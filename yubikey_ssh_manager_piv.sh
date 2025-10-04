#!/usr/bin/env bash

set -euo pipefail

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Detect OS and set PKCS11 library path
detect_os() {
    case "$(uname -s)" in
        Darwin*)
            OS="macos"
            PKCS11_LIB="/opt/homebrew/lib/libykcs11.dylib"
            ;;
        Linux*)
            OS="linux"
            PKCS11_LIB="/usr/lib/libykcs11.so"
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

# Configuration - using hex values
RETIRED_SLOTS=(82 83 84 85 86 87 88 89 8A 8B 8C 8D 8E 8F 90 91 92 93 94 95)

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

# Check if slot is valid
is_valid_slot() {
    local slot=$1
    for valid_slot in "${RETIRED_SLOTS[@]}"; do
        if [[ "$slot" == "$valid_slot" ]]; then
            return 0
        fi
    done
    return 1
}

# Convert hex slot to decimal for calculations
hex_to_dec() {
    local hex_slot=$1
    printf "%d" "0x$hex_slot"
}

# Convert slot number to retired key index for ssh-keygen
slot_to_key_index() {
    local slot=$1
    local dec_slot
    dec_slot=$(hex_to_dec "$slot")
    # Slot 82 (130) = Key 1, Slot 95 (149) = Key 20
    # So the formula is: key_index = dec_slot - 129
    echo $((dec_slot - 129))
}

# Get available slots as string for display
get_slots_display() {
    local slots_str=""
    for slot in "${RETIRED_SLOTS[@]}"; do
        if [[ -z "$slots_str" ]]; then
            slots_str="$slot"
        else
            slots_str="$slots_str, $slot"
        fi
    done
    echo "$slots_str"
}

# Check if YubiKey is connected and tools are installed
check_prerequisites() {
    # Detect OS and set PKCS11 library path first
    detect_os
    
    if ! command -v ykman &> /dev/null; then
        print_error "ykman is not installed."
        if [[ "$OS" == "macos" ]]; then
            print_error "Please install it with: brew install ykman"
        elif [[ "$OS" == "linux" ]]; then
            print_error "Please install it with your package manager (e.g., paru -S yubikey-manager)"
        fi
        exit 1
    fi
    
    if ! command -v ssh-keygen &> /dev/null; then
        print_error "ssh-keygen is not installed."
        if [[ "$OS" == "macos" ]]; then
            print_error "Please install openssh with: brew install openssh"
        elif [[ "$OS" == "linux" ]]; then
            print_error "Please install openssh with your package manager"
        fi
        exit 1
    fi
    
    if ! command -v openssl &> /dev/null; then
        print_error "openssl is not installed."
        exit 1
    fi
    
    if [[ ! -f "$PKCS11_LIB" ]]; then
        print_error "PKCS11 library not found at $PKCS11_LIB."
        if [[ "$OS" == "macos" ]]; then
            print_error "Please install yubico-piv-tool with: brew install yubico-piv-tool"
        elif [[ "$OS" == "linux" ]]; then
            print_error "Please install yubico-piv-tool with your package manager (e.g., paru -S yubico-piv-tool)"
        fi
        exit 1
    fi
    
    if ! ykman piv info &> /dev/null; then
        print_error "YubiKey not detected or PIV application not available."
        if [[ "$OS" == "linux" ]]; then
            print_warning "On Linux, make sure pcscd service is running: sudo systemctl start pcscd"
        fi
        exit 1
    fi
}

# Display main menu
show_menu() {
    echo ""
    echo "=================================="
    echo "    YubiKey SSH Key Manager"
    echo "=================================="
    echo "1. Create new SSH key"
    echo "2. List all SSH keys"
    echo "3. Get public key for specific slot"
    echo "4. Get all public keys"
    echo "5. Delete SSH key"
    echo "6. Show YubiKey PIV info"
    echo "7. Export all public keys to files"
    echo "8. Populate SSH config"
    echo "9. Exit"
    echo "=================================="
    echo -n "Please select an option [1-9]: "
}

