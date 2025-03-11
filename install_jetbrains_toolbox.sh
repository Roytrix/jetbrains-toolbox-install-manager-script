#!/bin/bash

#  ██████╗  ██████╗ ██╗   ██╗████████╗██████╗ ██╗██╗  ██╗
#  ██╔══██╗██╔═══██╗╚██╗ ██╔╝╚══██╔══╝██╔══██╗██║╚██╗██╔╝
#  ██████╔╝██║   ██║ ╚████╔╝    ██║   ██████╔╝██║ ╚███╔╝
#  ██╔══██╗██║   ██║  ╚██╔╝     ██║   ██╔══██╗██║ ██╔██╗
#  ██║  ██║╚██████╔╝   ██║      ██║   ██║  ██║██║██╔╝ ██╗
#  ╚═╝  ╚═╝ ╚═════╝    ╚═╝      ╚═╝   ╚═╝  ╚═╝╚═╝  ╚═╝
#       [01001010 01000101 01010100 01000010 01010010 01000001 01001001 01001110 01010011]

# Define variables
DOWNLOAD_PAGE="https://data.services.jetbrains.com/products/releases?code=TBA&latest=true&type=release"
JB_PRODUCTS_API="https://data.services.jetbrains.com/products"
DOWNLOAD_DIR="$HOME/Downloads"
INSTALL_DIR="$HOME/.local/share/jetbrains-toolbox"
DESKTOP_ENTRY="$HOME/.local/share/applications/jetbrains-toolbox.desktop"
LOG_FILE="/tmp/jetbrains-toolbox-install.log"

# Display warning about compatibility
echo "===================================================================="
echo "WARNING: This script has only been tested on Red Hat Enterprise Linux 9"
echo "It may not work properly on other Linux distributions."
echo "===================================================================="
echo ""

# Function to show usage
show_usage() {
  echo "Usage: $0 [options]"
  echo "Options:"
  echo "  --install       Install JetBrains Toolbox (default)"
  echo "  --uninstall     Uninstall JetBrains Toolbox"
  echo "  --status        Show currently running JetBrains tools"
  echo "  --help          Display this help and exit"
}

# Check for required dependencies
check_dependencies() {
  echo "Checking dependencies..."
  for cmd in curl wget tar grep find sudo; do
    if ! command -v "$cmd" &>/dev/null; then
      echo "Error: Required command '$cmd' not found. Please install it and try again."
      exit 1
    fi
  done
}

# Check for sudo privileges
check_sudo() {
  # No longer required for local installation
  log "Using local installation directory: ${INSTALL_DIR}"
  return 0
}

# Function to clean up in case of failure
cleanup() {
  echo "Cleaning up downloaded files and directories..."
  [ -f "${DOWNLOAD_DIR}/jetbrains-toolbox-${TOOLBOX_VERSION}.tar.gz" ] && rm "${DOWNLOAD_DIR}/jetbrains-toolbox-${TOOLBOX_VERSION}.tar.gz"
  [ -d "${INSTALL_DIR}" ] && rm -rf "${INSTALL_DIR}"
  [ -f "${DESKTOP_ENTRY}" ] && rm "${DESKTOP_ENTRY}"
  echo "Cleanup complete."
}

# Log function
log() {
  echo "$1"
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >>"$LOG_FILE"
}

# Trap any error and call cleanup
trap 'error_message=$?; echo "An error occurred on line $LINENO: $BASH_COMMAND."; echo "Error code: $error_message"; echo "Starting cleanup..."; cleanup; exit 1' ERR
error_message=0

