#!/bin/bash

# This script creates a fully ephemeral Zoom session.
# It must be run with sudo.

# --- Safety Check: Ensure the script is run with sudo ---
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root to manage applications."
   echo "Please run with: sudo $0"
   exit 1
fi

# Use SUDO_USER to target the home directory of the user who invoked sudo
USER_HOME=$(eval echo ~$SUDO_USER)

# --- Function to perform a full cleanup ---
cleanup_zoom() {
    echo "--- Starting Full Zoom Cleanup ---"

    # Force quit any running Zoom process
    echo "Closing Zoom application..."
    pkill -f "zoom.us" || echo "Zoom was not running."
    sleep 1

    # Delete the application
    echo "Deleting Zoom application..."
    rm -rf "/Applications/zoom.us.app"

    # Delete all associated user data
    echo "Deleting all Zoom user data..."
    rm -rf "$USER_HOME/Library/Application Support/zoom.us"
    rm -rf "$USER_HOME/Library/Caches/us.zoom.xos"
    rm -rf "$USER_HOME/Library/Logs/zoom.us"
    rm -rf "$USER_HOME/Library/Saved Application State/us.zoom.xos.savedState"
    rm -f "$USER_HOME/Library/Preferences/us.zoom.xos.plist"
    rm -f "$USER_HOME/Library/Preferences/us.zoom.config.plist"
    rm -f "$USER_HOME/Library/Preferences/ZoomChat.plist"
    rm -rf "$USER_HOME/Documents/Zoom" # Deletes recordings folder

    echo "Cleanup complete."
}


# --- PHASE 1: Initial Cleanup and Installation ---
echo "--- PHASE 1: SETUP ---"
cleanup_zoom

echo "Downloading the latest version of Zoom..."
curl -L "https://zoom.us/client/latest/Zoom.pkg" -o "/tmp/Zoom.pkg"

echo "Installing Zoom..."
installer -pkg "/tmp/Zoom.pkg" -target /

echo "Cleaning up installer..."
rm "/tmp/Zoom.pkg"

echo "Starting Zoom..."
# Launch the application as the original user, not as root
sudo -u "$SUDO_USER" open -a "zoom.us"

echo ""
echo "--------------------------------------------------------"
echo "✅ Zoom is ready for your meeting."
echo "Use the Zoom application as normal."
echo "When you are completely finished, return to this terminal."
echo "--------------------------------------------------------"
echo ""

# --- PHASE 2: Wait for user to finish ---
read -p "PRESS [ENTER] TO END SESSION AND WIPE ALL ZOOM DATA..."

# --- PHASE 3: Final Teardown ---
echo ""
echo "--- PHASE 2: TEARDOWN ---"
cleanup_zoom

echo "✅ All Zoom components have been removed."

exit 0
