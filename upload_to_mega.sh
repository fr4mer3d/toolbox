#!/bin/bash

# Define color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Display a stylized banner
echo -e "${RED}"
echo "(       )(  ____ \\(  ____ \\(  ___  )( \\      (  ___  )(  ___  )(  __  \\ "
echo "| () () || (    \\/| (    \\/| (   ) || (      | (   ) || (   ) || (  \\  )"
echo "| || || || (__    | |      | (___) || |      | |   | || (___) || |   ) |"
echo "| |(_)| ||  __)   | | ____ |  ___  || |      | |   | ||  ___  || |   | |"
echo "| |   | || (      | | \\_  )| (   ) || |      | |   | || (   ) || |   ) |"
echo "| )   ( || (____/\\| (___) || )   ( || (____/\\| (___) || )   ( || (__/  )"
echo "|/     \\|(_______/(_______)|/     \\|(_______/(_______)|/     \\|(______/ "
echo "                                                                          "
echo -e "                            by ${RED}fr4mered${NC}                              "
echo "#################################################################################"
echo -e "${NC}"

# Trap errors and exit the script with a custom error message
trap 'error_handler' ERR

# Error handler function
error_handler() {
    echo -e "${RED}An error occurred during execution. Please check the following steps:${NC}"
    echo -e "${YELLOW}1. Ensure you have a stable internet connection."
    echo "2. Verify your MEGA email and password are correct."
    echo "3. If using Tor, ensure the Tor service is running."
    echo "4. Ensure the file path is correct and the file exists."
    exit 1
}

# Function to check if MEGAcmd (mega client tool) is installed
check_megacmd_installed() {
    if ! command -v megacli &> /dev/null; then
        echo -e "${RED}MEGAcmd (mega CLI tool) is not installed.${NC}"
        echo -e "${YELLOW}Please install MEGAcmd before running this script.${NC}"
        exit 1
    else
        echo -e "${GREEN}MEGAcmd is already installed.${NC}"
    fi
}

# Prompt for MEGA login credentials
read -p "Enter your MEGA email: " EMAIL
read -sp "Enter your MEGA password: " PASSWORD
echo ""

# Path to the file you want to upload
FILE_PATH="$1"

# Functions
login_to_mega() {
    # Try to login using the provided credentials
    echo -e "${YELLOW}Attempting to log in to MEGA...${NC}"
    
    # Perform the login, capturing both stdout and stderr
    LOGIN_OUTPUT=$(mega-login "$EMAIL" "$PASSWORD" 2>&1)
    
    # Check the exit code of the previous command to see if the login was successful
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}Login successful!${NC}"
    else
        echo -e "${RED}Login failed: ${LOGIN_OUTPUT}${NC}"
        exit 1
    fi
}

logout_of_mega() {
    mega-logout
    echo -e "${GREEN}Done!${NC}"
}

# Function to generate a random file name
generate_random_name() {
    local random_name=$(date +%s%N | sha256sum | base64 | head -c 12)
    echo "$random_name"
}

upload_file() {
    local FILE_PATH="$1"
    local MEGA_FILE_NAME="$2"

    echo -e "${CYAN}Uploading file: $FILE_PATH${NC}"
    if ! mega-put "$FILE_PATH" "$MEGA_FILE_NAME"; then
        echo -e "${RED}Error: File upload failed. Please check the file path and try again.${NC}"
        logout_of_mega
        exit 1
    fi
    echo -e "${GREEN}File uploaded successfully.${NC}"
}

generate_link() {
    local FILE_NAME="$1"  # Get the file name to export

    echo -e "${CYAN}Generating public link for $FILE_NAME...${NC}"
    
    # Export and generate the public link
    PUBLIC_LINK=$(mega-export -a "$FILE_NAME")

    # Check if the command was successful
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}Public link generated successfully:${NC} $PUBLIC_LINK"
    else
        echo -e "${RED}Error: Failed to generate a public link. Please try again.${NC}"
    fi
}

