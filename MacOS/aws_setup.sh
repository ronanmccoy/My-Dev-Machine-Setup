#!/bin/bash

# -----------------------------
# AWS CLI Setup Script
# -----------------------------

# ------------------------
# Validation functions
# ------------------------
validate_profile_name() {
    local profile=$1
    
    if [[ -z "$profile" ]]; then
        echo "❌ Error: Profile name cannot be empty."
        return 1
    fi
    
    # AWS profile names can contain letters, numbers, and hyphens/underscores
    # Must start with a letter or number
    if [[ ! "$profile" =~ ^[a-zA-Z0-9][a-zA-Z0-9_-]*$ ]]; then
        echo "❌ Error: Profile name can only contain letters, numbers, hyphens, and underscores, and must start with a letter or number."
        return 1
    fi
    
    # Check length (AWS has a limit, typically 64 characters)
    if [[ ${#profile} -gt 64 ]]; then
        echo "❌ Error: Profile name must be 64 characters or less."
        return 1
    fi
    
    return 0
}

validate_sso_url() {
    local url=$1
    
    if [[ -z "$url" ]]; then
        echo "❌ Error: SSO Start URL cannot be empty."
        return 1
    fi
    
    # Basic URL validation - should start with https://
    if [[ ! "$url" =~ ^https:// ]]; then
        echo "❌ Error: SSO Start URL must start with 'https://'"
        return 1
    fi
    
    # Should contain .awsapps.com or similar AWS SSO domain pattern
    if [[ ! "$url" =~ \.(awsapps\.com|awsapps\.com\.cn) ]]; then
        echo "⚠️  Warning: SSO URL doesn't match typical AWS SSO format (contains .awsapps.com)"
        read -p "Continue anyway? (y/n): " continue_anyway
        if [[ ! "$continue_anyway" =~ ^[Yy]$ ]]; then
            return 1
        fi
    fi
    
    return 0
}

validate_aws_region() {
    local region=$1
    
    if [[ -z "$region" ]]; then
        echo "❌ Error: AWS Region cannot be empty."
        return 1
    fi
    
    # Basic AWS region format validation (e.g., us-east-1, eu-west-2)
    if [[ ! "$region" =~ ^[a-z]+-[a-z]+-[0-9]+$ ]]; then
        echo "❌ Error: Invalid AWS region format. Expected format: us-east-1, eu-west-2, etc."
        return 1
    fi
    
    return 0
}

validate_account_id() {
    local account_id=$1
    
    if [[ -z "$account_id" ]]; then
        echo "❌ Error: AWS Account ID cannot be empty."
        return 1
    fi
    
    # AWS Account IDs are exactly 12 digits
    if [[ ! "$account_id" =~ ^[0-9]{12}$ ]]; then
        echo "❌ Error: AWS Account ID must be exactly 12 digits."
        return 1
    fi
    
    return 0
}

validate_role_name() {
    local role_name=$1
    
    if [[ -z "$role_name" ]]; then
        echo "❌ Error: Role name cannot be empty."
        return 1
    fi
    
    # IAM role names: 1-64 characters, alphanumeric and +=,.@-_
    if [[ ! "$role_name" =~ ^[a-zA-Z0-9+=,.@_-]+$ ]]; then
        echo "❌ Error: Role name contains invalid characters. Allowed: letters, numbers, and +=,.@-_"
        return 1
    fi
    
    if [[ ${#role_name} -lt 1 ]] || [[ ${#role_name} -gt 64 ]]; then
        echo "❌ Error: Role name must be between 1 and 64 characters."
        return 1
    fi
    
    return 0
}

validate_access_key_id() {
    local access_key=$1
    
    if [[ -z "$access_key" ]]; then
        echo "❌ Error: Access Key ID cannot be empty."
        return 1
    fi
    
    # AWS Access Key IDs are typically 20 characters, alphanumeric (case-insensitive)
    # Remove any whitespace
    access_key=$(echo "$access_key" | tr -d '[:space:]')
    
    if [[ ${#access_key} -lt 16 ]] || [[ ${#access_key} -gt 20 ]]; then
        echo "❌ Error: Access Key ID should be between 16 and 20 alphanumeric characters."
        return 1
    fi
    
    # Check for valid alphanumeric characters
    if [[ ! "$access_key" =~ ^[A-Za-z0-9]+$ ]]; then
        echo "❌ Error: Access Key ID can only contain letters and numbers."
        return 1
    fi
    
    return 0
}

validate_secret_access_key() {
    local secret_key=$1
    
    if [[ -z "$secret_key" ]]; then
        echo "❌ Error: Secret Access Key cannot be empty."
        return 1
    fi
    
    # AWS Secret Access Keys are typically 40 characters, base64-like
    if [[ ${#secret_key} -lt 40 ]]; then
        echo "❌ Error: Secret Access Key appears to be too short (minimum 40 characters)."
        return 1
    fi
    
    return 0
}

validate_config_type() {
    local config_type=$1
    
    if [[ -z "$config_type" ]]; then
        echo "❌ Error: Please choose an option (1 or 2)."
        return 1
    fi
    
    if [[ "$config_type" != "1" ]] && [[ "$config_type" != "2" ]]; then
        echo "❌ Error: Invalid choice. Please enter 1 or 2."
        return 1
    fi
    
    return 0
}

# Check if AWS CLI is installed
if ! command -v aws &>/dev/null; then
    echo "☁️ AWS CLI not found. Installing via Homebrew..."
    brew install awscli
    if [ $? -ne 0 ]; then
        echo "❌ Failed to install AWS CLI. Exiting."
        exit 1
    fi
else
    echo "✅ AWS CLI already installed."
fi

# Ask for AWS Profile details
while true; do
    read -p "Enter AWS Profile name: " PROFILE
    if validate_profile_name "$PROFILE"; then
        break
    fi
done

# Ask user if they want SSO or Access Keys
echo "How do you want to configure AWS CLI?"
echo "1) SSO (Single Sign-On)"
echo "2) Access Keys"
while true; do
    read -p "Choose [1 or 2]: " CONFIG_TYPE
    if validate_config_type "$CONFIG_TYPE"; then
        break
    fi
done

if [ "$CONFIG_TYPE" == "1" ]; then
    echo "🔑 Configuring AWS CLI with SSO"
    
    while true; do
        read -p "Enter SSO Start URL: " SSO_START_URL
        if validate_sso_url "$SSO_START_URL"; then
            break
        fi
    done
    
    while true; do
        read -p "Enter SSO Region (e.g. us-east-2): " SSO_REGION
        if validate_aws_region "$SSO_REGION"; then
            break
        fi
    done
    
    while true; do
        read -p "Enter AWS Account ID: " ACCOUNT_ID
        if validate_account_id "$ACCOUNT_ID"; then
            break
        fi
    done
    
    while true; do
        read -p "Enter AWS Role Name: " ROLE_NAME
        if validate_role_name "$ROLE_NAME"; then
            break
        fi
    done
    
    while true; do
        read -p "Enter Default AWS Region (e.g. us-east-2): " REGION
        if validate_aws_region "$REGION"; then
            break
        fi
    done

    aws configure set sso_start_url "$SSO_START_URL" --profile "$PROFILE"
    aws configure set sso_region "$SSO_REGION" --profile "$PROFILE"
    aws configure set sso_account_id "$ACCOUNT_ID" --profile "$PROFILE"
    aws configure set sso_role_name "$ROLE_NAME" --profile "$PROFILE"
    aws configure set region "$REGION" --profile "$PROFILE"
    aws configure set output json --profile "$PROFILE"

    echo "✅ AWS CLI SSO profile '$PROFILE' configured."
    echo "👉 Run 'aws sso login --profile $PROFILE' if prompted."

elif [ "$CONFIG_TYPE" == "2" ]; then
    echo "🔑 Configuring AWS CLI with Access Keys"
    
    while true; do
        read -p "Enter AWS Region (e.g. us-west-2): " REGION
        if validate_aws_region "$REGION"; then
            break
        fi
    done
    
    while true; do
        read -p "Enter AWS Access Key ID: " AWS_ACCESS_KEY_ID
        # Trim whitespace from input
        AWS_ACCESS_KEY_ID=$(echo "$AWS_ACCESS_KEY_ID" | tr -d '[:space:]')
        if validate_access_key_id "$AWS_ACCESS_KEY_ID"; then
            break
        fi
    done
    
    while true; do
        read -s -p "Enter AWS Secret Access Key: " AWS_SECRET_ACCESS_KEY
        echo
        # Trim whitespace from input
        AWS_SECRET_ACCESS_KEY=$(echo "$AWS_SECRET_ACCESS_KEY" | tr -d '[:space:]')
        if validate_secret_access_key "$AWS_SECRET_ACCESS_KEY"; then
            break
        fi
    done

    aws configure set aws_access_key_id "$AWS_ACCESS_KEY_ID" --profile "$PROFILE"
    aws configure set aws_secret_access_key "$AWS_SECRET_ACCESS_KEY" --profile "$PROFILE"
    aws configure set region "$REGION" --profile "$PROFILE"
    aws configure set output json --profile "$PROFILE"

    echo "✅ AWS CLI profile '$PROFILE' configured with Access Keys."
else
    echo "❌ Invalid choice. Exiting."
    exit 1
fi

# -----------------------------
# Test AWS CLI Credentials
# -----------------------------
echo "🔍 Testing AWS CLI credentials for profile '$PROFILE'..."
TEST_OUTPUT=$(aws sts get-caller-identity --profile "$PROFILE" 2>&1)

if [ $? -eq 0 ]; then
    echo "✅ AWS CLI credentials are valid!"
    echo "$TEST_OUTPUT" | jq .
else
    echo "❌ Failed to validate AWS CLI credentials."
    echo "⚠️ Error: $TEST_OUTPUT"
    if [ "$CONFIG_TYPE" == "1" ]; then
        echo "👉 Try running: aws sso login --profile $PROFILE"
    else
        echo "👉 Double-check your Access Key and Secret Key."
    fi
fi

echo
echo "--> done! 👋 "