# Function to get all JetBrains products
get_jetbrains_products() {
  log "Fetching list of JetBrains products..."
  local RESPONSE
  RESPONSE=$(curl -s "$JB_PRODUCTS_API")
  if [ -z "$RESPONSE" ]; then
    log "Error: Could not fetch JetBrains products list. API might be unreachable."
    # Return essential products if API call fails
    echo "jetbrains-toolbox idea pycharm webstorm phpstorm rubymine clion goland datagrip rider dataspell rustrover fleet"
    return
  fi

  # Define a list of essential JetBrains product identifiers (lowercase)
  local ESSENTIAL_PRODUCTS="jetbrains-toolbox idea intellij pycharm webstorm phpstorm rubymine clion goland datagrip rider dataspell rustrover fleet"

  # Extract product codes from API response
  local PRODUCT_LIST
  PRODUCT_LIST=$(grep -oP '"code":\s*"\K[^"]+' <<<"$RESPONSE" | tr '[:upper:]' '[:lower:]')

  # Return unique and essential product identifiers
  echo "$ESSENTIAL_PRODUCTS $PRODUCT_LIST" | tr ' ' '\n' | grep -v '^$' | sort | uniq | tr '\n' ' '
}

# Function to check if any JetBrains tools are running
check_running_jetbrains_tools() {
  echo "Checking if any JetBrains tools are running..."

  # Get the list of JetBrains products
  local JETBRAINS_PATTERNS
  JETBRAINS_PATTERNS=$(get_jetbrains_products)
  echo "Checking for these JetBrains tools: $JETBRAINS_PATTERNS"

  # Use arrays instead of space-separated strings to properly handle multiple items
  declare -a RUNNING_TOOLS_ARRAY=()
  declare -a RUNNING_PIDS_ARRAY=()

  for pattern in $JETBRAINS_PATTERNS; do
    # Skip empty patterns and this script itself
    if [ -z "$pattern" ] || [ "$pattern" == "install_jetbrains_toolbox.sh" ]; then
      continue
    fi

    # Get PIDs of processes that match the pattern and contain JetBrains keywords in their command line
    local PIDS
    PIDS=$(pgrep -f "$pattern" | grep -i "jetbrains\|\.jbr\|\.idea\|jetbrains-toolbox")

    if [ -n "$PIDS" ]; then
      for PID in $PIDS; do
        # Double check if it's a JetBrains tool by examining command line
        local CMDLINE
        CMDLINE=$(tr '\0' ' ' </proc/"$PID"/cmdline 2>/dev/null)

        # Define JB product keywords in a more manageable way
        local JB_KEYWORDS=("jetbrains" "JetBrains" "idea" "pycharm" "webstorm" "phpstorm" "rubymine" "rider" "clion" "goland" "datagrip")
        local is_jetbrains_tool=0

        for keyword in "${JB_KEYWORDS[@]}"; do
          if [[ "$CMDLINE" == *"$keyword"* ]]; then
            is_jetbrains_tool=1
            break
          fi
        done

        if [ "$is_jetbrains_tool" -eq 1 ] && [[ "$CMDLINE" != *"install_jetbrains_toolbox.sh"* ]]; then
          local TOOL_NAME
          TOOL_NAME=$(ps -p "$PID" -o comm= | head -n1)
          RUNNING_TOOLS_ARRAY+=("$TOOL_NAME")
          RUNNING_PIDS_ARRAY+=("$PID")
        fi
      done
    fi
  done

  # Convert arrays back to space-separated strings for compatibility with rest of script
  RUNNING_TOOLS="${RUNNING_TOOLS_ARRAY[*]}"
  RUNNING_PIDS="${RUNNING_PIDS_ARRAY[*]}"

  if [ "${#RUNNING_TOOLS_ARRAY[@]}" -gt 0 ]; then
    echo "Found running JetBrains tools: $RUNNING_TOOLS"
    return 0 # Tools are running
  else
    echo "No JetBrains tools are currently running."
    return 1 # No tools running
  fi
}

