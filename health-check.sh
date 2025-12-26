#!/bin/bash

# ============================================================================
# Health Check Script for Dev Machine Setup
# ============================================================================
# This script verifies that all components installed by the setup scripts
# are properly installed and configured.
#
# Usage:
#   sh health-check.sh              # Standard check
#   sh health-check.sh --quiet       # Minimal output (only failures)
#   sh health-check.sh --verbose     # Detailed output
#   sh health-check.sh --test-ssh    # Test GitHub SSH connection
#   sh health-check.sh --test-aws    # Test AWS CLI credentials
# ============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$SCRIPT_DIR"
CONFIG_FILE="$PROJECT_ROOT/config.sh"
APP_LIST_FILE="$PROJECT_ROOT/MacOS/apps.txt"
NPM_PACKAGES_FILE="$PROJECT_ROOT/data/packages/packages.txt"
VSCODE_EXTENSIONS_FILE="$PROJECT_ROOT/data/vscode/extensions.txt"

# Parse command line arguments
QUIET=false
VERBOSE=false
TEST_SSH=false
TEST_AWS=false

for arg in "$@"; do
	case "$arg" in
		--quiet|-q)
			QUIET=true
			;;
		--verbose|-v)
			VERBOSE=true
			;;
		--test-ssh)
			TEST_SSH=true
			;;
		--test-aws)
			TEST_AWS=true
			;;
		--help|-h)
			echo "Usage: $0 [OPTIONS]"
			echo ""
			echo "Options:"
			echo "  --quiet, -q       Minimal output (only failures)"
			echo "  --verbose, -v     Detailed output"
			echo "  --test-ssh        Test GitHub SSH connection"
			echo "  --test-aws        Test AWS CLI credentials"
			echo "  --help, -h        Show this help message"
			exit 0
			;;
	esac
done

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Counters
TOTAL_CHECKS=0
PASSED_CHECKS=0
WARNING_CHECKS=0
FAILED_CHECKS=0

# Results arrays
PASSED=()
WARNINGS=()
FAILED=()

# Helper functions
print_pass() {
	local message="$1"
	PASSED+=("$message")
	((PASSED_CHECKS++))
	((TOTAL_CHECKS++))
	if [ "$QUIET" = false ]; then
		echo -e "${GREEN}[✓]${NC} $message"
	fi
}

print_warning() {
	local message="$1"
	WARNINGS+=("$message")
	((WARNING_CHECKS++))
	((TOTAL_CHECKS++))
	if [ "$QUIET" = false ]; then
		echo -e "${YELLOW}[⚠️]${NC} $message"
	fi
}

print_fail() {
	local message="$1"
	FAILED+=("$message")
	((FAILED_CHECKS++))
	((TOTAL_CHECKS++))
	echo -e "${RED}[❌]${NC} $message"
}

print_info() {
	if [ "$VERBOSE" = true ] && [ "$QUIET" = false ]; then
		echo -e "${BLUE}[ℹ]${NC} $1"
	fi
}

# Detect platform
detect_platform() {
	if [[ "$OSTYPE" == "darwin"* ]]; then
		echo "macos"
	elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
		echo "linux"
	elif [[ "$OSTYPE" == "msys" || "$OSTYPE" == "cygwin" ]]; then
		echo "windows"
	else
		echo "unknown"
	fi
}

PLATFORM=$(detect_platform)

# Load configuration
load_config() {
	if [ ! -f "$CONFIG_FILE" ]; then
		print_fail "Configuration file not found: $CONFIG_FILE"
		return 1
	fi
	
	# Source config file
	error_output=$(source "$CONFIG_FILE" 2>&1)
	if [ $? -ne 0 ]; then
		print_fail "Failed to load configuration file: $error_output"
		return 1
	fi
	
	print_pass "Configuration file: Valid"
	return 0
}

# Check Homebrew
check_homebrew() {
	print_info "Checking Homebrew..."
	if command -v brew &> /dev/null; then
		local version=$(brew --version | head -n1)
		print_pass "Homebrew: Installed ($version)"
		return 0
	else
		print_fail "Homebrew: Not installed"
		return 1
	fi
}

