#!/bin/bash

# --- dev_setup.sh ---
# This script first ensures Git, Ghostty, and Docker are installed on macOS,
# then builds and runs a container for an isolated Git environment.

# --- Part 1: Application Installation Checks ---
echo "🔎 Checking for required applications..."

# Function to ensure Homebrew is installed and ready
ensure_homebrew() {
    if ! command -v brew &> /dev/null; then
        echo "🍺 Homebrew not found. Installing Homebrew..."
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    fi
    # Ensure Homebrew is up to date
    echo "🍺 Updating Homebrew..."
    brew update
}

# Function to install command-line tools if they are missing
install_cli_if_missing() {
    local tool_name=$1
    local brew_package_name=$2

    if command -v "$tool_name" &> /dev/null; then
        echo "✅ $tool_name is already installed."
    else
        echo "$tool_name not found. Preparing to install..."
        ensure_homebrew
        echo "📦 Installing $tool_name using Homebrew..."
        brew install "$brew_package_name"
        if [ $? -eq 0 ]; then
            echo "🚀 Successfully installed $tool_name."
        else
            echo "❌ Failed to install $tool_name."
            exit 1
        fi
    fi
}

# Function to install GUI applications if they are missing
install_cask_if_missing() {
    local app_name=$1
    local brew_cask_name=$2
    local mdfind_query=$3

    # Use mdfind (Spotlight search) for a robust check of the application's existence
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

# --- Run Checks ---
install_cli_if_missing "git" "git"
install_cask_if_missing "Ghostty" "ghostty" "kMDItemCFBundleIdentifier == 'com.mitchellh.ghostty'"
install_cask_if_missing "Docker Desktop" "docker" "kMDItemCFBundleIdentifier == 'com.docker.docker'"


# --- Part 2: Docker Environment Setup ---
echo ""
echo "--- Docker Setup ---"

# Define the image name and tag
IMAGE_NAME="git-auth-env"
TAG="latest"
DOCKERFILE_NAME="personal.Dockerfile"

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
echo "######################################################################"
echo "#                                                                    #"
echo "#   ACTION REQUIRED: Once inside the container, you MUST run this    #"
echo "#   command to set up your Git credentials for the session:          #"
echo "#                                                                    #"
echo "#   > generate-git-keys                                              #"
echo "#                                                                    #"
echo "######################################################################"
echo ""

# Run the container in interactive mode and remove it on exit
# Mount the current host directory to the /workspace directory
docker run -it --rm --name git-container \
    -v "$(pwd):/workspace" \
    "$IMAGE_NAME:$TAG"

echo "Container exited."
