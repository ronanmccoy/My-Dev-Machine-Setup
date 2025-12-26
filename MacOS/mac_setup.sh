#!/bin/bash

# ----------------------------------------------------------------
#	README
#	This script will install Homebrew, if it's not already 
#	installed, and then install a list of apps defined below.
#	It will then 
#	    - update VS Code with some basic settings,
#		- install VS Code extensions,
#		- add a custom theme to iTerm,
#		- customize shell prompt and aliases (with prompts)
#
#	When complete, it will list any errors that occurred during
#	installation, unless they caused the script to fail completely.
#
#	IMPORTANT NOTE: the iTerm theme file, iTerm-Ronans-Theme.json
#	is expected to be in a folder called `themes` that's one level
#	above where this script is.
# ----------------------------------------------------------------

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
APP_LIST_FILE="$SCRIPT_DIR/apps.txt"
NPM_PACKAGES_FILE="$SCRIPT_DIR/../data/packages/packages.txt"
VSCODE_EXTENSIONS_FILE="$SCRIPT_DIR/../data/vscode/extensions.txt"
ITERM_THEME_FILE="$SCRIPT_DIR/../data/themes/iTerm-Ronans-Theme.json"
LOG_FILE="$PROJECT_ROOT/dev-setup.log"
CONFIG_FILE="$PROJECT_ROOT/config.sh"

