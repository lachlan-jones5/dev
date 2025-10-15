#!/bin/bash

# --- dev_setup.sh ---
# This script ensures Git, Alacritty, and Docker are installed on macOS or Linux,
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
MODE=""
while [[ $# -gt 0 ]]; do
  case $1 in
  --work)
    MODE="work"
    shift
    ;;
  --personal)
    MODE="personal"
    shift
    ;;
  *)
    echo "Unknown option: $1"
    echo "Usage: $0 [--work|--personal]"
    exit 1
    ;;
  esac
done

# Check if mode was specified
if [ -z "$MODE" ]; then
  echo "❌ Error: You must specify either --work or --personal"
  echo "Usage: $0 [--work|--personal]"
  exit 1
fi

echo "🔧 Mode: $MODE"

# --- Part 1: Application Installation Checks ---
echo "🔎 Checking for required applications..."

# Function to ensure Homebrew is installed and ready (macOS)
ensure_homebrew() {
  if ! command -v brew &>/dev/null; then
    echo "🍺 Homebrew not found. Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  fi
  echo "🍺 Updating Homebrew..."
  brew update
}

# Function to detect Linux package manager
detect_package_manager() {
  if command -v apt-get &>/dev/null; then
    echo "apt"
  elif command -v dnf &>/dev/null; then
    echo "dnf"
  elif command -v yum &>/dev/null; then
    echo "yum"
  elif command -v pacman &>/dev/null; then
    echo "pacman"
  else
    echo "unknown"
  fi
}

