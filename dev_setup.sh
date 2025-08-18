#!/bin/bash

# --- dev_setup.sh ---
# This script first ensures VS Code and Zoom are installed on macOS, then builds
# and runs a container for an isolated Git environment.

# --- Part 1: Application Installation Checks ---
echo "🔎 Checking for required applications..."

# --- VS Code Check ---
if mdfind "kMDItemAppStoreIdentifier == 'com.microsoft.VSCode'" | grep -q "Visual Studio Code.app"; then
    echo "✅ Visual Studio Code is already installed."
else
    echo "VS Code not found. Preparing to install..."
    if ! command -v brew &> /dev/null; then
        echo "🍺 Homebrew not found. Installing Homebrew first..."
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    else
        echo "🍺 Homebrew is already installed. Updating..."
        brew update
    fi
    echo "📦 Installing Visual Studio Code using Homebrew..."
    brew install --cask visual-studio-code
    if [ $? -eq 0 ]; then echo "🚀 Successfully installed Visual Studio Code."; else echo "❌ Failed to install Visual Studio Code."; exit 1; fi
fi

# --- Zoom Check ---
if mdfind "kMDItemAppStoreIdentifier == 'us.zoom.xos'" | grep -q "zoom.us.app"; then
    echo "✅ Zoom is already installed."
else
    echo "Zoom not found. Preparing to install..."
    if ! command -v brew &> /dev/null; then
        echo "🍺 Homebrew not found. Installing Homebrew first..."
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    else
        echo "🍺 Homebrew is already installed. Updating..."
        brew update
    fi
    echo "📦 Installing Zoom using Homebrew..."
    brew install --cask zoom
    if [ $? -eq 0 ]; then echo "🚀 Successfully installed Zoom."; else echo "❌ Failed to install Zoom."; exit 1; fi
fi


# --- Part 2: Docker Environment Setup ---
echo ""
echo "--- Docker Setup ---"

# Define the image name and tag
IMAGE_NAME="git-auth-env"
TAG="latest"
DOCKERFILE_NAME="personal.Dockerfile"

echo "Building the Docker image: $IMAGE_NAME:$TAG..."

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