# Check installed applications
check_applications() {
	print_info "Checking installed applications..."
	
	if [ ! -f "$APP_LIST_FILE" ]; then
		print_warning "Apps list file not found: $APP_LIST_FILE"
		return 0
	fi
	
	local apps=()
	local app_count=0
	local installed_count=0
	local missing_count=0
	
	# Read apps from file
	while IFS= read -r line || [[ -n "$line" ]]; do
		if [[ -n "$line" && ! "$line" =~ ^[[:space:]]*# ]]; then
			line=$(echo "$line" | xargs)
			if [[ -n "$line" ]]; then
				apps+=("$line")
				((app_count++))
			fi
		fi
	done < "$APP_LIST_FILE"
	
	if [ $app_count -eq 0 ]; then
		print_warning "No applications found in apps.txt"
		return 0
	fi
	
	if [ "$QUIET" = false ]; then
		echo ""
		echo "Applications ($app_count total):"
	fi
	
	for app in "${apps[@]}"; do
		# Check if installed via Homebrew
		if brew list --cask "$app" &> /dev/null 2>&1 || brew list "$app" &> /dev/null 2>&1; then
			((installed_count++))
			if [ "$VERBOSE" = true ]; then
				print_pass "  $app: Installed"
			fi
		else
			# Check if it's a GUI app that might be installed differently
			local app_path=""
			case "$app" in
				visual-studio-code)
					app_path="/Applications/Visual Studio Code.app"
					;;
				iterm2)
					app_path="/Applications/iTerm.app"
					;;
				cursor)
					app_path="/Applications/Cursor.app"
					;;
			esac
			
			if [ -n "$app_path" ] && [ -d "$app_path" ]; then
				((installed_count++))
				if [ "$VERBOSE" = true ]; then
					print_pass "  $app: Installed (found at $app_path)"
				fi
			else
				((missing_count++))
				print_fail "  $app: Not found"
			fi
		fi
	done
	
	if [ $missing_count -eq 0 ]; then
		print_pass "All applications installed ($installed_count/$app_count)"
	else
		print_warning "Some applications missing ($installed_count/$app_count installed, $missing_count missing)"
	fi
}

# Check Node.js and NVM
check_node_nvm() {
	print_info "Checking Node.js and NVM..."
	
	# Check NVM
	if [ -s "$HOME/.nvm/nvm.sh" ] || [ -s "/opt/homebrew/opt/nvm/nvm.sh" ]; then
		# Try to source NVM
		if [ -s "$HOME/.nvm/nvm.sh" ]; then
			source "$HOME/.nvm/nvm.sh" 2>/dev/null
		elif [ -s "/opt/homebrew/opt/nvm/nvm.sh" ]; then
			source "/opt/homebrew/opt/nvm/nvm.sh" 2>/dev/null
		fi
		
		if command -v nvm &> /dev/null; then
			print_pass "NVM: Installed"
		else
			print_warning "NVM: Found but not initialized in current shell"
		fi
	else
		print_warning "NVM: Not found (may need to restart terminal)"
	fi
	
	# Check Node.js
	if command -v node &> /dev/null; then
		local node_version=$(node --version)
		print_pass "Node.js: Installed ($node_version)"
		
		# Check npm
		if command -v npm &> /dev/null; then
			local npm_version=$(npm --version)
			print_pass "npm: Installed (v$npm_version)"
		else
			print_fail "npm: Not found"
		fi
	else
		print_fail "Node.js: Not installed or not in PATH"
	fi
}

