# --- personal.Dockerfile ---
# This Dockerfile sets up an environment with Git and SSH,
# and creates a manual script for key generation.

FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

# Install dependencies
RUN apt-get update && \
    apt-get install -y git openssh-client tmux vim && \
    rm -rf /var/lib/apt/lists/*

# Configure git to use vim as the default editor
RUN git config --global core.editor vim

# Create the key generation script directly in the image
RUN echo '#!/bin/bash' > /usr/local/bin/generate-git-keys && \
    echo 'echo "--- Git SSH Key Setup ---"' >> /usr/local/bin/generate-git-keys && \
    echo 'read -p "Please enter your Git user name: " GIT_USER_NAME' >> /usr/local/bin/generate-git-keys && \
    echo 'read -p "Please enter your Git email address: " GIT_USER_EMAIL' >> /usr/local/bin/generate-git-keys && \
    echo '' >> /usr/local/bin/generate-git-keys && \
    echo 'if [ -z "$GIT_USER_NAME" ] || [ -z "$GIT_USER_EMAIL" ]; then' >> /usr/local/bin/generate-git-keys && \
    echo '    echo "Aborted: Both user name and email are required."' >> /usr/local/bin/generate-git-keys && \
    echo '    exit 1' >> /usr/local/bin/generate-git-keys && \
    echo 'fi' >> /usr/local/bin/generate-git-keys && \
    echo '' >> /usr/local/bin/generate-git-keys && \
    echo 'git config --global user.name "$GIT_USER_NAME"' >> /usr/local/bin/generate-git-keys && \
    echo 'git config --global user.email "$GIT_USER_EMAIL"' >> /usr/local/bin/generate-git-keys && \
    echo '' >> /usr/local/bin/generate-git-keys && \
    echo 'echo "Generating a new SSH key for $GIT_USER_EMAIL..."' >> /usr/local/bin/generate-git-keys && \
    echo 'ssh-keygen -t rsa -b 4096 -C "$GIT_USER_EMAIL" -N "" -f /root/.ssh/id_rsa' >> /usr/local/bin/generate-git-keys && \
    echo '' >> /usr/local/bin/generate-git-keys && \
    echo 'echo "----------------------------------------------------------------"' >> /usr/local/bin/generate-git-keys && \
    echo 'echo "ACTION REQUIRED: Add the following public key to your Git provider:"' >> /usr/local/bin/generate-git-keys && \
    echo 'echo "----------------------------------------------------------------"' >> /usr/local/bin/generate-git-keys && \
    echo 'cat /root/.ssh/id_rsa.pub' >> /usr/local/bin/generate-git-keys && \
    echo 'echo "----------------------------------------------------------------"' >> /usr/local/bin/generate-git-keys

# Make the script executable
RUN chmod +x /usr/local/bin/generate-git-keys

WORKDIR /workspace

# Set the default command to open a bash shell
CMD ["/bin/bash"]