# Function to close all running JetBrains tools
close_running_jetbrains_tools() {
  log "Attempting to close all running JetBrains tools..."

  RUNNING_PIDS=""

  # Get current script's PID and parent PID to avoid killing ourselves
  SCRIPT_PID=$$
  PARENT_PID=$PPID

  # Find JetBrains processes - look specifically in JetBrains directories
  PROCESSES=$(pgrep -af "JetBrains\|jetbrains" | grep -v "install_jetbrains_toolbox.sh")

  # Process the output to identify main and helper processes
  while read -r line; do
    if [ -n "$line" ]; then
      PID=$(echo "$line" | awk '{print $1}')
      CMD=$(echo "$line" | cut -d' ' -f3-)

      # Skip our own processes and parent processes
      if [ "$PID" -eq "$SCRIPT_PID" ] || [ "$PID" -eq "$PARENT_PID" ] || [[ "$CMD" == *"install_jetbrains_toolbox.sh"* ]]; then
        continue
      fi

      # Only kill processes that are clearly JetBrains tools
      if [[ "$CMD" == *"/JetBrains/"* || "$CMD" == *"jetbrains"* || "$CMD" == *"jetbrains-toolbox"* ]]; then
        RUNNING_PIDS="$RUNNING_PIDS $PID"
        TOOL_NAME=$(ps -p "$PID" -o comm= | head -n1)
        log "Closing $TOOL_NAME process: $PID"
        kill "$PID" 2>/dev/null
      fi
    fi
  done <<<"$PROCESSES"

  # Wait for processes to terminate with polling
  log "Waiting for processes to terminate..."
  max_wait=10       # Maximum wait time in seconds
  wait_interval=0.5 # Check interval in seconds
  wait_time=0

  while [ "$wait_time" -lt "$max_wait" ]; do
    # Check if any target processes are still running
    still_running=false
    for PID in $RUNNING_PIDS; do
      if kill -0 "$PID" 2>/dev/null; then
        still_running=true
        break
      fi
    done

    # If no processes are running anymore, we're done
    if ! $still_running; then
      log "All JetBrains processes terminated successfully."
      return
    fi

    # Wait a bit before checking again
    wait_time=$(echo "$wait_time + $wait_interval" | bc)
    sleep "$wait_interval"
  done

  # If we get here, some processes are still running after timeout - force kill them
  log "Some processes did not terminate gracefully. Force closing..."
  for PID in $RUNNING_PIDS; do
    if kill -0 "$PID" 2>/dev/null; then
      TOOL_NAME=$(ps -p "$PID" -o comm= 2>/dev/null || echo "unknown")
      log "Force closing $TOOL_NAME process: $PID"
      kill -9 "$PID" 2>/dev/null
    fi
  done
}

# Function to uninstall JetBrains Toolbox
uninstall() {
  log "Starting JetBrains Toolbox uninstallation..."

  # Check if JetBrains Toolbox is installed
  if [ ! -d "${INSTALL_DIR}" ] && [ ! -f "${DESKTOP_ENTRY}" ]; then
    echo "JetBrains Toolbox does not appear to be installed."
    echo "No installation found at ${INSTALL_DIR}"
    echo "No desktop entry found at ${DESKTOP_ENTRY}"
    read -p "Do you want to continue anyway? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
      log "Uninstallation cancelled by user."
      exit 0
    fi
  fi

  # Ask for confirmation
  read -p "This will uninstall JetBrains Toolbox from ${INSTALL_DIR}. Continue? (y/n) " -n 1 -r
  echo
  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    log "Uninstallation cancelled by user."
    exit 0
  fi

  # Check if JetBrains Toolbox is running and close it
  log "Checking if JetBrains Toolbox is running..."
  TOOLBOX_PID=$(pgrep -f jetbrains-toolbox)
  if [ -n "$TOOLBOX_PID" ]; then
    log "JetBrains Toolbox is running with PID(s): $TOOLBOX_PID"
    log "Attempting to gracefully close JetBrains Toolbox..."

    # Try graceful termination first
    kill "$TOOLBOX_PID" 2>/dev/null

    # Give it some time to close
    sleep 2

    # Check if it's still running
    if pgrep -f jetbrains-toolbox >/dev/null; then
      log "JetBrains Toolbox is still running. Force closing..."
      kill -9 "$(pgrep -f jetbrains-toolbox)" 2>/dev/null
      sleep 1
    fi

    log "JetBrains Toolbox has been closed."
  else
    log "JetBrains Toolbox is not running."
  fi

  # Check and show if any JetBrains tools are running
  log "Checking for running JetBrains tools..."
  # Use the show_running_tools function to display detailed information
  if show_running_tools; then
    log "Warning: Some JetBrains tools are still running."
    read -p "Do you want to close all running JetBrains tools? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
      close_running_jetbrains_tools
    else
      log "Continuing uninstallation with running JetBrains tools. This might cause issues."
    fi
  fi

  # Remove the installation directory
  if [ -d "${INSTALL_DIR}" ]; then
    log "Removing installation directory: ${INSTALL_DIR}"
    rm -rf "${INSTALL_DIR}"
  else
    log "Installation directory not found: ${INSTALL_DIR}"
  fi

  # Remove the desktop entry
  if [ -f "${DESKTOP_ENTRY}" ]; then
    log "Removing desktop entry: ${DESKTOP_ENTRY}"
    rm "${DESKTOP_ENTRY}"
  else
    log "Desktop entry not found: ${DESKTOP_ENTRY}"
  fi

  log "Uninstallation complete. JetBrains Toolbox has been removed from your system."
}

