#!/usr/bin/env bash

set -euo pipefail

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Detect OS and check prerequisites
detect_os() {
    case "$(uname -s)" in
        Darwin*)
            OS="macos"
            ;;
        Linux*)
            OS="linux"
            ;;
        CYGWIN*|MINGW*|MSYS*)
            print_error "Windows is not supported by this script"
            exit 1
            ;;
        *)
            print_error "Unsupported operating system: $(uname -s)"
            exit 1
            ;;
    esac
}

# Helper functions
print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if YubiKey is connected and tools are installed
check_prerequisites() {
    detect_os
    
    if ! command -v ssh-keygen &> /dev/null; then
        print_error "ssh-keygen is not installed."
        if [[ "$OS" == "macos" ]]; then
            print_error "Please install openssh with: brew install openssh"
        elif [[ "$OS" == "linux" ]]; then
            print_error "Please install openssh with your package manager"
        fi
        exit 1
    fi
    
    if [[ "$OS" == "linux" ]]; then
        if ! command -v fido2-token &> /dev/null; then
            print_error "libfido2 is not installed."
            print_error "Please install it with your package manager (e.g., paru -S libfido2)"
            exit 1
        fi
    fi
    
    # Check if YubiKey is connected by trying to list FIDO2 tokens
    if [[ "$OS" == "linux" ]]; then
        if ! fido2-token -L &> /dev/null; then
            print_error "No FIDO2 tokens detected. Make sure your YubiKey is connected."
            exit 1
        fi
    else
        # For macOS, we'll rely on ssh-keygen to detect the device
        print_info "Detected macOS - FIDO2 device detection will be handled by ssh-keygen"
    fi
}

# Get FIDO2 device path (Linux only)
get_device_path() {
    if [[ "$OS" == "linux" ]]; then
        local device_path
        device_path=$(fido2-token -L 2>/dev/null | head -n1 | awk '{print $1}' | sed 's/:$//')
        if [[ -z "$device_path" ]]; then
            print_error "Could not find FIDO2 device path"
            return 1
        fi
        echo "$device_path"
    else
        echo ""  # Not needed on macOS
    fi
}

# Display main menu
show_menu() {
    echo ""
    echo "=================================="
    echo "   YubiKey SSH Key Manager (FIDO2)"
    echo "=================================="
    echo "1. Create new SSH key"
    echo "2. List all SSH keys on YubiKey"
    echo "3. Export keys to current directory"
    echo "4. Delete SSH key"
    echo "5. Show YubiKey info"
    echo "6. Exit"
    echo "=================================="
    echo -n "Please select an option [1-6]: "
}

# Create new SSH key
create_ssh_key() {
    echo
    print_info "Creating a new FIDO2 SSH key..."
    
    read -p "Enter application suffix (leave empty for default 'ssh:', or enter identifier like 'github' for 'ssh:github'): " app_suffix
    read -p "Enter a description/comment for this key: " description
    read -p "Enter filename to save the key (e.g., 'yubikey_github'): " filename
    
    [[ -z "$description" ]] && description="FIDO2 SSH Key"
    [[ -z "$filename" ]] && filename="yubikey_fido2_key"
    
    # Always use ssh: as base, add suffix if provided
    local app_id="ssh"
    if [[ -n "$app_suffix" ]]; then
        app_id="ssh:$app_suffix"
    fi
    
    # Prepare ssh-keygen command
    local ssh_args="-t ed25519-sk -O resident -O verify-required -O application=$app_id"
    ssh_args="$ssh_args -C \"$description\""
    
    print_info "Using application identifier: $app_id"
    print_info "Generating key with options: $ssh_args"
    print_warning "You will need to touch your YubiKey when prompted"
    
    # Use a temporary location first, then move to avoid overwrite prompts
    local temp_key="/tmp/${filename}_temp"
    
    if eval "ssh-keygen $ssh_args -f \"$temp_key\""; then
        # Move files to current directory
        mv "$temp_key" "./$filename"
        mv "${temp_key}.pub" "./${filename}.pub"
        
        print_success "SSH key created successfully!"
        print_info "Application ID: $app_id"
        print_info "Private key: ./$filename"
        print_info "Public key: ./${filename}.pub"
        echo
        print_info "Public key content:"
        cat "./${filename}.pub"
        echo
        print_info "You can copy this public key to your servers' ~/.ssh/authorized_keys file"
    else
        print_error "Failed to create SSH key"
        # Clean up temp files if they exist
        [[ -f "$temp_key" ]] && rm "$temp_key"
        [[ -f "${temp_key}.pub" ]] && rm "${temp_key}.pub"
        return 1
    fi
}

# List all SSH keys on YubiKey
list_ssh_keys() {
    echo
    print_info "Listing FIDO2 SSH keys stored on YubiKey..."
    
    if [[ "$OS" == "linux" ]]; then
        local device_path
        if ! device_path=$(get_device_path); then
            return 1
        fi
        
        print_info "Device: $device_path"
        echo
        
        # List resident credentials
        print_info "Resident credentials:"
        if fido2-token -L "$device_path" -r 2>/dev/null; then
            echo
        else
            print_warning "Could not list resident credentials or no credentials found"
        fi
    else
        print_info "On macOS, use 'ssh-keygen -K' to export keys and see what's stored"
        print_warning "FIDO2 key listing is limited on macOS without additional tools"
    fi
}