# Check NPM global packages
check_npm_packages() {
	print_info "Checking NPM global packages..."
	
	if ! command -v npm &> /dev/null; then
		print_warning "npm not available, skipping NPM package checks"
		return 0
	fi
	
	if [ ! -f "$NPM_PACKAGES_FILE" ]; then
		print_warning "NPM packages file not found: $NPM_PACKAGES_FILE"
		return 0
	fi
	
	local packages=()
	local package_count=0
	local installed_count=0
	local missing_count=0
	
	# Read packages from file
	while IFS= read -r line || [[ -n "$line" ]]; do
		if [[ -n "$line" && ! "$line" =~ ^[[:space:]]*# ]]; then
			line=$(echo "$line" | xargs)
			if [[ -n "$line" && ! "$line" =~ ---[[:space::]]*IGNORE[[:space:]]*--- ]]; then
				packages+=("$line")
				((package_count++))
			fi
		fi
	done < "$NPM_PACKAGES_FILE"
	
	if [ $package_count -eq 0 ]; then
		print_warning "No NPM packages found in packages.txt"
		return 0
	fi
	
	if [ "$QUIET" = false ]; then
		echo ""
		echo "NPM Packages ($package_count total):"
	fi
	
	for package in "${packages[@]}"; do
		if npm list -g --depth=0 "$package" &> /dev/null 2>&1; then
			((installed_count++))
			if [ "$VERBOSE" = true ]; then
				print_pass "  $package: Installed"
			fi
		else
			((missing_count++))
			print_fail "  $package: Not installed"
		fi
	done
	
	if [ $missing_count -eq 0 ]; then
		print_pass "All NPM packages installed ($installed_count/$package_count)"
	else
		print_warning "Some NPM packages missing ($installed_count/$package_count installed, $missing_count missing)"
	fi
}

# Check VS Code
check_vscode() {
	print_info "Checking VS Code..."
	
	local vscode_installed=false
	local vscode_command=false
	
	# Check if VS Code is installed
	if [ -d "/Applications/Visual Studio Code.app" ] || [ -d "$HOME/Applications/Visual Studio Code.app" ]; then
		vscode_installed=true
	fi
	
	# Check if code command is available
	if command -v code &> /dev/null; then
		vscode_command=true
		vscode_installed=true
	fi
	
	if [ "$vscode_installed" = true ]; then
		print_pass "VS Code: Installed"
		
		# Check settings file
		local vscode_settings="$HOME/Library/Application Support/Code/User/settings.json"
		if [ -f "$vscode_settings" ]; then
			print_pass "VS Code settings: Found"
			
			# Verify key settings if config is loaded
			if [ -f "$CONFIG_FILE" ]; then
				source "$CONFIG_FILE" 2>/dev/null
				# Check font size
				if grep -q "\"editor.fontSize\": $VSCODE_FONT_SIZE" "$vscode_settings" 2>/dev/null; then
					if [ "$VERBOSE" = true ]; then
						print_pass "VS Code font size: Correct ($VSCODE_FONT_SIZE)"
					fi
				else
					print_warning "VS Code font size: May not match config"
				fi
			fi
		else
			print_warning "VS Code settings: Not found"
		fi
		
		# Check extensions
		check_vscode_extensions
	else
		print_warning "VS Code: Not installed"
	fi
}

# Check VS Code extensions
check_vscode_extensions() {
	if [ ! -f "$VSCODE_EXTENSIONS_FILE" ]; then
		print_warning "VS Code extensions file not found: $VSCODE_EXTENSIONS_FILE"
		return 0
	fi
	
	if ! command -v code &> /dev/null; then
		print_warning "VS Code command not available, skipping extension check"
		return 0
	fi
	
	local extensions=()
	local extension_count=0
	local installed_count=0
	local missing_count=0
	
	# Get installed extensions
	local installed_extensions=$(code --list-extensions 2>/dev/null)
	
	# Read extensions from file
	while IFS= read -r line || [[ -n "$line" ]]; do
		if [[ -n "$line" && ! "$line" =~ ^[[:space:]]*# ]]; then
			line=$(echo "$line" | xargs)
			if [[ -n "$line" ]]; then
				extensions+=("$line")
				((extension_count++))
			fi
		fi
	done < "$VSCODE_EXTENSIONS_FILE"
	
	if [ $extension_count -eq 0 ]; then
		print_warning "No VS Code extensions found in extensions.txt"
		return 0
	fi
	
	if [ "$QUIET" = false ]; then
		echo ""
		echo "VS Code Extensions ($extension_count total):"
	fi
	
	for extension in "${extensions[@]}"; do
		if echo "$installed_extensions" | grep -q "^${extension}$"; then
			((installed_count++))
			if [ "$VERBOSE" = true ]; then
				print_pass "  $extension: Installed"
			fi
		else
			((missing_count++))
			print_fail "  $extension: Not installed"
		fi
	done
	
	if [ $missing_count -eq 0 ]; then
		print_pass "All VS Code extensions installed ($installed_count/$extension_count)"
	else
		print_warning "Some VS Code extensions missing ($installed_count/$extension_count installed, $missing_count missing)"
	fi
}

# Check Git configuration
check_git() {
	print_info "Checking Git configuration..."
	
	if ! command -v git &> /dev/null; then
		print_fail "Git: Not installed"
		return 1
	fi
	
	local git_version=$(git --version)
	print_pass "Git: Installed ($git_version)"
	
	# Check global config
	local user_name=$(git config --global user.name 2>/dev/null)
	local user_email=$(git config --global user.email 2>/dev/null)
	local default_branch=$(git config --global init.defaultBranch 2>/dev/null)
	
	if [ -n "$user_name" ]; then
		print_pass "Git user.name: Set ($user_name)"
	else
		print_fail "Git user.name: Not configured"
	fi
	
	if [ -n "$user_email" ]; then
		print_pass "Git user.email: Set ($user_email)"
	else
		print_fail "Git user.email: Not configured"
	fi
	
	if [ -n "$default_branch" ]; then
		if [ -f "$CONFIG_FILE" ]; then
			source "$CONFIG_FILE" 2>/dev/null
			if [ "$default_branch" = "$GIT_DEFAULT_BRANCH" ]; then
				print_pass "Git default branch: Correct ($default_branch)"
			else
				print_warning "Git default branch: Set to '$default_branch' (config expects '$GIT_DEFAULT_BRANCH')"
			fi
		else
			print_pass "Git default branch: Set ($default_branch)"
		fi
	else
		print_warning "Git default branch: Not configured"
	fi
	
	# Check SSH key
	local ssh_key_found=false
	if [ -f "$HOME/.ssh/id_ed25519" ]; then
		ssh_key_found=true
		print_pass "SSH key: Found (id_ed25519)"
	elif [ -f "$HOME/.ssh/id_rsa" ]; then
		ssh_key_found=true
		print_pass "SSH key: Found (id_rsa)"
	else
		print_warning "SSH key: Not found"
	fi
	
	# Test SSH connection if requested
	if [ "$TEST_SSH" = true ] && [ "$ssh_key_found" = true ]; then
		print_info "Testing GitHub SSH connection..."
		if ssh -T git@github.com &> /dev/null 2>&1; then
			print_pass "GitHub SSH: Connection successful"
		else
			local ssh_output=$(ssh -T git@github.com 2>&1)
			if echo "$ssh_output" | grep -q "successfully authenticated"; then
				print_pass "GitHub SSH: Authenticated"
			else
				print_warning "GitHub SSH: Connection test failed (key may not be added to GitHub)"
			fi
		fi
	fi
}

# Check AWS CLI
check_aws() {
	print_info "Checking AWS CLI..."
	
	if ! command -v aws &> /dev/null; then
		print_warning "AWS CLI: Not installed"
		return 0
	fi
	
	local aws_version=$(aws --version 2>/dev/null)
	print_pass "AWS CLI: Installed ($aws_version)"
	
	# Check for configured profiles
	local profiles=$(aws configure list-profiles 2>/dev/null)
	if [ -n "$profiles" ]; then
		local profile_count=$(echo "$profiles" | wc -l | xargs)
		print_pass "AWS profiles: Found ($profile_count profile(s))"
		
		# Test credentials if requested
		if [ "$TEST_AWS" = true ]; then
			print_info "Testing AWS CLI credentials..."
			for profile in $profiles; do
				if aws sts get-caller-identity --profile "$profile" &> /dev/null 2>&1; then
					print_pass "AWS profile '$profile': Credentials valid"
				else
					print_warning "AWS profile '$profile': Credentials test failed (may need SSO login)"
				fi
			done
		fi
	else
		print_warning "AWS profiles: None configured"
	fi
}

# Check iTerm theme
check_iterm_theme() {
	print_info "Checking iTerm theme..."
	
	if [ ! -d "/Applications/iTerm.app" ]; then
		print_warning "iTerm: Not installed"
		return 0
	fi
	
	print_pass "iTerm: Installed"
	
	local theme_dir="$HOME/Library/Application Support/iTerm2/DynamicProfiles"
	local theme_file="$PROJECT_ROOT/data/themes/iTerm-Ronans-Theme.json"
	
	if [ -f "$theme_file" ]; then
		local theme_name=$(basename "$theme_file")
		if [ -f "$theme_dir/$theme_name" ]; then
			print_pass "iTerm theme: Installed"
		else
			print_warning "iTerm theme: Not found in DynamicProfiles"
		fi
	else
		print_warning "iTerm theme file: Not found in project"
	fi
}

# Check shell profile customizations
check_shell_profile() {
	print_info "Checking shell profile customizations..."
	
	local shell_profile=""
	if [ -f "$HOME/.zshrc" ]; then
		shell_profile="$HOME/.zshrc"
	elif [ -f "$HOME/.bash_profile" ]; then
		shell_profile="$HOME/.bash_profile"
	elif [ -f "$HOME/.bashrc" ]; then
		shell_profile="$HOME/.bashrc"
	fi
	
	if [ -z "$shell_profile" ]; then
		print_warning "Shell profile: Not found"
		return 0
	fi
	
	print_pass "Shell profile: Found ($(basename $shell_profile))"
	
	# Check for NVM setup
	if grep -q "nvm.sh" "$shell_profile" 2>/dev/null; then
		print_pass "NVM setup: Found in shell profile"
	else
		print_warning "NVM setup: Not found in shell profile"
	fi
	
	# Check for custom prompt
	if grep -q "# Custom prompt" "$shell_profile" 2>/dev/null; then
		print_pass "Custom prompt: Found in shell profile"
	else
		print_warning "Custom prompt: Not found in shell profile"
	fi
	
	# Check for custom aliases
	if grep -q "# Custom Aliases" "$shell_profile" 2>/dev/null; then
		print_pass "Custom aliases: Found in shell profile"
	else
		print_warning "Custom aliases: Not found in shell profile"
	fi
}

# Main execution
main() {
	echo "=========================================="
	echo "HEALTH CHECK REPORT"
	echo "=========================================="
	echo ""
	
	# Load configuration first
	if ! load_config; then
		echo ""
		echo "Cannot continue without valid configuration file."
		exit 1
	fi
	echo ""
	
	# Run checks
	check_homebrew
	check_node_nvm
	check_applications
	check_npm_packages
	check_vscode
	check_git
	check_aws
	check_iterm_theme
	check_shell_profile
	
	# Print summary
	echo ""
	echo "=========================================="
	echo "SUMMARY"
	echo "=========================================="
	echo "Total Checks: $TOTAL_CHECKS"
	echo -e "${GREEN}Passed: $PASSED_CHECKS${NC}"
	if [ $WARNING_CHECKS -gt 0 ]; then
		echo -e "${YELLOW}Warnings: $WARNING_CHECKS${NC}"
	fi
	if [ $FAILED_CHECKS -gt 0 ]; then
		echo -e "${RED}Failed: $FAILED_CHECKS${NC}"
	fi
	echo ""
	
	# Determine exit code
	if [ $FAILED_CHECKS -gt 0 ]; then
		echo -e "${RED}❌ Health check found failures${NC}"
		exit 1
	elif [ $WARNING_CHECKS -gt 0 ]; then
		echo -e "${YELLOW}⚠️  Health check completed with warnings${NC}"
		exit 2
	else
		echo -e "${GREEN}✓ All checks passed!${NC}"
		exit 0
	fi
}

# Run main function
main

