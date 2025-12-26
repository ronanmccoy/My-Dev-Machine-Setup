#!/bin/bash

# -------------------------------------------------------------
#	README
#	Run with `sh git_setup.sh` from command prompt on Mac OS.
#	This will check if git is installed, and if it is will 
#	update git config, set global git ignore, and generate a
#	new SSH key for Github.com if one doesn't already exist.
# -------------------------------------------------------------


# ------------------------
# check for git
# ------------------------
if ! command -v git &> /dev/null; then
	echo "ERROR!!"
	echo "Git is not installed. Please install git before running this script."
	exit 1
fi


# ------------------------
# user info
# ------------------------
read -p "Enter your name to use with git: " GIT_USER_NAME
read -p "Enter your email to use with git: " GIT_USER_EMAIL
SSH_KEY_COMMENT="$GIT_USER_EMAIL"


# ------------------------
# git config
# ------------------------
echo
echo "--> setting up git global config..."
git config --global user.name "$GIT_USER_NAME"
git config --global user.email "$GIT_USER_EMAIL"
git config --global init.defaultBranch main


# ------------------------
# git global ignore
# ------------------------
echo
echo "--> setting up global ignore for git..."
GLOBAL_GITIGNORE="$HOME/.gitignore_global"
touch "$GLOBAL_GITIGNORE"
git config --global core.excludesfile "$GLOBAL_GITIGNORE"

cat <<EOL >> "$GLOBAL_GITIGNORE"
# OS
.DS_Store
Thumbs.db

# Editors
.vscode/
*.code-workspace
*.sublime-workspace
*.sublime-project

# Logs
*.log
npm-debug.log*
yarn-debug.log*
pnpm-debug.log*

# Environment
.env
.env.local
.env.*.local

# Node
node_modules/
dist/
build/
out/
*.tsbuildinfo

# Misc
*.swp
*.swo
*.ronan
*.ronan.*
devnotes.*
notes.*

EOL

echo "--> created global gitignore at $GLOBAL_GITIGNORE"


# ------------------------
# SSH key for GitHub
# ------------------------
echo 
echo "--> setting up SSH key for github..."
SSH_KEY_PATH="$HOME/.ssh/id_ed25519"

if [ -f "$SSH_KEY_PATH" ]; then
	echo "--> SSH key already exists at $SSH_KEY_PATH"
else
	echo "--> generating new SSH key..."
	ssh-keygen -t ed25519 -C "$SSH_KEY_COMMENT" -f "$SSH_KEY_PATH" -N ""
	eval "$(ssh-agent -s)"
	ssh-add "$SSH_KEY_PATH"
	echo "SSH key generated and added to ssh-agent"
fi

echo
echo "--> Copy the following SSH key and add it to GitHub.com (https://www.github.com/settings/keys):"
cat "$SSH_KEY_PATH.pub"


# ------------------------
# Summary
# ------------------------
echo
echo "--> setup completed"
echo "--> global git config updated:"
git config --list | grep -E "user.name|user.email|core.excludefile"

echo
echo "👉 After adding the SSH key to Github, test SSH connection to GitHub with:"
echo "ssh -T git@github.com"
echo
echo "--> done! 👋 "

