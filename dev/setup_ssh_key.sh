#!/bin/bash

# Set your remote target variables
read -p "Enter your remote username: " REMOTE_USER
read -p "Enter your remote host (IP or hostname): " REMOTE_HOST

# Step 1: Generate a new SSH key if one does not exist
KEY_FILE="$HOME/.ssh/id_rsa"

if [ ! -f "$KEY_FILE" ]; then
    echo "🔑 Generating SSH key..."
    ssh-keygen -t rsa -b 4096 -f "$KEY_FILE" -N ""
else
    echo "✅ SSH key already exists at $KEY_FILE"
fi

# Step 2: Copy public key to remote server
echo "🚀 Copying public key to $REMOTE_USER@$REMOTE_HOST..."
ssh-copy-id "$REMOTE_USER@$REMOTE_HOST"

# Step 3: Test passwordless login
echo "🔗 Testing SSH connection..."
ssh -o PasswordAuthentication=no "$REMOTE_USER@$REMOTE_HOST" echo "✅ SSH key authentication succeeded."

# Done
echo "🎉 SSH key setup complete."