# Create new SSH key
create_ssh_key() {
    echo
    print_info "Available slots: $(get_slots_display)"
    
    # Show occupied slots
    echo
    print_info "Currently occupied slots:"
    ykman piv info | grep -E "Slot (8[2-9A-F]|9[0-5])" | grep -v "Empty" || echo "  No keys found"
    
    echo
    read -p "Enter slot number (e.g., 82, 8A, 95): " slot
    
    # Convert to uppercase for consistency
    slot=$(echo "$slot" | tr '[:lower:]' '[:upper:]')
    
    if ! is_valid_slot "$slot"; then
        print_error "Invalid slot number. Must be one of: $(get_slots_display)"
        return 1
    fi
    
    # Check if slot is already occupied
    if ykman piv info | grep -q "Slot $slot" && ! ykman piv info | grep "Slot $slot" | grep -q "Empty"; then
        print_error "Slot $slot is already occupied."
        return 1
    fi
    
    read -p "Enter a description for this key (e.g., 'GitHub', 'Bitbucket'): " description
    [[ -z "$description" ]] && description="SSH Key"
    
    print_info "Creating RSA4096 key on slot $slot..."
    
    # Generate temporary file names in /tmp
    local temp_pub="/tmp/temp_${slot}_pub.pem"
    local temp_cert="/tmp/temp_${slot}_cert.pem"
    local temp_raw_pub="/tmp/temp_${slot}_raw_pub.pem"
    local temp_ssh_pub="/tmp/temp_${slot}_ssh.pub"
    
    # Generate key pair
    if ! ykman piv keys generate --algorithm RSA4096 "$slot" "$temp_pub"; then
        print_error "Failed to generate key pair"
        return 1
    fi
    
    # Generate certificate
    if ! ykman piv certificates generate --subject "CN=$description" --valid-days 36500 "$slot" "$temp_pub"; then
        print_error "Failed to generate certificate"
        return 1
    fi
    
    # Export certificate and extract public key
    if ! ykman piv certificates export "$slot" "$temp_cert"; then
        print_error "Failed to export certificate"
        return 1
    fi
    
    if ! openssl x509 -in "$temp_cert" -pubkey -noout > "$temp_raw_pub"; then
        print_error "Failed to extract public key from certificate"
        return 1
    fi
    
    if ! ssh-keygen -i -m PKCS8 -f "$temp_raw_pub" > "$temp_ssh_pub"; then
        print_error "Failed to convert public key to SSH format"
        return 1
    fi
    
    print_success "SSH key created successfully on slot $slot"
    echo
    print_info "Public key:"
    cat "$temp_ssh_pub"
    echo
    print_info "You can copy this public key to your servers' ~/.ssh/authorized_keys file"
    rm "$temp_pub" "$temp_cert" "$temp_raw_pub" "$temp_ssh_pub"
}

# List all SSH keys
list_ssh_keys() {
    echo
    print_info "Scanning YubiKey for SSH keys on retired slots..."
    echo
    
    local found_keys=false
    local piv_info
    
    # Get PIV info once and store it
    piv_info=$(ykman piv info)
    
    for slot in "${RETIRED_SLOTS[@]}"; do
        if echo "$piv_info" | grep -q "Slot $slot" && ! echo "$piv_info" | grep "Slot $slot" | grep -q "Empty"; then
            local subject=$(echo "$piv_info" | grep "Slot $slot" -A 5 | grep "Subject DN:" | sed 's/.*Subject DN://')
            echo "Slot $slot: $subject"
            found_keys=true
        fi
    done
    
    if [[ "$found_keys" == false ]]; then
        print_warning "No SSH keys found on retired slots"
    fi
    
    echo
    print_info "You can also view all PIV info with option 6"
}