# Function to install command-line tools if they are missing (cross-platform)
install_cli_if_missing() {
  local tool_name=$1
  local package_name=$2

  if command -v "$tool_name" &>/dev/null; then
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

  if command -v "$binary_name" &>/dev/null; then
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

  if command -v flatpak &>/dev/null && [ -n "$flatpak_id" ]; then
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

if [ "$MODE" = "work" ]; then
  if [ "$OS_TYPE" = "macos" ]; then
    install_cli_if_missing "docker" "docker"
  elif [ "$OS_TYPE" = "linux" ]; then
    install_cli_if_missing "docker" "docker.io"
  fi
else
  if [ "$OS_TYPE" = "macos" ]; then
    install_cask_if_missing "Alacritty" "alacritty" "kMDItemCFBundleIdentifier == 'org.alacritty'"
    install_cask_if_missing "Docker Desktop" "docker" "kMDItemCFBundleIdentifier == 'com.docker.docker'"
  elif [ "$OS_TYPE" = "linux" ]; then
    install_linux_gui_if_missing "Alacritty" "alacritty" "org.alacritty.Alacritty"
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
if [ "$MODE" = "work" ]; then
  IMAGE_NAME="work-env"
  TAG="latest"
  DOCKERFILE_NAME="Dockerfile.work"
else
  IMAGE_NAME="git-auth-env"
  TAG="latest"
  DOCKERFILE_NAME="Dockerfile.personal"
fi

echo "Building the Docker image: $IMAGE_NAME:$TAG..."

# Check if the Docker daemon is running
if ! docker info &>/dev/null; then
  echo "❌ Docker daemon is not running. Please start Docker Desktop and try again."
  exit 1
fi

if [ "$MODE" = "work" ]; then
  echo ""
  echo "--- SSH Configuration Setup ---"

  mkdir -p "$(pwd)/.ssh"
  rm -f "$(pwd)/.ssh/config"

  read -p "Enter VM hostname: " vm_hostname
  read -p "Enter VM username: " vm_username

  cat >"$(pwd)/.ssh/config" <<EOF
Host vm
    HostName $vm_hostname
    User $vm_username
    Port 22
    IdentityFile ~/.ssh/id_rsa
    StrictHostKeyChecking no
    UserKnownHostsFile=/dev/null
EOF
  echo "✅ SSH config created at .ssh/config"

  echo ""
  echo "--- Remote Path Configuration ---"
  read -p "Enter remote path on VM (e.g., /home/user/projects): " remote_path
  read -p "Enter local mount point in container (e.g., /workspace): " local_mount

  # Ensure local_mount doesn't have trailing slash
  local_mount="${local_mount%/}"
  remote_path="${remote_path%/}"

  echo "✅ Remote path: $remote_path"
  echo "✅ Local mount: $local_mount"

  echo ""
  echo "--- Copying SSH Keys ---"
  if [ -f "$HOME/.ssh/id_rsa" ]; then
    cp "$HOME/.ssh/id_rsa" "$(pwd)/.ssh/id_rsa"
    chmod 600 "$(pwd)/.ssh/id_rsa"
    echo "✅ Copied id_rsa"
  else
    echo "⚠️  Warning: $HOME/.ssh/id_rsa not found"
  fi

  if [ -f "$HOME/.ssh/id_rsa.pub" ]; then
    cp "$HOME/.ssh/id_rsa.pub" "$(pwd)/.ssh/id_rsa.pub"
    chmod 644 "$(pwd)/.ssh/id_rsa.pub"
    echo "✅ Copied id_rsa.pub"
  fi

  echo ""
  echo "--- Retrieving Remote User Information ---"
  remote_uid=$(ssh -F "$(pwd)/.ssh/config" vm "id -u $vm_username" 2>/dev/null)
  remote_gid=$(ssh -F "$(pwd)/.ssh/config" vm "id -g $vm_username" 2>/dev/null)

  if [ -z "$remote_uid" ] || [ -z "$remote_gid" ]; then
    echo "⚠️  Warning: Could not retrieve remote user ID/group ID"
    echo "Using default UID=1000, GID=1000"
    remote_uid=1000
    remote_gid=1000
  else
    echo "✅ Retrieved UID: $remote_uid, GID: $remote_gid"
  fi

  # Build the Docker image with user information and alias commands
  docker build -f "$DOCKERFILE_NAME" \
    --build-arg USERNAME="$vm_username" \
    --build-arg USER_UID="$remote_uid" \
    --build-arg USER_GID="$remote_gid" \
    --build-arg REMOTE_PATH="$remote_path" \
    --build-arg LOCAL_MOUNT="$local_mount" \
    -t "$IMAGE_NAME:$TAG" .
else
  # Build the Docker image
  docker build -f "$DOCKERFILE_NAME" -t "$IMAGE_NAME:$TAG" .
fi

# Check if the build was successful
if [ $? -ne 0 ]; then
  echo "Docker image build failed. Please check your Dockerfile and try again."
  exit 1
fi

echo "Image built successfully."

# Prompt for Anthropic API key if not in work mode
if [ "$MODE" = "personal" ]; then
  echo ""
  echo "--- API Configuration ---"
  read -p "Enter your Anthropic API key (or press Enter to skip): " ANTHROPIC_API_KEY
  echo ""
fi

echo "Starting the container..."
echo ""

if [ "$MODE" = "personal" ]; then
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
if [ "$MODE" = "work" ]; then
  SOURCE_SSH_DIR="$HOME/.ssh"
  DEST_SSH_DIR="$(PWD)/.ssh"

  echo "Copying files from '$SOURCE_SSH_DIR' to '$DEST_SSH_DIR'..."
  cp -r "$SOURCE_SSH_DIR" "$PWD"

  # The UseKeychain option is specific to macOS and stores passphrases in the keychain.
  # It is not a valid option on Linux and needs to be commented out or removed.
  CONFIG_FILE="$DEST_SSH_DIR/config"
  if [ -f "$CONFIG_FILE" ]; then
    echo "Converting 'config' file for Linux compatibility..."
    # Use sed to find and comment out the UseKeychain line
    sed -i.bak 's/^\s*UseKeychain\s*yes/# UseKeychain yes/' "$CONFIG_FILE"
    # Remove the backup file created by sed
    rm "${CONFIG_FILE}.bak"
    echo "'UseKeychain' option has been commented out in the config file."
  fi

  docker run -d --rm --name work-container \
    --privileged \
    -p 8501:8501 \
    -v "$(pwd)/.ssh:/home/$vm_username/.ssh" \
    "$IMAGE_NAME:$TAG" tail -f /dev/null || {
    echo "Error: Could not start work-container" >&2
    exit 1
  }

  echo "Container started in background."
  echo ""
  echo "######################################################################"
  echo "#                                                                    #"
  echo "#   Available commands in the container:                             #"
  echo "#                                                                    #"
  echo "#   rmount  - Mount remote directory using rclone                    #"
  echo "#   rpull   - Pull changes from remote using rsync                   #"
  echo "#   rpush   - Push changes to remote using rsync                     #"
  echo "#                                                                    #"
  echo "######################################################################"
  echo ""

  echo "Waiting for container to start..."
  while [ "$(docker inspect -f '{{.State.Running}}' work-container)" != "true" ]; do
    sleep 0.1
  done
  echo "Container started."

  echo "Opening interactive terminal..."
  echo "You'll also need to place the .gitignore file at /home/$vm_username"
  echo 'Remember to run: eval "$(ssh-agent -s)" && ssh-add ~/.ssh/id_rsa'
  WORK_CMD='docker exec -it -u "$vm_username" work-container /bin/bash'
  eval "$WORK_CMD"

  docker kill work-container

else
  # Build docker run command with optional API key
  DOCKER_RUN_CMD="docker run -it --rm --name git-container -v $(pwd):/workspace"

  if [ -n "$ANTHROPIC_API_KEY" ]; then
    DOCKER_RUN_CMD="$DOCKER_RUN_CMD -e ANTHROPIC_API_KEY=$ANTHROPIC_API_KEY"
  fi

  DOCKER_RUN_CMD="$DOCKER_RUN_CMD $IMAGE_NAME:$TAG"

  eval "$DOCKER_RUN_CMD"
fi

echo "Container exited."
