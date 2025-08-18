#!/bin/bash

# --- dev_setup.sh ---
# This script ensures Git, WezTerm, and Docker are installed on macOS or Linux,
# then builds and runs a container for an isolated Git environment.

# Detect OS
detect_os() {
    if [[ "$OSTYPE" == "darwin"* ]]; then
        echo "macos"
    elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
        echo "linux"
    else
        echo "unknown"
    fi
}

OS_TYPE=$(detect_os)

if [ "$OS_TYPE" = "unknown" ]; then
    echo "❌ Unsupported operating system: $OSTYPE"
    exit 1
fi

echo "🖥️  Detected OS: $OS_TYPE"

# Parse command line flags
DIND_MODE=false
while [[ $# -gt 0 ]]; do
    case $1 in
        --dind)
            DIND_MODE=true
            shift
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

# --- Part 1: Application Installation Checks ---
echo "🔎 Checking for required applications..."

# Function to ensure Homebrew is installed and ready (macOS)
ensure_homebrew() {
    if ! command -v brew &> /dev/null; then
        echo "🍺 Homebrew not found. Installing Homebrew..."
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    fi
    echo "🍺 Updating Homebrew..."
    brew update
}

# Function to detect Linux package manager
detect_package_manager() {
    if command -v apt-get &> /dev/null; then
        echo "apt"
    elif command -v dnf &> /dev/null; then
        echo "dnf"
    elif command -v yum &> /dev/null; then
        echo "yum"
    elif command -v pacman &> /dev/null; then
        echo "pacman"
    else
        echo "unknown"
    fi
}

# Function to install command-line tools if they are missing (cross-platform)
install_cli_if_missing() {
    local tool_name=$1
    local package_name=$2

    if command -v "$tool_name" &> /dev/null; then
        echo "✅ $tool_name is already installed."
    else
        echo "$tool_name not found. Preparing to install..."
        
        if [ "$OS_TYPE" = "macos" ]; then
            ensure_homebrew
            echo "📦 Installing $tool_name using Homebrew..."
            brew install "$package_name"
        elif [ "$OS_TYPE" = "linux" ]; then
            local pkg_mgr=$(detect_package_manager)
            echo "📦 Installing $tool_name using $pkg_mgr..."
            
            case $pkg_mgr in
                apt)
                    sudo apt-get update
                    sudo apt-get install -y "$package_name"
                    ;;
                dnf)
                    sudo dnf install -y "$package_name"
                    ;;
                yum)
                    sudo yum install -y "$package_name"
                    ;;
                pacman)
                    sudo pacman -Sy --noconfirm "$package_name"
                    ;;
                *)
                    echo "❌ Unsupported package manager. Please install $tool_name manually."
                    exit 1
                    ;;
            esac
        fi
        
        if [ $? -eq 0 ]; then
            echo "🚀 Successfully installed $tool_name."
        else
            echo "❌ Failed to install $tool_name."
            exit 1
        fi
    fi
}

# Function to install GUI applications if they are missing (macOS)
install_cask_if_missing() {
    local app_name=$1
    local brew_cask_name=$2
    local mdfind_query=$3

    if mdfind "$mdfind_query" | grep -q ".app"; then
        echo "✅ $app_name is already installed."
    else
        echo "$app_name not found. Preparing to install..."
        ensure_homebrew
        echo "📦 Installing $app_name using Homebrew..."
        brew install --cask "$brew_cask_name"
        if [ $? -eq 0 ]; then
            echo "🚀 Successfully installed $app_name."
        else
            echo "❌ Failed to install $app_name."
            exit 1
        fi
    fi
}

# Function to check if GUI app is installed on Linux
check_linux_gui_app() {
    local app_name=$1
    local binary_name=$2
    
    if command -v "$binary_name" &> /dev/null; then
        echo "✅ $app_name is already installed."
        return 0
    else
        return 1
    fi
}