# ------------------------
# Configuration loading and validation
# ------------------------
load_config() {
	local config_file="$CONFIG_FILE"
	
	# Check if config file exists
	if [ ! -f "$config_file" ]; then
		echo "❌ Error: Configuration file not found at: $config_file"
		echo "   Please create config.sh in the project root directory."
		echo "   You can copy config.sh.example if one exists, or create it manually."
		exit 1
	fi
	
	# Try to source the config file and capture any errors
	local error_output
	error_output=$(source "$config_file" 2>&1)
	local source_exit_code=$?
	
	if [ $source_exit_code -ne 0 ]; then
		echo "❌ Error: Failed to load configuration file due to syntax error."
		echo "   File: $config_file"
		echo "   Error details:"
		echo "   $error_output"
		echo ""
		echo "   Please check the syntax of your config.sh file."
		echo "   Common issues:"
		echo "   - Missing quotes around values with spaces"
		echo "   - Invalid variable names"
		echo "   - Syntax errors in variable assignments"
		exit 1
	fi
	
	# Validate required variables are set
	local missing_vars=()
	local invalid_vars=()
	
	# Check VS Code settings
	[ -z "${VSCODE_FONT_SIZE:-}" ] && missing_vars+=("VSCODE_FONT_SIZE")
	[ -z "${VSCODE_TAB_SIZE:-}" ] && missing_vars+=("VSCODE_TAB_SIZE")
	[ -z "${VSCODE_COLOR_THEME:-}" ] && missing_vars+=("VSCODE_COLOR_THEME")
	[ -z "${VSCODE_ICON_THEME:-}" ] && missing_vars+=("VSCODE_ICON_THEME")
	[ -z "${VSCODE_FORMAT_ON_SAVE:-}" ] && missing_vars+=("VSCODE_FORMAT_ON_SAVE")
	[ -z "${VSCODE_AUTO_SAVE:-}" ] && missing_vars+=("VSCODE_AUTO_SAVE")
	[ -z "${VSCODE_DEFAULT_FORMATTER:-}" ] && missing_vars+=("VSCODE_DEFAULT_FORMATTER")
	[ -z "${VSCODE_WORD_WRAP:-}" ] && missing_vars+=("VSCODE_WORD_WRAP")
	
	# Check prompt defaults
	[ -z "${PROMPT_INSTALL_VSCODE_SETTINGS:-}" ] && missing_vars+=("PROMPT_INSTALL_VSCODE_SETTINGS")
	[ -z "${PROMPT_INSTALL_VSCODE_EXTENSIONS:-}" ] && missing_vars+=("PROMPT_INSTALL_VSCODE_EXTENSIONS")
	[ -z "${PROMPT_INSTALL_ITERM_THEME:-}" ] && missing_vars+=("PROMPT_INSTALL_ITERM_THEME")
	[ -z "${PROMPT_INSTALL_SHELL_PROMPT:-}" ] && missing_vars+=("PROMPT_INSTALL_SHELL_PROMPT")
	[ -z "${PROMPT_INSTALL_SHELL_ALIASES:-}" ] && missing_vars+=("PROMPT_INSTALL_SHELL_ALIASES")
	
	# Check git config
	[ -z "${GIT_DEFAULT_BRANCH:-}" ] && missing_vars+=("GIT_DEFAULT_BRANCH")
	
	# Check node config
	[ -z "${NODE_VERSION:-}" ] && missing_vars+=("NODE_VERSION")
	
	# Report missing variables
	if [ ${#missing_vars[@]} -ne 0 ]; then
		echo "❌ Error: Configuration file is missing required variables:"
		for var in "${missing_vars[@]}"; do
			echo "   - $var"
		done
		echo ""
		echo "   Please ensure all required variables are set in: $config_file"
		exit 1
	fi
	
	# Validate boolean values
	local bool_vars=(
		"VSCODE_FORMAT_ON_SAVE"
		"PROMPT_INSTALL_VSCODE_SETTINGS"
		"PROMPT_INSTALL_VSCODE_EXTENSIONS"
		"PROMPT_INSTALL_ITERM_THEME"
		"PROMPT_INSTALL_SHELL_PROMPT"
		"PROMPT_INSTALL_SHELL_ALIASES"
	)
	
	for var in "${bool_vars[@]}"; do
		local value="${!var}"
		if [[ "$value" != "true" && "$value" != "false" ]]; then
			invalid_vars+=("$var (must be 'true' or 'false', got: '$value')")
		fi
	done
	
	# Validate numeric values
	if ! [[ "$VSCODE_FONT_SIZE" =~ ^[0-9]+$ ]] || [ "$VSCODE_FONT_SIZE" -lt 8 ] || [ "$VSCODE_FONT_SIZE" -gt 48 ]; then
		invalid_vars+=("VSCODE_FONT_SIZE (must be a number between 8 and 48, got: '$VSCODE_FONT_SIZE')")
	fi
	
	if ! [[ "$VSCODE_TAB_SIZE" =~ ^[0-9]+$ ]] || [ "$VSCODE_TAB_SIZE" -lt 1 ] || [ "$VSCODE_TAB_SIZE" -gt 8 ]; then
		invalid_vars+=("VSCODE_TAB_SIZE (must be a number between 1 and 8, got: '$VSCODE_TAB_SIZE')")
	fi
	
	# Report invalid values
	if [ ${#invalid_vars[@]} -ne 0 ]; then
		echo "❌ Error: Configuration file contains invalid values:"
		for var in "${invalid_vars[@]}"; do
			echo "   - $var"
		done
		echo ""
		echo "   Please fix these values in: $config_file"
		exit 1
	fi
	
	return 0
}

# Load configuration (this will exit if config is invalid)
load_config

# ------------------------
# Dry-run mode detection
# ------------------------
DRY_RUN=false
if [[ "$1" == "--dry-run" ]] || [[ "$1" == "-n" ]]; then
	DRY_RUN=true
	echo "=========================================="
	echo "DRY RUN MODE - No changes will be made"
	echo "=========================================="
	echo
fi

# ------------------------
# Logging system
# ------------------------
log() {
	local level="$1"
	shift
	local message="$*"
	local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
	local log_entry="[$timestamp] [$level] $message"
	
	# Write to log file (append mode)
	echo "$log_entry" >> "$LOG_FILE"
	
	# Also output to console
	echo "$message"
}

log_info() {
	log "INFO" "$@"
}

log_warning() {
	log "WARNING" "$@"
}

log_error() {
	log "ERROR" "$@"
}

# Initialize log file
echo "[$(date '+%Y-%m-%d %H:%M:%S')] ========================================" >> "$LOG_FILE"
if [ "$DRY_RUN" = true ]; then
	echo "[$(date '+%Y-%m-%d %H:%M:%S')] DRY RUN MODE ENABLED" >> "$LOG_FILE"
else
	echo "[$(date '+%Y-%m-%d %H:%M:%S')] Setup script started" >> "$LOG_FILE"
fi
echo "[$(date '+%Y-%m-%d %H:%M:%S')] ========================================" >> "$LOG_FILE"

# ------------------------
# Error collection system
# ------------------------
ERRORS=()
CRITICAL_ERRORS=()

# Function to collect non-critical errors
collect_error() {
    local error_msg="$1"
    ERRORS+=("$error_msg")
    log_warning "⚠️  $error_msg"
}

# Function to collect critical errors (will cause script to exit)
collect_critical_error() {
    local error_msg="$1"
    CRITICAL_ERRORS+=("$error_msg")
    log_error "❌ Critical Error: $error_msg"
}

# Function to display all collected errors at the end
display_errors() {
    if [ ${#CRITICAL_ERRORS[@]} -ne 0 ]; then
        echo
        echo "=========================================="
        echo "CRITICAL ERRORS (Script cannot continue):"
        echo "=========================================="
        for error in "${CRITICAL_ERRORS[@]}"; do
            echo "  ❌ $error"
        done
        return 1
    fi
    
    if [ ${#ERRORS[@]} -ne 0 ]; then
        echo
        echo "=========================================="
        echo "NON-CRITICAL ERRORS (Review and fix manually):"
        echo "=========================================="
        for error in "${ERRORS[@]}"; do
            echo "  ⚠️  $error"
        done
        return 1
    fi
    
    return 0
}

# ------------------------
# Interactive prompt function
# ------------------------
prompt_yes_no() {
    local prompt_text="$1"
    local default="${2:-n}"  # Default to 'no' if not specified
    
    # In dry-run mode, use defaults and log what would be asked
    if [ "$DRY_RUN" = true ]; then
        log_info "[DRY RUN] Would prompt: $prompt_text (default: $default)"
        if [[ "$default" == "y" ]]; then
            return 0
        else
            return 1
        fi
    fi
    
    while true; do
        if [[ "$default" == "y" ]]; then
            read -p "$prompt_text (Y/n): " response
            response="${response:-y}"
        else
            read -p "$prompt_text (y/N): " response
            response="${response:-n}"
        fi
        
        case "$response" in
            [Yy]* ) 
                log_info "User answered 'yes' to: $prompt_text"
                return 0;;
            [Nn]* ) 
                log_info "User answered 'no' to: $prompt_text"
                return 1;;
            * ) echo "Please answer yes (y) or no (n).";;
        esac
    done
}

# ------------------------
# Initialize NVM properly
# ------------------------
init_nvm() {
    # Try multiple methods to find and initialize NVM
    local nvm_paths=(
        "$HOME/.nvm/nvm.sh"
        "/opt/homebrew/opt/nvm/nvm.sh"
        "/usr/local/opt/nvm/nvm.sh"
    )
    
    # First, try to source from common locations
    for nvm_path in "${nvm_paths[@]}"; do
        if [ -s "$nvm_path" ]; then
            source "$nvm_path"
            if command -v nvm &> /dev/null; then
                return 0
            fi
        fi
    done
    
    # If NVM was installed via Homebrew, it might need to be in PATH
    # Check if nvm directory exists but wasn't sourced
    if [ -d "$HOME/.nvm" ]; then
        export NVM_DIR="$HOME/.nvm"
        if [ -s "$NVM_DIR/nvm.sh" ]; then
            source "$NVM_DIR/nvm.sh"
            if command -v nvm &> /dev/null; then
                return 0
            fi
        fi
    fi
    
    # Check Homebrew installation location
    if [ -d "/opt/homebrew/opt/nvm" ]; then
        export NVM_DIR="/opt/homebrew/opt/nvm"
        if [ -s "$NVM_DIR/nvm.sh" ]; then
            source "$NVM_DIR/nvm.sh"
            if command -v nvm &> /dev/null; then
                return 0
            fi
        fi
    fi
    
    return 1
}

# ------------------------
# check for homebrew
# ------------------------
if ! command -v brew &> /dev/null; then
	log_info "--> homebrew is not installed. Let's try and install it..."
	if [ "$DRY_RUN" = true ]; then
		log_info "[DRY RUN] Would run: /bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
		log_info "[DRY RUN] Would add brew to PATH"
	else
		if /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"; then
			# add brew to PATH
			if [[ -f "/opt/homebrew/bin/brew" ]]; then
				eval "$(/opt/homebrew/bin/brew shellenv)"
			elif [[ -f "/usr/local/bin/brew" ]]; then
				eval "$(/usr/local/bin/brew shellenv)"
			fi
			log_info "--> homebrew installed successfully"
		else
			collect_critical_error "Failed to install Homebrew. Cannot continue."
			display_errors
			exit 1
		fi
	fi
else
	log_info "--> homebrew is already installed."
fi

# ------------------------
# apps for installation
# ------------------------
APPS=()
FAILED_APPS=()

# get apps list from file
log_info "--> reading apps list from $APP_LIST_FILE"
if [ ! -f "$APP_LIST_FILE" ]; then
	collect_critical_error "apps.txt file not found at $APP_LIST_FILE"
	display_errors
	exit 1
fi

while IFS= read -r line || [[ -n "$line" ]]; do
    # Skip empty lines and lines starting with #
    if [[ -n "$line" && ! "$line" =~ ^[[:space:]]*# ]]; then
        # Trim whitespace
        line=$(echo "$line" | xargs)
        if [[ -n "$line" ]]; then
            APPS+=("$line")
        fi
    fi
done < "$APP_LIST_FILE"

log_info "--> Found ${#APPS[@]} app(s) to install"

if [ "$DRY_RUN" = true ]; then
	log_info "--> [DRY RUN] Would install the following apps:"
	for app in "${APPS[@]}"; do
		log_info "  [DRY RUN] Would run: brew install --cask $app (or brew install $app)"
	done
else
	log_info "--> installing apps..."
	for app in "${APPS[@]}"; do
		log_info "--> installing $app..."
		if brew install --cask "$app" &> /dev/null || brew install "$app" &> /dev/null; then
			log_info "	✓ installed"
		else
			FAILED_APPS+=("$app")
			collect_error "Failed to install app: $app"
		fi
	done
fi

# ------------------------
# Initialize NVM and install Node
# ------------------------
log_info "--> initializing NVM..."
if init_nvm; then
	log_info "	✓ NVM initialized"
	
	# Install Node.js via NVM
	if [ "$DRY_RUN" = true ]; then
		log_info "[DRY RUN] Would run: nvm install $NODE_VERSION"
		log_info "[DRY RUN] Would run: nvm use $NODE_VERSION"
		log_info "[DRY RUN] Would run: nvm alias default $NODE_VERSION"
	else
		log_info "--> installing node version: $NODE_VERSION via nvm..."
		if nvm install "$NODE_VERSION"; then
			nvm use "$NODE_VERSION"
			nvm alias default "$NODE_VERSION"
			log_info "	✓ Node.js $NODE_VERSION installed via NVM"
		else
			collect_error "Failed to install Node.js $NODE_VERSION via NVM"
		fi
	fi
else
	collect_error "NVM not found. Node.js installation skipped. Install NVM manually or ensure it's in your PATH."
fi

# ------------------------
# Global NPM packages
# ------------------------
NPM_PACKAGES=()
FAILED_NPM_PACKAGES=()

# get npm packages list from file
log_info "--> reading npm packages list from $NPM_PACKAGES_FILE"
if [ ! -f "$NPM_PACKAGES_FILE" ]; then
	collect_error "packages.txt file not found at $NPM_PACKAGES_FILE"
else
	while IFS= read -r line || [[ -n "$line" ]]; do
		# Skip empty lines and lines starting with #
		if [[ -n "$line" && ! "$line" =~ ^[[:space:]]*# ]]; then
			# Trim whitespace
			line=$(echo "$line" | xargs)
			if [[ -n "$line" && ! "$line" =~ ---[[:space::]]*IGNORE[[:space:]]*--- ]]; then
				NPM_PACKAGES+=("$line")
			fi
		fi
	done < "$NPM_PACKAGES_FILE"
	log_info "--> Found ${#NPM_PACKAGES[@]} npm package(s) to install"
fi

if command -v npm &> /dev/null || [ "$DRY_RUN" = true ]; then
	if [ "$DRY_RUN" = true ]; then
		log_info "--> [DRY RUN] Would install the following npm packages:"
		for package in "${NPM_PACKAGES[@]}"; do
			log_info "  [DRY RUN] Would run: npm install -g $package"
		done
	else
		log_info "--> installing global npm packages..."
		for package in "${NPM_PACKAGES[@]}"; do
			log_info "--> installing $package..."
			if npm install -g "$package" &> /dev/null; then
				log_info "	✓ installed"
			else
				FAILED_NPM_PACKAGES+=("$package")
				collect_error "Failed to install npm package: $package"
			fi
		done
	fi
else
	collect_error "npm is not available. Skipping npm package installation."
fi

# ------------------------
# VS Code settings and extensions
# ------------------------
VSCODE_SETTINGS="$HOME/Library/Application Support/Code/User/settings.json"
VSCODE_INSTALLED=false

if [ -d "/Applications/Visual Studio Code.app" ] || [ -d "$HOME/Applications/Visual Studio Code.app" ] || command -v code &> /dev/null; then
	VSCODE_INSTALLED=true
	
	# Prompt for VS Code settings
	local vscode_settings_default="y"
	if [ "$PROMPT_INSTALL_VSCODE_SETTINGS" = "false" ]; then
		vscode_settings_default="n"
	fi
	if prompt_yes_no "Do you want to update VS Code settings?" "$vscode_settings_default"; then
		if [ "$DRY_RUN" = true ]; then
			log_info "[DRY RUN] Would update VS Code settings at: $VSCODE_SETTINGS"
			if [ -f "$VSCODE_SETTINGS" ]; then
				log_info "[DRY RUN] Would backup existing settings"
			fi
			log_info "[DRY RUN] Would write new settings.json with configured preferences"
		else
			log_info "--> updating VS Code settings..."
			mkdir -p "$(dirname "$VSCODE_SETTINGS")"
			
			# Backup existing settings if they exist
			if [ -f "$VSCODE_SETTINGS" ]; then
				cp "$VSCODE_SETTINGS" "$VSCODE_SETTINGS.backup.$(date +%Y%m%d_%H%M%S)"
				log_info "	✓ Backed up existing settings"
			fi
			
			# Convert boolean to JSON boolean
			local format_on_save_json="true"
			if [ "$VSCODE_FORMAT_ON_SAVE" = "false" ]; then
				format_on_save_json="false"
			fi
			
			cat > "$VSCODE_SETTINGS" <<EOL
{
	"editor.fontSize": $VSCODE_FONT_SIZE,
	"editor.formatOnSave": $format_on_save_json,
	"files.autoSave": "$VSCODE_AUTO_SAVE",
	"editor.defaultFormatter": "$VSCODE_DEFAULT_FORMATTER",
	"editor.wordWrap": "$VSCODE_WORD_WRAP",
	"workbench.colorTheme": "$VSCODE_COLOR_THEME",
	"workbench.iconTheme": "$VSCODE_ICON_THEME",
	"editor.tabSize": $VSCODE_TAB_SIZE
}
EOL
			log_info "	✓ VS Code settings updated"
		fi
	else
		log_info "--> skipping VS Code settings update"
	fi
	
	# Install VS Code extensions
	local vscode_extensions_default="y"
	if [ "$PROMPT_INSTALL_VSCODE_EXTENSIONS" = "false" ]; then
		vscode_extensions_default="n"
	fi
	if prompt_yes_no "Do you want to install VS Code extensions?" "$vscode_extensions_default"; then
		if [ ! -f "$VSCODE_EXTENSIONS_FILE" ]; then
			collect_error "VS Code extensions file not found at $VSCODE_EXTENSIONS_FILE"
		else
			if [ "$DRY_RUN" = true ]; then
				log_info "--> [DRY RUN] Would install VS Code extensions..."
				VSCODE_EXTENSIONS=()
				while IFS= read -r line || [[ -n "$line" ]]; do
					if [[ -n "$line" && ! "$line" =~ ^[[:space:]]*# ]]; then
						line=$(echo "$line" | xargs)
						if [[ -n "$line" ]]; then
							VSCODE_EXTENSIONS+=("$line")
							log_info "  [DRY RUN] Would run: code --install-extension $line --force"
						fi
					fi
				done < "$VSCODE_EXTENSIONS_FILE"
			else
				log_info "--> installing VS Code extensions..."
				VSCODE_EXTENSIONS=()
				FAILED_EXTENSIONS=()
				
				# Read extensions from file
				while IFS= read -r line || [[ -n "$line" ]]; do
					if [[ -n "$line" && ! "$line" =~ ^[[:space:]]*# ]]; then
						line=$(echo "$line" | xargs)
						if [[ -n "$line" ]]; then
							VSCODE_EXTENSIONS+=("$line")
						fi
					fi
				done < "$VSCODE_EXTENSIONS_FILE"
				
				# Install each extension
				for extension in "${VSCODE_EXTENSIONS[@]}"; do
					log_info "--> installing extension: $extension..."
					if code --install-extension "$extension" --force &> /dev/null; then
						log_info "	✓ installed"
					else
						FAILED_EXTENSIONS+=("$extension")
						collect_error "Failed to install VS Code extension: $extension"
					fi
				done
				
				if [ ${#FAILED_EXTENSIONS[@]} -eq 0 ]; then
					log_info "	✓ All VS Code extensions installed successfully"
				fi
			fi
		fi
	else
		log_info "--> skipping VS Code extensions installation"
	fi
else
	collect_error "VS Code is not installed. Skipping VS Code configuration."
fi

# ------------------------
# Set iTerm theme
# ------------------------
THEME_FILE="$ITERM_THEME_FILE"
PROFILE_DIR="$HOME/Library/Application Support/iTerm2/DynamicProfiles"

if [ -d "/Applications/iTerm.app" ]; then
	local iterm_theme_default="y"
	if [ "$PROMPT_INSTALL_ITERM_THEME" = "false" ]; then
		iterm_theme_default="n"
	fi
	if prompt_yes_no "Do you want to install the iTerm theme?" "$iterm_theme_default"; then
		if [ "$DRY_RUN" = true ]; then
			if [ -f "$THEME_FILE" ]; then
				log_info "[DRY RUN] Would copy iTerm theme from: $THEME_FILE"
				log_info "[DRY RUN] Would copy to: $PROFILE_DIR/"
			else
				collect_error "iTerm theme file not found ($THEME_FILE)"
			fi
		else
			if [ -f "$THEME_FILE" ]; then
				mkdir -p "$PROFILE_DIR"
				if cp "$THEME_FILE" "$PROFILE_DIR/"; then
					log_info "	✓ imported iTerm theme file. You can select it in Settings -> Profiles"
				else
					collect_error "Failed to copy iTerm theme file"
				fi
			else
				collect_error "iTerm theme file not found ($THEME_FILE)"
			fi
		fi
	else
		log_info "--> skipping iTerm theme installation"
	fi
else
	collect_error "iTerm is not installed. Skipping iTerm theme installation."
fi

# ------------------------------------
# Add customizations to shell profile
# ------------------------------------
SHELL_PROFILE="$HOME/.zshrc"

if [[ $SHELL == *"bash"* ]]; then
	SHELL_PROFILE="$HOME/.bash_profile"
fi

# Add NVM to shell profile if needed
if command -v nvm &> /dev/null || init_nvm; then
	if ! grep -q "nvm.sh" "$SHELL_PROFILE" 2>/dev/null; then
		if [ "$DRY_RUN" = true ]; then
			log_info "[DRY RUN] Would add NVM setup to: $SHELL_PROFILE"
		else
			log_info "--> adding nvm to shell profile for future sessions..."
			
			echo '' >> "$SHELL_PROFILE"
			echo '#--------------------------------' >> "$SHELL_PROFILE"
			echo '# NVM setup' >> "$SHELL_PROFILE"
			echo '#--------------------------------' >> "$SHELL_PROFILE"
			echo 'export NVM_DIR="$HOME/.nvm"' >> "$SHELL_PROFILE"
			echo '[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"' >> "$SHELL_PROFILE"
			echo '[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"' >> "$SHELL_PROFILE"
			
			log_info "	✓ nvm setup added to $SHELL_PROFILE"
		fi
	fi
fi

# Prompt for custom shell prompt
local shell_prompt_default="y"
if [ "$PROMPT_INSTALL_SHELL_PROMPT" = "false" ]; then
	shell_prompt_default="n"
fi
if prompt_yes_no "Do you want to set up a custom shell prompt with git branch information?" "$shell_prompt_default"; then
	if ! grep -q "# Custom prompt" "$SHELL_PROFILE" 2>/dev/null; then
		if [ "$DRY_RUN" = true ]; then
			log_info "[DRY RUN] Would add custom prompt configuration to: $SHELL_PROFILE"
		else
			log_info "--> adding custom prompt to shell profile..."
			
			echo '' >> "$SHELL_PROFILE"
			echo '#--------------------------------' >> "$SHELL_PROFILE"
			echo '# Custom prompt' >> "$SHELL_PROFILE"
			echo '#--------------------------------' >> "$SHELL_PROFILE"
			echo '# load version control info' >> "$SHELL_PROFILE"
			echo 'autoload -Uz vcs_info' >> "$SHELL_PROFILE"
			echo 'precmd() { vcs_info }' >> "$SHELL_PROFILE"
			echo '# format the text of the prompt' >> "$SHELL_PROFILE"
			echo 'zstyle ":vcs_info:git:*" formats "%F{201}<%b>%f"' >> "$SHELL_PROFILE"
			echo '# add git branch name to the prompt' >> "$SHELL_PROFILE"
			echo 'setopt PROMPT_SUBST' >> "$SHELL_PROFILE"
			echo 'PROMPT="%n@%m %F{255}%2~/%f${vcs_info_msg_0_}: "' >> "$SHELL_PROFILE"
			
			log_info "	✓ custom prompt added"
		fi
	else
		log_info "	✓ custom prompt already exists in shell profile"
	fi
else
	log_info "--> skipping custom prompt setup"
fi

# Prompt for custom aliases
local shell_aliases_default="y"
if [ "$PROMPT_INSTALL_SHELL_ALIASES" = "false" ]; then
	shell_aliases_default="n"
fi
if prompt_yes_no "Do you want to add custom shell aliases?" "$shell_aliases_default"; then
	if ! grep -q "# Custom Aliases" "$SHELL_PROFILE" 2>/dev/null; then
		if [ "$DRY_RUN" = true ]; then
			log_info "[DRY RUN] Would add custom aliases to: $SHELL_PROFILE"
		else
			log_info "--> adding custom aliases to shell profile..."
			
			echo '' >> "$SHELL_PROFILE"
			echo '#--------------------------------' >> "$SHELL_PROFILE"
			echo '# Custom Aliases' >> "$SHELL_PROFILE"
			echo '#--------------------------------' >> "$SHELL_PROFILE"
			echo 'alias lsa="ls -alG"' >> "$SHELL_PROFILE"
			echo 'alias ll="ls -lG"' >> "$SHELL_PROFILE"
			echo 'alias cd..="cd .."' >> "$SHELL_PROFILE"
			echo 'alias cd...="cd ../.."' >> "$SHELL_PROFILE"
			echo 'alias cd....="cd ../../.."' >> "$SHELL_PROFILE"
			echo 'alias showhosts="cat /etc/hosts"' >> "$SHELL_PROFILE"
			echo 'alias updatehosts="sudo nano /etc/hosts"' >> "$SHELL_PROFILE"
			echo 'alias path="echo -e ${PATH//:/\\n}"' >> "$SHELL_PROFILE"
			echo 'alias f="open -a Finder ./"' >> "$SHELL_PROFILE"
			echo 'alias reload="source ~/.zshrc"' >> "$SHELL_PROFILE"
			echo 'alias cls="clear"' >> "$SHELL_PROFILE"
			echo 'alias gits="git status"' >> "$SHELL_PROFILE"
			echo 'alias gita="git add ."' >> "$SHELL_PROFILE"
			echo 'alias gitaa="git add -A"' >> "$SHELL_PROFILE"
			echo 'alias gitc="git commit -m"' >> "$SHELL_PROFILE"
			echo 'alias gitp="git push"' >> "$SHELL_PROFILE"
			echo 'alias gitpl="git pull"' >> "$SHELL_PROFILE"
			echo 'alias gitco="git checkout"' >> "$SHELL_PROFILE"
			echo 'alias gitbr="git branch"' >> "$SHELL_PROFILE"
			echo 'alias gitcl="git clone"' >> "$SHELL_PROFILE"
			echo 'alias gitdiff="git diff"' >> "$SHELL_PROFILE"
			echo 'alias gitlg="git log --oneline --graph --decorate --all"' >> "$SHELL_PROFILE"
			
			log_info "	✓ custom aliases added"
		fi
	else
		log_info "	✓ custom aliases already exist in shell profile"
	fi
else
	log_info "--> skipping custom aliases setup"
fi

# --------------------------------
# Display summary and errors
# --------------------------------
echo
echo "=========================================="
if [ "$DRY_RUN" = true ]; then
	echo "DRY RUN SUMMARY"
else
	echo "INSTALLATION SUMMARY"
fi
echo "=========================================="

if [ "$DRY_RUN" = true ]; then
	log_info "This was a dry run. No changes were made to your system."
	log_info "Review the log file at: $LOG_FILE"
else
	if [ ${#FAILED_APPS[@]} -eq 0 ]; then
		log_info "✓ All apps installed successfully"
	else
		log_warning "⚠️  ${#FAILED_APPS[@]} app(s) failed to install"
	fi

	if [ ${#FAILED_NPM_PACKAGES[@]} -eq 0 ] && command -v npm &> /dev/null; then
		log_info "✓ All npm packages installed successfully"
	elif [ ${#FAILED_NPM_PACKAGES[@]} -ne 0 ]; then
		log_warning "⚠️  ${#FAILED_NPM_PACKAGES[@]} npm package(s) failed to install"
	fi
fi

# Display all collected errors
if ! display_errors; then
	echo
	log_warning "Please review the errors above and fix them manually if needed."
fi

echo
echo "=========================================="
echo "NEXT STEPS"
echo "=========================================="
if [ "$DRY_RUN" = true ]; then
	log_info "To run the actual setup, execute: sh mac_setup.sh"
else
	log_info "1. Restart your terminal for all changes to take effect"
	log_info "2. Run the git setup script: sh git_setup.sh"
	log_info "3. (Optional) Run the AWS setup script: sh aws_setup.sh"
	log_info "Log file saved at: $LOG_FILE"
fi
echo
log_info "--> finished! 👋"

# Log script completion
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Setup script completed" >> "$LOG_FILE"
if [ "$DRY_RUN" = true ]; then
	echo "[$(date '+%Y-%m-%d %H:%M:%S')] DRY RUN MODE - No changes were made" >> "$LOG_FILE"
fi
echo "[$(date '+%Y-%m-%d %H:%M:%S')] ========================================" >> "$LOG_FILE"
