# MacOS Setup

## Intro

Scripts specific to MacOS. Uses Homebrew to install apps.

## Instructions

1. Review `apps.txt`.
2. Run `sh mac_setup.sh` (might need to use `sudo`).
   - Use `sh mac_setup.sh --dry-run` or `sh mac_setup.sh -n` to preview what will be done without making changes
3. (Optional) Run `sh git_setup.sh` (might need to use `sudo`).
4. (Optional) Run `sh aws_setup.sh` (might need to use `sudo`).

### Dry-Run Mode

The script supports a dry-run mode that shows what would be done without actually making any changes:
```bash
sh mac_setup.sh --dry-run
# or
sh mac_setup.sh -n
```

In dry-run mode:
- All operations are simulated (no actual installations or file modifications)
- Interactive prompts use default answers
- Commands that would be executed are displayed
- Errors for missing files/invalid configs are still collected
- A log file is still created showing what would happen

### Logging

The script automatically logs all operations to `dev-setup.log` in the project root directory. The log file:
- Contains timestamps for all operations
- Includes log levels (INFO, WARNING, ERROR)
- Appends to the file on each run (preserves history)
- Can be reviewed to troubleshoot issues or see what was installed

### apps.txt

First update the list of apps as needed. The apps here are specific to my usecase and might not fit your needs.

### mac_setup.sh

This script will do the following:

- Install Homebrew.
- Attempt to install the apps listed in `apps.txt`.
- Install the latest version of Node via NVM (FYI, NVM is an app listed in `apps.txt`).
- Install NPM packages listed in `/data/packages/packages.txt`.
- Apply some basic settings to VS Code (set dark theme, vs code icons, font size, and tab size).
- Set Iterm theme from `/data/themes/iTerm-Ronans-Theme.json` (if the theme file does not exist, it will skip this step).
- Customize the shell prompt to show git branch information when in a git project.
- Add some aliases to the shell profile (search for "my custom aliases" in `mac_setup.sh` to modify or remove this section).
- If any apps or NPM packages failed to install, print a list of them for manual resolution.

### Prompt Aliases

The list of aliases that will be added to the shell profile is very specific to my usecase. These aliases I've been using for years and, admittedly they might not be ideal, but I'm simply used to them. For your usecase feel free to modify this list. Simply search for "my custom aliases" in the script. They can be removed from `mac_setup.sh` without any negative effects. Or one can add new aliases or modify/remove existing ones.

## Additional Steps

1. The `mac_setup.sh` script only installs a set of predefined apps and an iTerm theme. After running both scripts, open iTerm and set the new theme as the default if so desired.

2. Also, after running the scripts, you will need to install VS Code extensions as needed. For starters I install the following extensions (note this will be an ever-evolving list):

- Auto Rename Tag
- Better Comments
- Bookmarks
- Claude Code for VSCode
- ES7+React/Redux/React-Native snippets
- ESLint
- Github Copilot
- Github Copilot Chat
- Javascript and Typescript Nightly
- npm Intellisense
- Prettier - Code Formatter
- Tailwind CSS Intellisense
- Todo Tree
- vscode-icons

VS Code extensions are now automatically installed by the script from `/data/vscode/extensions.txt`.

## Features

- ✅ Interactive prompts for optional features (VS Code settings, extensions, iTerm theme, shell prompt, aliases)
- ✅ Automatic VS Code extension installation from external file
- ✅ Dry-run mode (`--dry-run` or `-n`) to preview changes
- ✅ Comprehensive logging to `dev-setup.log` in project root
- ✅ Error collection and reporting system
- ✅ Improved NVM path handling
- ✅ Configuration file (`config.sh`) for customizing all settings

### Configuration File

The setup scripts use a configuration file at the project root: `config.sh`

This file allows you to customize:
- **VS Code settings**: Font size, tab size, theme, icon theme, and other preferences
- **Default prompt answers**: Set defaults for interactive prompts (install VS Code settings, extensions, etc.)
- **Git configuration**: Default branch name
- **Node.js version**: Which Node.js version to install via NVM

**Important**: The `config.sh` file is **required**. If it's missing or contains errors, the script will fail with clear error messages indicating what's wrong.

Example configuration:
```bash
# VS Code Settings
VSCODE_FONT_SIZE=13
VSCODE_TAB_SIZE=4
VSCODE_COLOR_THEME="Visual Studio Dark"

# Default Prompt Answers
PROMPT_INSTALL_VSCODE_SETTINGS=true
PROMPT_INSTALL_SHELL_ALIASES=false

# Git Configuration
GIT_DEFAULT_BRANCH="main"

# Node.js Version
NODE_VERSION="node"  # or specific version like "18.17.0"
```

See `config.sh` in the project root for all available configuration options.