# Function to install GUI applications on Linux
install_linux_gui_if_missing() {
    local app_name=$1
    local binary_name=$2
    local flatpak_id=$3
    
    if check_linux_gui_app "$app_name" "$binary_name"; then
        return
    fi
    
    echo "$app_name not found. Attempting to install..."
    
    if command -v flatpak &> /dev/null && [ -n "$flatpak_id" ]; then
        echo "📦 Installing $app_name using Flatpak..."
        flatpak install -y flathub "$flatpak_id"
        if [ $? -eq 0 ]; then
            echo "🚀 Successfully installed $app_name."
            return
        fi
    fi
    
    echo "⚠️  Could not install $app_name automatically."
    echo "Please install $app_name manually for your distribution."
}

# --- Run Checks ---
install_cli_if_missing "git" "git"

if [ "$DIND_MODE" = true ]; then
    if [ "$OS_TYPE" = "macos" ]; then
        install_cli_if_missing "docker" "docker"
    elif [ "$OS_TYPE" = "linux" ]; then
        install_cli_if_missing "docker" "docker.io"
    fi
else
    if [ "$OS_TYPE" = "macos" ]; then
        install_cask_if_missing "WezTerm" "wezterm" "kMDItemCFBundleIdentifier == 'com.github.wez.wezterm'"
        install_cask_if_missing "Docker Desktop" "docker" "kMDItemCFBundleIdentifier == 'com.docker.docker'"
    elif [ "$OS_TYPE" = "linux" ]; then
        install_linux_gui_if_missing "WezTerm" "wezterm" "org.wezfurlong.wezterm"
        install_cli_if_missing "docker" "docker.io"
        
        if ! groups | grep -q docker; then
            echo "⚠️  Adding current user to docker group..."
            sudo usermod -aG docker "$USER"
            echo "⚠️  You may need to log out and back in for docker group changes to take effect."
        fi
    fi
fi


# --- Part 2: Docker Environment Setup ---
echo ""
echo "--- Docker Setup ---"

# Define the image name and tag
if [ "$DIND_MODE" = true ]; then
    IMAGE_NAME="dind-env"
    TAG="latest"
    DOCKERFILE_NAME="Dockerfile.dind"
else
    IMAGE_NAME="git-auth-env"
    TAG="latest"
    DOCKERFILE_NAME="Dockerfile.personal"
fi

echo "Building the Docker image: $IMAGE_NAME:$TAG..."

# Check if the Docker daemon is running
if ! docker info &> /dev/null; then
    echo "❌ Docker daemon is not running. Please start Docker Desktop and try again."
    exit 1
fi

# Build the Docker image
docker build -f "$DOCKERFILE_NAME" -t "$IMAGE_NAME:$TAG" .

# Check if the build was successful
if [ $? -ne 0 ]; then
    echo "Docker image build failed. Please check your Dockerfile and try again."
    exit 1
fi

echo "Image built successfully."
echo "Starting the container..."
echo ""

if [ "$DIND_MODE" = false ]; then
    echo "######################################################################"
    echo "#                                                                    #"
    echo "#   ACTION REQUIRED: Once inside the container, you MUST run this    #"
    echo "#   command to set up your Git credentials for the session:          #"
    echo "#                                                                    #"
    echo "#   > generate-git-keys                                              #"
    echo "#                                                                    #"
    echo "######################################################################"
    echo ""
fi

# Run the container in interactive mode and remove it on exit
# Mount the current host directory to the /workspace directory
if [ "$DIND_MODE" = true ]; then
    docker run -d --rm --name dind-container \
        --privileged \
        -v "$HOME/.ssh/config:/root/.ssh/config:ro" \
        "$IMAGE_NAME:$TAG"
    
    echo "Container started in background."
    echo "Opening interactive terminal..."
    docker exec -it dind-container /bin/bash
    
    echo "Stopping container..."
    docker stop dind-container
else
    docker run -it --rm --name git-container \
        -v "$(pwd):/workspace" \
        "$IMAGE_NAME:$TAG"
fi

echo "Container exited."
