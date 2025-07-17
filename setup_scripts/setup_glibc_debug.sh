#!/bin/bash

# This script automates the setup for debugging glibc source code in VS Code.
# It installs the necessary packages, unpacks the source code, and creates
# a suitable .vscode/launch.json configuration.

set -e # Exit immediately if a command fails.

echo "--- Step 1: Installing glibc-source ---"
sudo apt-get update
sudo apt-get install -y glibc-source
echo "glibc-source installed successfully."
echo

echo "--- Step 2: Finding and Unpacking glibc source tarball ---"
# dpkg -L glibc-source
# Find the glibc source tarball, which is usually in /usr/src/glibc
GLIBC_TARBALL=$(find /usr/src/glibc -name "glibc-*.tar.xz" 2>/dev/null | head -n 1)

if [ -z "$GLIBC_TARBALL" ]; then
    echo "Error: Could not find glibc source tarball in /usr/src/glibc."
    exit 1
fi

echo "Found glibc tarball: $GLIBC_TARBALL"

# Determine the directory name that will be created upon extraction
EXTRACTED_DIR_NAME=$(tar -tf "$GLIBC_TARBALL" | head -n 1 | cut -d'/' -f1)
GLIBC_SOURCE_PATH="/usr/src/$EXTRACTED_DIR_NAME"

if [ -z "$EXTRACTED_DIR_NAME" ]; then
    echo "Error: Could not determine directory name from tarball."
    exit 1
fi

# Check if the source code is already unpacked
if [ -d "$GLIBC_SOURCE_PATH" ]; then
    echo "Source directory $GLIBC_SOURCE_PATH already exists. Skipping extraction."
else
    echo "Extracting source to /usr/src/..."
    sudo tar -xvf "$GLIBC_TARBALL" -C /usr/src/
    echo "Extraction complete."
fi
echo

echo "--- Step 3: Configuring VS Code launch.json ---"
echo "Add the following to your launch.json file:"<< EOF
            "sourceFileMap": {
                "/build/glibc-*": "${GLIBC_SOURCE_PATH}"
            }
EOF

# VSCODE_DIR=".vscode"
# LAUNCH_JSON="$VSCODE_DIR/launch.json"

# # Create .vscode directory if it doesn't exist
# mkdir -p "$VSCODE_DIR"

# # Create the launch.json content. This will overwrite an existing file.
# # A backup of the old configuration will be created if it exists.
# if [ -f "$LAUNCH_JSON" ]; then
#     echo "Backing up existing launch.json to ${LAUNCH_JSON}.bak"
#     cp "$LAUNCH_JSON" "${LAUNCH_JSON}.bak"
# fi




# echo "Creating new $LAUNCH_JSON with glibc source mapping."

# # Note: The build path /build/glibc-* is a common placeholder used by build systems.
# # The wildcard ensures it matches the specific versioned build path on your system.
# cat > "$LAUNCH_JSON" <<EOF
# {
#     "version": "0.2.0",
#     "configurations": [
#         {
#             "name": "C/C++ Debug (gdb Attach)",
#             "type": "cppdbg",
#             "request": "attach",
#             "program": "\${workspaceFolder}/myshell",
#             "processId": "\${command:pickProcess}",
#             "MIMode": "gdb",
#             "setupCommands": [
#                 {
#                     "description": "Enable pretty-printing for gdb",
#                     "text": "-enable-pretty-printing",
#                     "ignoreFailures": true
#                 }
#             ],
#             "sourceFileMap": {
#                 "/build/glibc-*": "${GLIBC_SOURCE_PATH}"
#             }
#         },
#         {
#             "name": "(gdb) Launch",
#             "type": "cppdbg",
#             "request": "launch",
#             "program": "\${workspaceFolder}/myshell",
#             "args": [],
#             "stopAtEntry": false,
#             "cwd": "\${workspaceFolder}",
#             "environment": [],
#             "externalConsole": false,
#             "MIMode": "gdb",
#             "preLaunchTask": "build",
#             "sourceFileMap": {
#                 "/build/glibc-*": "${GLIBC_SOURCE_PATH}"
#             }
#         }
#     ]
# }
# EOF

# echo
# echo "--- Setup Complete ---"
# echo "You can now run this script with: bash setup_glibc_debug.sh"
# echo "After running, your VS Code debugger will be configured to find glibc source files."