# Get public key for specific slot
get_public_key() {
    echo
    read -p "Enter slot number (e.g., 82, 8A, 95): " slot
    
    # Convert to uppercase for consistency
    slot=$(echo "$slot" | tr '[:lower:]' '[:upper:]')
    
    if ! is_valid_slot "$slot"; then
        print_error "Invalid slot number. Must be one of: $(get_slots_display)"
        return 1
    fi
    
    # Check if slot has a key
    if ykman piv info | grep "Slot $slot" | grep -q "Empty"; then
        print_error "Slot $slot is empty"
        return 1
    fi
    
    local key_index
    key_index=$(slot_to_key_index "$slot")
    
    print_info "Public key for slot $slot (Retired Key $key_index):"
    echo
    
    # Try to get the specific key, but if that fails, show all keys with slot info
    if ! ssh-keygen -D "$PKCS11_LIB" | grep "Retired Key $key_index"; then
        print_warning "Could not extract specific key"
    fi
}

# Get all public keys
get_all_public_keys() {
    echo
    print_info "Extracting all public keys from YubiKey..."
    echo
    
    if ! ssh-keygen -D "$PKCS11_LIB" 2>/dev/null; then
        print_error "Could not extract public keys from YubiKey"
        print_info "Make sure your YubiKey is connected and has SSH keys"
        return 1
    fi
    
    echo
    print_info "Copy the relevant public keys to your servers' ~/.ssh/authorized_keys file"
}

# Delete SSH key
delete_ssh_key() {
    echo
    print_info "Available keys to delete:"
    list_ssh_keys
    
    read -p "Enter slot number to delete (e.g., 82, 8A, 95): " slot
    
    # Convert to uppercase for consistency
    slot=$(echo "$slot" | tr '[:lower:]' '[:upper:]')
    
    if ! is_valid_slot "$slot"; then
        print_error "Invalid slot number. Must be one of: $(get_slots_display)"
        return 1
    fi
    
    # Check if slot has a key
    if ykman piv info | grep "Slot $slot" | grep -q "Empty"; then
        print_error "Slot $slot is already empty"
        return 1
    fi
    
    local subject=$(ykman piv info | grep "Slot $slot" -A 5 | grep "Subject" | sed 's/.*Subject: //')
    
    echo
    print_warning "You are about to delete the SSH key on slot $slot:"
    print_warning "Subject: $subject"
    echo
    print_error "THIS ACTION CANNOT BE UNDONE!"
    echo
    
    read -p "Type 'DELETE' to confirm: " confirmation
    
    if [[ "$confirmation" != "DELETE" ]]; then
        print_info "Operation cancelled"
        return 0
    fi
    
    print_info "Deleting key and certificate from slot $slot..."
    
    if ykman piv keys delete "$slot" && ykman piv certificates delete "$slot"; then
        print_success "SSH key deleted from slot $slot"
    else
        print_error "Failed to delete SSH key from slot $slot"
        return 1
    fi
}