# Function to check if Tor is installed and running
check_tor_running() {
    # Check if tor is installed
    if ! command -v tor &> /dev/null; then
        echo -e "${RED}Tor is not installed. Please install Tor and try again.${NC}"
        exit 1
    fi

    # Check if tor service is running
    if ! systemctl is-active --quiet tor; then
        echo -e "${RED}Tor service is not running. Please start the Tor service and try again.${NC}"
        exit 1
    fi
    echo -e "${GREEN}Tor is installed and running.${NC}"
}

# Function to configure Tor proxy
configure_tor_proxy() {
    echo -e "${CYAN}Configuring Tor proxy...${NC}"

    # Backup the current proxy settings
    ORIGINAL_HTTP_PROXY="$http_proxy"
    ORIGINAL_HTTPS_PROXY="$https_proxy"

    # Set Tor proxy
    export http_proxy="socks5://127.0.0.1:9050"
    export https_proxy="socks5://127.0.0.1:9050"
}
# Function to reset the proxy settings back to the original values
reset_proxy() {
    echo -e "${CYAN}Resetting proxy settings to original values...${NC}"

    # Revert to the original proxy settings
    export http_proxy="$ORIGINAL_HTTP_PROXY"
    export https_proxy="$ORIGINAL_HTTPS_PROXY"
}

# Main logic
if [ -z "$FILE_PATH" ]; then
    echo -e "${RED}Usage: $0 <path-to-file>${NC}"
    exit 1
fi

# Ensure the file exists
if [ ! -f "$FILE_PATH" ]; then
    echo -e "${RED}Error: The specified file does not exist. Please check the file path and try again.${NC}"
    exit 1
fi

# Check if MEGAcmd is installed
check_megacmd_installed

# Ask if the user wants to use Tor for anonymity
read -p "Do you want to use the Tor network for anonymity? (y/n): " USE_TOR_RESPONSE
if [[ "$USE_TOR_RESPONSE" == "y" || "$USE_TOR_RESPONSE" == "Y" ]]; then
    check_tor_running  # Ensure Tor is installed and running
    configure_tor_proxy  # Configure the Tor proxy
    
    TOR_IP=$(curl --socks5 127.0.0.1:9050 https://ipinfo.io/ip 2>/dev/null)
    echo -e "${GREEN}Congratulations! You're on tor network, your IP address: $TOR_IP${NC}"
fi

# Log in to MEGA
login_to_mega

# Ask the user if they want to provide a custom name for the file on MEGA
read -p "Do you want to provide a custom name for the file in MEGA? (y/n): " CUSTOM_NAME_RESPONSE

if [[ "$CUSTOM_NAME_RESPONSE" == "y" || "$CUSTOM_NAME_RESPONSE" == "Y" ]]; then
    read -p "Enter the custom file name for MEGA: " MEGA_FILE_NAME
else
    # Generate a random name if the user doesn't want to provide one
    MEGA_FILE_NAME=$(generate_random_name)
    echo -e "${YELLOW}No custom name provided. Using random name: $MEGA_FILE_NAME${NC}"
fi

# Upload the file with the chosen name in MEGA
upload_file "$FILE_PATH" "$MEGA_FILE_NAME"

# Ask if user wants to generate a public link
read -p "Do you want to generate a public link for the uploaded file? (y/n): " GENERATE_LINK_RESPONSE

if [[ "$GENERATE_LINK_RESPONSE" == "y" || "$GENERATE_LINK_RESPONSE" == "Y" ]]; then
    # Generate a public link for the uploaded file
    generate_link "$MEGA_FILE_NAME"
else
    echo -e "${YELLOW}Public link generation skipped.${NC}"
fi

# Reset proxy settings if Tor was used
if [[ "$USE_TOR_RESPONSE" == "y" || "$USE_TOR_RESPONSE" == "Y" ]]; then
    reset_proxy
fi

# Log out of MEGA
logout_of_mega

echo -e "${GREEN}Good Bye!${NC}"