# Function to display currently running JetBrains tools
show_running_tools() {
  # Check if any JetBrains tools are running
  if check_running_jetbrains_tools; then
    echo "Running JetBrains tools: $RUNNING_TOOLS"
    return 0
  else
    echo "No JetBrains tools are currently running."
    return 1
  fi
}

# Main installation process
install() {
  log "Starting JetBrains Toolbox installation..."

  # Check dependencies
  check_dependencies

  # Create directories if they don't exist
  mkdir -p "${INSTALL_DIR}"
  mkdir -p "$(dirname "${DESKTOP_ENTRY}")"

  # Ask for confirmation
  read -p "This will install JetBrains Toolbox to ${INSTALL_DIR}. Continue? (y/n) " -n 1 -r
  echo
  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    log "Installation cancelled by user."
    exit 0
  fi

  # Get the latest version and download URL
  log "Fetching the latest version of JetBrains Toolbox App..."
  RESPONSE=$(curl -s "$DOWNLOAD_PAGE")
  FULL_DOWNLOAD_URL=$(echo "$RESPONSE" | grep -oP '"linux":\{"link":"[^"]+' | sed 's/"linux":{"link":"//')

  log "Using download URL: $FULL_DOWNLOAD_URL"

  # Check if FULL_DOWNLOAD_URL is empty
  if [ -z "$FULL_DOWNLOAD_URL" ]; then
    log "Error: Could not fetch the download URL. Check the connection and the download page."
    log "Starting cleanup..."
    cleanup
    exit 1
  fi

  # Extract the full version number from the URL before .tar.gz
  TOOLBOX_VERSION=$(echo "$FULL_DOWNLOAD_URL" | grep -oP 'jetbrains-toolbox-\K[^.]+(\.[^.]+)*(?=\.tar\.gz)')
  log "Detected toolbox version: ${TOOLBOX_VERSION}"

  # Download with progress
  log "Downloading JetBrains Toolbox App version ${TOOLBOX_VERSION} from ${FULL_DOWNLOAD_URL}..."
  wget -O "${DOWNLOAD_DIR}/jetbrains-toolbox-${TOOLBOX_VERSION}.tar.gz" "${FULL_DOWNLOAD_URL}" --progress=bar:force 2>&1

  # Create installation directory
  log "Creating installation directory at ${INSTALL_DIR}..."
  mkdir -p "${INSTALL_DIR}"

  # Extract the Toolbox App with feedback
  log "Extracting JetBrains Toolbox App to ${INSTALL_DIR}..."
  tar -xzf "${DOWNLOAD_DIR}/jetbrains-toolbox-${TOOLBOX_VERSION}.tar.gz" -C "${INSTALL_DIR}" --verbose

  # Find the exact path to the executable
  TOOLBOX_EXECUTABLE=$(find "${INSTALL_DIR}" -name "jetbrains-toolbox" -type f)
  if [ -z "$TOOLBOX_EXECUTABLE" ]; then
    log "Error: jetbrains-toolbox executable not found after extraction."
    log "Starting cleanup..."
    cleanup
    exit 1
  fi

  log "Found toolbox executable at: ${TOOLBOX_EXECUTABLE}"

  # Find the icon file
  ICON_PATH=$(find "${INSTALL_DIR}" -name "jetbrains-toolbox.svg" -type f)
  if [ -z "$ICON_PATH" ]; then
    log "Warning: Could not find the icon file. Using default path."
    ICON_PATH="${INSTALL_DIR}/jetbrains-toolbox-${TOOLBOX_VERSION}/jetbrains-toolbox.svg"
  else
    log "Found icon at: ${ICON_PATH}"
  fi

  # Create a desktop entry for the Toolbox App
  log "Creating desktop entry at ${DESKTOP_ENTRY}..."
  tee "${DESKTOP_ENTRY}" >/dev/null <<EOL
[Desktop Entry]
Version=1.0
Type=Application
Name=JetBrains Toolbox
Exec=${TOOLBOX_EXECUTABLE}
Icon=${ICON_PATH}
Comment=JetBrains Toolbox
Categories=Development;IDE;
Terminal=false
EOL

  # Run the Toolbox App
  log "Running JetBrains Toolbox App..."
  "${TOOLBOX_EXECUTABLE}" &

  # Delete the downloaded tar.gz file
  log "Deleting the downloaded tar.gz file..."
  rm "${DOWNLOAD_DIR}/jetbrains-toolbox-${TOOLBOX_VERSION}.tar.gz"

  log "Installation complete. JetBrains Toolbox is now running."
}