# Export all public keys to individual files
export_all_public_keys() {
    echo
    print_info "Scanning YubiKey for SSH keys on retired slots..."
    
    local found_keys=false
    local piv_info
    local exported_count=0
    
    # Get PIV info once and store it
    piv_info=$(ykman piv info)
    
    # Check if any keys exist first
    for slot in "${RETIRED_SLOTS[@]}"; do
        if echo "$piv_info" | grep -q "Slot $slot" && ! echo "$piv_info" | grep "Slot $slot" | grep -q "Empty"; then
            found_keys=true
            break
        fi
    done
    
    if [[ "$found_keys" == false ]]; then
        print_warning "No SSH keys found on retired slots"
        return 0
    fi
    
    echo
    read -p "Enter file prefix (e.g., 'my_yubikey', 'work_keys'): " prefix
    
    if [[ -z "$prefix" ]]; then
        print_error "Prefix cannot be empty"
        return 1
    fi
    
    # Sanitize prefix (remove special characters except underscore and dash)
    prefix=$(echo "$prefix" | sed 's/[^a-zA-Z0-9_-]/_/g')
    
    echo
    print_info "Exporting public keys with prefix '$prefix'..."
    echo
    
    for slot in "${RETIRED_SLOTS[@]}"; do
        if echo "$piv_info" | grep -q "Slot $slot" && ! echo "$piv_info" | grep "Slot $slot" | grep -q "Empty"; then
            # Extract subject and clean it up
            local subject_raw=$(echo "$piv_info" | grep "Slot $slot" -A 5 | grep "Subject DN:" | sed 's/.*Subject DN: *//')
            local subject_clean=""
            
            # Extract CN value if present, otherwise use the whole subject
            if [[ "$subject_raw" =~ CN=([^,]*) ]]; then
                subject_clean="${BASH_REMATCH[1]}"
            else
                subject_clean="$subject_raw"
            fi
            
            # Replace spaces with underscores and sanitize
            subject_clean=$(echo "$subject_clean" | sed 's/ /_/g' | sed 's/[^a-zA-Z0-9_-]/_/g')
            
            print_info "Processing slot $slot: $subject_clean"

            local key_index
            key_index=$(slot_to_key_index "$slot")
    
            local public_key
            local filename
            public_key=$(ssh-keygen -D "$PKCS11_LIB" 2>/dev/null | grep "Retired Key $key_index")
            if [[ -n "$public_key" ]]; then
                if [[ -n "$subject_clean" ]]; then
                    filename="${prefix}_slot_${slot}_${subject_clean}.pub"
                else
                    filename="${prefix}_slot_${slot}.pub"
                fi
                echo "$public_key" > "$filename"
                chmod 0644 "$filename"
                print_success "Exported slot $slot to $filename"
                exported_count=$((exported_count + 1))
            else
                print_warning "Failed to extract public key for slot $slot"
            fi
        fi
    done
    
    echo
    if [[ $exported_count -gt 0 ]]; then
        print_success "Successfully exported $exported_count public key(s)"
        print_info "Files saved in current directory with prefix '$prefix'"
    else
        print_error "No public keys were exported"
    fi
}

