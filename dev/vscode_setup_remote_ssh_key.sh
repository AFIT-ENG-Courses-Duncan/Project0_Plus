#!/bin/bash

# 1. Generate SSH key on remote
KEY_NAME="id_vscode_rsa"
KEY_PATH="$HOME/.ssh/$KEY_NAME"

REMOTE_KEY="$KEY_PATH"

if [ -f "$REMOTE_KEY" ]; then
    echo "🔑 SSH key already exists at $REMOTE_KEY"
else
    echo "🔐 Generating SSH key on remote..."
    ssh-keygen -t rsa -b 4096 -f "$REMOTE_KEY" -N ""
fi

# 2. Print fingerprint
echo "🔎 Public key fingerprint:"
ssh-keygen -lf "$REMOTE_KEY"


# 3. Create temporary location to transfer the private key
TMP_DIR=$(mktemp -d)
cp "$REMOTE_KEY" "$TMP_DIR/$KEY_NAME"
cp "$REMOTE_KEY.pub" "$TMP_DIR/$KEY_NAME.pub"

# 4. Detect VS Code local user home path
#echo "📡 Detecting local .ssh path via VS Code extension bridge..."
#LOCAL_USER_HOME=$(code --locate-shell-integration | sed -E 's/\/.vscode.*//' | sed 's/\/$//')
# x. Ask for hostname and user to use in SSH config
# We need to properly handle the user input for LOCAL_USER_HOME as it may be a windows path
# Example user input: C:\Users\mcdunc2\.ssh
read -p "Enter VS Code local user home path (e.g., C:\\Users\\yourusername or C:/Users/yourusername): " LOCAL_USER_HOME

# Convert backslashes to forward slashes, but preserve the colon
LOCAL_USER_HOME=$(echo "$LOCAL_USER_HOME" | sed -E 's|\\+|/|g')

# Remove any trailing slash
LOCAL_USER_HOME=$(echo "$LOCAL_USER_HOME" | sed 's:/*$::')

LOCAL_SSH_DIR="${LOCAL_USER_HOME}/.ssh"

echo "📁 Detected local .ssh directory: $LOCAL_SSH_DIR"

# x. Ask for hostname and user to use in SSH config
read -p "Enter remote host (e.g., 192.168.1.100): " HOST
read -p "Enter SSH user for $HOST: " USER
CONFIG_ENTRY=$(cat <<EOF

Host $HOST-keyauth
    HostName $HOST
    User $USER
    IdentityFile $LOCAL_SSH_DIR/$KEY_NAME
    IdentitiesOnly yes
EOF
)

# x. Create Append config entry
echo "📝 Updating local SSH config..."
echo "$CONFIG_ENTRY" >> "$TMP_DIR/append_ssh_host_config"


# 5. Output instructions for downloading or Use VS Code's file sync to pull to local .ssh directory
echo "⬇️ Downloading key files and config to local machine..."
#code --remote-download "$TMP_DIR/id_vscode_rsa" "$LOCAL_SSH_DIR/id_vscode_rsa"
#code --remote-download "$TMP_DIR/id_vscode_rsa.pub" "$LOCAL_SSH_DIR/id_vscode_rsa.pub"
#chmod 600 "$LOCAL_SSH_DIR/id_vscode_rsa"
#chmod 644 "$LOCAL_SSH_DIR/id_vscode_rsa.pub"

# Output instructions for downloading
echo ""
echo "📥 To continue, run the following on your LOCAL machine:"
echo ""
echo "scp $USER@$HOST:$TMP_DIR/$KEY_NAME $LOCAL_SSH_DIR/$KEY_NAME"
#C:\Users\mcdunc2\.ssh\id_vscode_rsa
#scp osc@192.168.56.110:/tmp/tmp.LlvWkJL5k4/id_vscode_rsa C:/Users/mcdunc2/.ssh/id_vscode_rsa
echo "scp $USER@$HOST:$TMP_DIR/$KEY_NAME.pub $LOCAL_SSH_DIR/$KEY_NAME.pub"
#scp osc@192.168.56.110:/tmp/tmp.LlvWkJL5k4/id_vscode_rsa.pub C:/Users/mcdunc2/.ssh/id_vscode_rsa.pub
echo "scp $USER@$HOST:$TMP_DIR/append_ssh_host_config $LOCAL_SSH_DIR/append_ssh_host_config"
# scp osc@192.168.56.110:/tmp/tmp.LlvWkJL5k4/append_ssh_host_config C:/Users/mcdunc2/.ssh/append_ssh_host_config

# 6. Cleanup
#rm -rf "$TMP_DIR"


echo "✅ All done. You can now connect via:"
echo "    ssh $HOST-keyauth"
