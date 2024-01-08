#!/bin/bash

# Exit codes for the script
# 0: Success
# 1: Insufficient user rights
# 2: Unsupported package manager
# 3: pkglist not found
# 4: Installation aborted
# 5: Unknown option provided

# Set the package list filename
PGKF="./pkglist"

# Get the script directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

# Set the full path to the package list file
PGKF_PATH="$SCRIPT_DIR/$PGKF"

# Detect package manager
detect_package_manager() {
    if command -v apt-get &> /dev/null; then
        PACKAGE_MANAGER="apt"
    elif command -v pacman &> /dev/null; then
        PACKAGE_MANAGER="pacman"
    elif command -v dnf &> /dev/null; then
        PACKAGE_MANAGER="dnf"
    elif command -v yum &> /dev/null; then
        PACKAGE_MANAGER="yum"
    elif command -v zypper &> /dev/null; then
        PACKAGE_MANAGER="zypper"
    else
        echo "Error: Unsupported package manager. Exiting."
        exit 2 # Unsupported package manager
    fi
}

# Display help message
display_help() {
    echo "Usage: $0 [OPTIONS]"
    echo "Options:"
    echo "  -c, --count               Display the count of installed packages."
    echo "  -g, --generate            Generate a text file of all installed packages."
    echo "  -i, --install             Install all packages from the generated list."
    echo "  -h, --help                Display this help message."
    echo
    echo "Optional:"
    echo "  -a, --all                 Skip confirmation for installation. (Must follow -i, --install; otherwise, it will be ignored)"
    echo "  -f, --file FILE           Specify input/output file."
    echo
    echo "Example:"
    echo "  $0 --count"
    echo "  $0 --generate"
    echo "  $0 --install"
    echo "  $0 --install --all"
    echo "  $0 -c -g -i"
}

check_permissions() {
    # Check if the script is run as root or sudo is available
    if [ "$(id -u)" != "0" ] && ! command -v sudo &> /dev/null ; then
        echo "Error: This script must be run as root or with sudo. Exiting."
        exit 1
    fi

    # Validate the current user has sudo permissions
    if [ "$(id -u)" != "0" ] && ! sudo -l >/dev/null 2>&1 ; then
        echo "Error: User does not have sudo permissions. Exiting."
        exit 1
    fi
}

# Get the count of installed packages
get_package_count() {
    case $PACKAGE_MANAGER in
        apt)
            dpkg --get-selections | grep -c -E '\sinstall$'
            ;;
        pacman)
            pacman -Q | wc -l
            ;;
        dnf|yum)
            yum list installed | grep -c -E '\.[a-zA-Z]'
            ;;
        zypper)
            zypper se --installed-only | grep -c -E '\.[a-zA-Z]'
            ;;
        *)
            echo "Error: Unsupported package manager. Exiting." >&2
            exit 2  # Unsupported package manager
            ;;
    esac
    return 0  # Success
}

# Generate a text file of all installed packages
generate_package_list() {
    case $PACKAGE_MANAGER in
        apt)
            dpkg --get-selections > "$PGKF_PATH"
            ;;
        pacman)
            pacman -Qq > "$PGKF_PATH"
            ;;
        dnf|yum)
            yum list installed | grep -E '\.[a-zA-Z]' | awk '{print $1}' > "$PGKF_PATH"
            ;;
        zypper)
            zypper se --installed-only | grep -E '\.[a-zA-Z]' | awk '{print $3}' > "$PGKF_PATH"
            ;;
        *)
            echo "Error: Unsupported package manager. Exiting." >&2
            exit 2  # Unsupported package manager
            ;;
    esac

    chmod 644 $PGKF_PATH
    chown $USER:$USER $PGKF_PATH

    echo "List of installed packages saved to '$PGKF_PATH'."
    return 0  # Success
}

# Function to check the position of -i and ensure -a follows it
check_skip_confirm() {
    local POSITION_I=0
    local POSITION_A=0

    # Iterate through command-line arguments
    for ((position=1; position<=$#; position++)); do
        arg="${!position}"

        if [ "$arg" == "-i" ] || [ "$arg" == "--install" ]; then
            POSITION_I=$position
        elif [ "$arg" == "-a" ] || [ "$arg" == "--all" ]; then
            POSITION_A=$position
        fi
    done

    # Increment POSITION_I to ensure that skip_confirm follows arg -i
    ((POSITION_I++))

    if [ "$POSITION_A" == "$POSITION_I" ]; then
        SKIP_CONFIRM="true"
    else
        SKIP_CONFIRM="false"
    fi
}

# Install packages from the generated list
install_packages() {
    local WITH_SUDO

    check_permissions $USER

    if [ ! -f "$PGKF_PATH" ]; then
        echo "Error: No pkglist found at $PGKF_PATH. Exiting." >&2
        exit 3 # pkglist not found
    fi

    if [ "$SKIP_CONFIRM" == "true" ]; then
        CONFIRM="y"
    else
        read -p "Do you want to install all packages? (y/N): " CONFIRM
    fi


    if [ "$CONFIRM" == "y" ] || [ "$CONFIRM" == "Y" ]; then

        # If the user isn't root add sudo to commands
        if [ "$(id -u)" != "0" ]; then
            WITH_SUDO="sudo"
        fi


        case $PACKAGE_MANAGER in
            apt)
                #$WITH_SUDO dpkg --set-selections < "$PGKF_PATH"
                #$WITH_SUDO apt-get -y dselect-upgrade
                ;;
            pacman)
                #$WITH_SUDO pacman -S --needed - < "$PGKF_PATH"
                ;;
            dnf|yum)
                #$WITH_SUDO yum install $(cat "$PGKF_PATH")
                ;;
            zypper)
                #$WITH_SUDO zypper install $(cat "$PGKF_PATH")
                ;;
        esac
        echo "All packages installed successfully."
        return 0  # Success
    else
        echo "Installation aborted." >&2
        exit 4  # Installation aborted
    fi
}

# If no options are provided, display help message
if [ "$#" -eq 0 ]; then
    display_help
fi

# Main script logic
detect_package_manager

check_skip_confirm $@

# Main processing loop
while [[ "$#" -gt 0 ]]; do
    case $1 in
        -a|--all)
            # Placeholder
            ;;
        -c|--count)
            get_package_count
            ;;
        -f|--file)
            echo "Not yet implemented. Because using a while loop with shift would be hacky"
            echo "At this point, it's handy to use Python with the argparse"
            ;;
        -g|--generate)
            generate_package_list
            ;;
        -i|--install)
            install_packages
            ;;
        -h|--help)
            display_help
            ;;
        *)
            echo
            echo "Unknown option: $1. Use -h or --help for help."
            exit 5
            ;;
    esac
    shift
done

exit 0