# Populate SSH config from public key files
populate_ssh_config() {
    echo
    print_info "SSH Config Population Tool"
    echo
    
    # Get SSH folder path
    read -p "Enter SSH folder path [default: ~/.ssh/]: " ssh_folder
    ssh_folder=${ssh_folder:-~/.ssh/}
    
    # Expand tilde
    ssh_folder="${ssh_folder/#\~/$HOME}"
    
    # Ensure trailing slash
    [[ "$ssh_folder" != */ ]] && ssh_folder="${ssh_folder}/"
    
    if [[ ! -d "$ssh_folder" ]]; then
        print_error "SSH folder does not exist: $ssh_folder"
        return 1
    fi
    
    # Get SSH config file path
    read -p "Enter SSH config file path [default: ~/.ssh/config]: " config_file
    config_file=${config_file:-~/.ssh/config}
    
    # Expand tilde
    config_file="${config_file/#\~/$HOME}"
    
    # Get key file prefix
    read -p "Enter public key file prefix [default: yubikey_]: " prefix
    prefix=${prefix:-yubikey_}
    
    print_info "Scanning for public key files matching: ${ssh_folder}${prefix}*.pub"
    echo
    
    # Find all matching public key files
    local pub_files=()
    while IFS= read -r -d '' file; do
        pub_files+=("$file")
    done < <(find "$ssh_folder" -maxdepth 1 -name "${prefix}*.pub" -print0 2>/dev/null | sort -z)
    
    if [[ ${#pub_files[@]} -eq 0 ]]; then
        print_error "No public key files found matching pattern: ${prefix}*.pub"
        return 1
    fi
    
    print_info "Found ${#pub_files[@]} public key file(s)"
    
    # Group files by host
    declare -A host_files
    
    for file in "${pub_files[@]}"; do
        local basename=$(basename "$file")
        
        # Extract host from filename
        # Pattern: prefix_*_slot_*_description.pub
        # We look for IP addresses (x.x.x.x) or named hosts in the description
        local host=""
        
        # Try to extract IP address pattern
        if [[ "$basename" =~ ([0-9]{1,3}_[0-9]{1,3}_[0-9]{1,3}_[0-9]{1,3}) ]]; then
            host="${BASH_REMATCH[1]}"
            host="${host//_/.}"  # Replace underscores with dots
        elif [[ "$basename" =~ _([A-Za-z][A-Za-z0-9_-]+)\.pub$ ]]; then
            # Extract the last meaningful part before .pub as hostname
            local temp="${basename%.pub}"
            # Get everything after the last slot_XX_ pattern
            if [[ "$temp" =~ slot_[0-9A-F]{2}_(.+)$ ]]; then
                host="${BASH_REMATCH[1]}"
            fi
        fi
        
        if [[ -n "$host" ]]; then
            if [[ ! -v host_files[$host] ]]; then
                host_files[$host]="$file"
            else
                host_files[$host]="${host_files[$host]}|$file"
            fi
        else
            print_warning "Could not extract host from: $basename"
        fi
    done
    
    if [[ ${#host_files[@]} -eq 0 ]]; then
        print_error "Could not extract any host information from filenames"
        return 1
    fi
    
    print_info "Found ${#host_files[@]} unique host(s)"
    echo
    
    # Create config entries
    local config_content=""
    config_content+="# Generated by YubiKey SSH Manager on $(date)\n"
    config_content+="# --- BEGIN YUBIKEY CONFIG ---\n\n"
    
    for host in "${!host_files[@]}"; do
        config_content+="Host $host\n"
        config_content+="\tPKCS11Provider $PKCS11_LIB\n"
        config_content+="\tIdentityAgent none\n"
        config_content+="\tIdentitiesOnly yes\n"
        
        IFS='|' read -ra files <<< "${host_files[$host]}"
        for file in "${files[@]}"; do
            config_content+="\tIdentityFile $file\n"
        done
        
        config_content+="\n"
    done
    
    config_content+="# --- END YUBIKEY CONFIG ---\n\n"
    
    # Show preview
    print_info "Preview of configuration to be added:"
    echo
    echo -e "$config_content"
    
    # Ask for confirmation
    read -p "Append this configuration to $config_file? [y/N]: " confirm
    
    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
        print_info "Operation cancelled"
        return 0
    fi
    
    # Backup existing config
    if [[ -f "$config_file" ]]; then
        local backup_file="${config_file}.backup.$(date +%Y%m%d_%H%M%S)"
        if cp "$config_file" "$backup_file"; then
            print_success "Backed up existing config to: $backup_file"
        else
            print_error "Failed to create backup"
            return 1
        fi
    fi
    
    # Append to config file
    if echo -e "$config_content" >> "$config_file"; then
        print_success "Successfully updated SSH config file"
        print_info "Config file: $config_file"
    else
        print_error "Failed to update SSH config file"
        return 1
    fi
}

# Show YubiKey PIV info
show_piv_info() {
    echo
    print_info "YubiKey PIV Information:"
    echo
    ykman piv info
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
                get_public_key
                ;;
            4)
                get_all_public_keys
                ;;
            5)
                delete_ssh_key
                ;;
            6)
                show_piv_info
                ;;
            7)
                export_all_public_keys
                ;;
            8)
                populate_ssh_config
                ;;
            9)
                print_info "Goodbye!"
                exit 0
                ;;
            *)
                print_error "Invalid option. Please select 1-9."
                ;;
        esac
        
        echo
    done
}

# Run the main function
main "$@"

