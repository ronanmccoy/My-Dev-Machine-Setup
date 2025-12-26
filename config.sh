#!/bin/bash
# ============================================================================
# Configuration File for Dev Machine Setup Scripts
# ============================================================================
# This file contains all configurable values for the setup scripts.
# Edit this file to customize the setup behavior without modifying the scripts.
#
# IMPORTANT: 
# - All variables must be properly quoted if they contain spaces
# - Boolean values should be: true or false (lowercase)
# - If you make a syntax error, the script will fail with an error message
# ============================================================================

# ----------------------------------------------------------------------------
# VS Code Settings
# ----------------------------------------------------------------------------
VSCODE_FONT_SIZE=13
VSCODE_TAB_SIZE=4
VSCODE_COLOR_THEME="Visual Studio Dark"
VSCODE_ICON_THEME="vscode-icons"
VSCODE_FORMAT_ON_SAVE=true
VSCODE_AUTO_SAVE="afterDelay"
VSCODE_DEFAULT_FORMATTER="esbenp.prettier-vscode"
VSCODE_WORD_WRAP="on"

# ----------------------------------------------------------------------------
# Default Prompt Answers
# These determine the default answers for interactive prompts
# Set to true for "yes" or false for "no"
# ----------------------------------------------------------------------------
PROMPT_INSTALL_VSCODE_SETTINGS=true
PROMPT_INSTALL_VSCODE_EXTENSIONS=true
PROMPT_INSTALL_ITERM_THEME=true
PROMPT_INSTALL_SHELL_PROMPT=true
PROMPT_INSTALL_SHELL_ALIASES=true

# ----------------------------------------------------------------------------
# Git Configuration
# ----------------------------------------------------------------------------
GIT_DEFAULT_BRANCH="main"

# ----------------------------------------------------------------------------
# Node.js/NVM Configuration
# ----------------------------------------------------------------------------
NODE_VERSION="node"  # Use "node" for latest, or specific version like "18.17.0"