# Export keys to current directory
export_keys() {
    echo
    print_info "Exporting all FIDO2 SSH keys from YubiKey to current directory..."
    
    read -p "Enter optional prefix for key filenames (e.g., 'work_', 'personal_', leave empty for default): " prefix
    if [[ -n "$prefix" && ! "$prefix" =~ _$ ]]; then
        prefix="${prefix}_"
    fi
    
    print_warning "You will need to touch your YubiKey when prompted"
    print_info "Note: Key filenames will be auto-generated with prefix '${prefix}'. You may want to rename them further."
    
    # Create temporary directory for initial export
    local temp_dir="/tmp/yubikey_export_$$"
    mkdir -p "$temp_dir"
    cd "$temp_dir"
    
    if ssh-keygen -K; then
        print_success "Keys exported successfully!"
        echo
        
        # Move and rename files with prefix
        local exported_files=()
        for file in id_ed25519_sk_*; do
            if [[ -f "$file" ]]; then
                local new_name="${prefix}${file}"
                if mv "$file" "$OLDPWD/$new_name"; then
                    exported_files+=("$new_name")
                fi
            fi
        done
        
        cd "$OLDPWD"
        rm -rf "$temp_dir"
        
        if [[ ${#exported_files[@]} -gt 0 ]]; then
            print_info "Exported key files:"
            for file in "${exported_files[@]}"; do
                echo "  $file"
            done
            
            echo
            print_info "Public key contents:"
            for file in "${exported_files[@]}"; do
                if [[ "$file" =~ \.pub$ ]]; then
                    echo
                    echo "=== $file ==="
                    cat "$file"
                fi
            done
            
            echo
            print_info "You can now use these keys normally with ssh-agent or specify them directly"
            print_info "Remember to rename the files to something more descriptive if needed"
        else
            print_warning "No key files were exported"
        fi
    else
        print_error "Failed to export keys"
        cd "$OLDPWD"
        rm -rf "$temp_dir"
        return 1
    fi
}

# Delete SSH key
delete_ssh_key() {
    echo
    print_info "Deleting a FIDO2 SSH key from YubiKey..."
    
    if [[ "$OS" == "linux" ]]; then
        local device_path
        if ! device_path=$(get_device_path); then
            return 1
        fi
        
        print_info "Current keys on YubiKey:"
        if ! fido2-token -L "$device_path" -r 2>/dev/null; then
            print_error "Could not list keys or no keys found"
            return 1
        fi
        
        echo
        read -p "Enter application identifier to delete (e.g., 'ssh', 'ssh:github'): " app_id
        
        [[ -z "$app_id" ]] && app_id="ssh"
        
        print_info "Getting credential ID for application: $app_id"
        
        local cred_output
        if ! cred_output=$(fido2-token -L "$device_path" -k "$app_id" 2>/dev/null); then
            print_error "Could not find credentials for application: $app_id"
            return 1
        fi
        
        local cred_id
        cred_id=$(echo "$cred_output" | grep "^00:" | awk '{print $2}')
        
        if [[ -z "$cred_id" ]]; then
            print_error "Could not extract credential ID"
            return 1
        fi
        
        print_info "Found credential ID: $cred_id"
        echo
        print_error "THIS ACTION CANNOT BE UNDONE!"
        print_warning "You are about to delete the FIDO2 key with application ID: $app_id"
        echo
        
        read -p "Type 'DELETE' to confirm: " confirmation
        
        if [[ "$confirmation" != "DELETE" ]]; then
            print_info "Operation cancelled"
            return 0
        fi
        
        print_info "Deleting credential..."
        print_warning "You may need to touch your YubiKey to confirm deletion"
        
        if fido2-token -D -i "$cred_id" "$device_path"; then
            print_success "SSH key deleted successfully"
        else
            print_error "Failed to delete SSH key"
            return 1
        fi
    else
        print_error "Key deletion from command line is not supported on macOS"
        print_info "Please use the Yubico Authenticator app to manage FIDO2 credentials"
        print_info "You can find it at: Applications > Yubico Authenticator"
    fi
}

# Show YubiKey info
show_yubikey_info() {
    echo
    print_info "YubiKey FIDO2 Information:"
    
    if [[ "$OS" == "linux" ]]; then
        local device_path
        if ! device_path=$(get_device_path); then
            return 1
        fi
        
        echo
        print_info "Device: $device_path"
        
        # Get device info
        if command -v fido2-token &> /dev/null; then
            echo
            print_info "Device information:"
            fido2-token -I "$device_path" 2>/dev/null || print_warning "Could not get device info"
            
            echo
            print_info "Credential count:"
            fido2-token -I -c "$device_path" 2>/dev/null || print_warning "Could not get credential count"
        fi
        
        echo
        print_info "For more detailed information, consider using:"
        print_info "  - Yubico Authenticator app"
        print_info "  - ykman fido info (if available)"
    else
        print_info "On macOS, detailed FIDO2 information is limited from command line"
        print_info "For comprehensive management, use:"
        print_info "  - Yubico Authenticator app"
        print_info "  - System Information > Hardware > USB"
        
        # Try to show some basic info
        echo
        print_info "Attempting to detect FIDO2 capability via ssh-keygen..."
        if ssh-keygen -K &> /dev/null; then
            print_success "FIDO2 support is working"
        else
            print_warning "FIDO2 detection failed or no resident keys found"
        fi
    fi
}

# Main loop
main() {
    check_prerequisites
    
    while true; do
        show_menu
        read -r choice
        
        case $choice in
            1)
                create_ssh_key
                ;;
            2)
                list_ssh_keys
                ;;
            3)
                export_keys
                ;;
            4)
                delete_ssh_key
                ;;
            5)
                show_yubikey_info
                ;;
            6)
                print_info "Goodbye!"
                exit 0
                ;;
            *)
                print_error "Invalid option. Please select 1-6."
                ;;
        esac
        
        echo
    done
}

# Run the main function
main "$@"