# Main function
main() {
  # Show welcome message and options if no arguments provided
  if [ $# -eq 0 ]; then
    echo "JetBrains Toolbox Installer/Uninstaller"
    echo "======================================="
    echo "This script is brought to you by:"
    echo ""
    echo "  ██████╗  ██████╗ ██╗   ██╗████████╗██████╗ ██╗██╗  ██╗"
    echo "  ██╔══██╗██╔═══██╗╚██╗ ██╔╝╚══██╔══╝██╔══██╗██║╚██╗██╔╝"
    echo "  ██████╔╝██║   ██║ ╚████╔╝    ██║   ██████╔╝██║ ╚███╔╝ "
    echo "  ██╔══██╗██║   ██║  ╚██╔╝     ██║   ██╔══██╗██║ ██╔██╗ "
    echo "  ██║  ██║╚██████╔╝   ██║      ██║   ██║  ██║██║██╔╝ ██╗"
    echo "  ╚═╝  ╚═╝ ╚═════╝    ╚═╝      ╚═╝   ╚═╝  ╚═╝╚═╝  ╚═╝"
    echo "       [01001010 01000101 01010100 01000010 01010010 01000001 01001001 01001110 01010011]"
    echo ""
    show_usage
    echo ""

    # Ask the user to choose an operation
    echo "Please choose an operation:"
    echo "1) Install JetBrains Toolbox"
    echo "2) Uninstall JetBrains Toolbox"
    echo "3) Show running JetBrains tools"
    echo "4) Exit"
    read -r -p "Enter your choice (1-4): " choice

    case $choice in
      1)
        OPERATION="install"
        ;;
      2)
        OPERATION="uninstall"
        ;;
      3)
        OPERATION="status"
        ;;
      4 | *)
        echo "Exiting..."
        exit 0
        ;;
    esac
  else
    # Parse command line arguments
    OPERATION="install"

    while [[ $# -gt 0 ]]; do
      case "$1" in
        --install)
          OPERATION="install"
          shift
          ;;
        --uninstall)
          OPERATION="uninstall"
          shift
          ;;
        --status)
          OPERATION="status"
          shift
          ;;
        --help)
          show_usage
          exit 0
          ;;
        *)
          echo "Unknown option: $1"
          show_usage
          exit 1
          ;;
      esac
    done
  fi

  # Perform the requested operation
  if [ "$OPERATION" = "install" ]; then
    install
  elif [ "$OPERATION" = "uninstall" ]; then
    uninstall
  elif [ "$OPERATION" = "status" ]; then
    # Call show_running_tools but handle its return value separately
    # to prevent triggering the ERR trap on normal "no tools running" condition
    show_running_tools || true
  else
    echo "Invalid operation: $OPERATION"
    show_usage
    exit 1
  fi
}

# Run main function with all command line arguments
main "$@"
