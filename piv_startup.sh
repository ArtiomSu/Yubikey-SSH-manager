#!/usr/bin/env bash

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

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

check_prerequisites

ykman piv info
ssh-keygen -D "$PKCS11_LIB"

print_success "PIV should be usable now with ssh"