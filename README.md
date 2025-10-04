# Yubikey SSH Manager

A collection of scripts and documentation for managing SSH keys on YubiKeys using different methods.

## Overview

This repository provides two automated scripts for managing SSH keys on YubiKeys:

- **PIV Method** (`yubikey_ssh_manager_piv.sh`) - Uses PIV application with RSA4096 keys

```txt
1. Create new SSH key
2. List all SSH keys
3. Get public key for specific slot
4. Get all public keys
5. Delete SSH key
6. Show YubiKey PIV info
7. Export all public keys to files
8. Populate SSH config
```

- **FIDO2 Method** (`yubikey_ssh_manager_fido2.sh`) - Uses FIDO2 with ED25519-SK keys

```txt
1. Create new SSH key
2. List all SSH keys on YubiKey
3. Export keys to current directory
4. Delete SSH key
5. Show YubiKey info
```

## Method Comparison

Yubikey supports 3 main methods for SSH key storage: PIV, FIDO2, and OpenPGP.

OpenPGP support is still WIP and not included in this repo for now. I'll include it once I figure out a good way to use it. You can use it for git commit signing which is pretty cool. 

| Feature | PIV | FIDO2 |
|---------|-----|-------|
| **Key Capacity** | 20 keys | 100 keys (shared with web logins) |
| **Key Type** | RSA4096 | ED25519-SK |
| **Generation Speed** | Slow (~1 minute) | Instant |
| **macOS Support** | Yes | Yes |
| **Linux x86_64 Support** | Yes | Yes |
| **Linux ARM Support (PinePhone 64)** | Yes | Yes |
| **Android Support** | No | Only in Termius |
| **Setup Complexity** | Medium | Easy |
| **Server Configuration** | None required | None required |

## Quick Start

### Prerequisites

Make sure to change the default PIN, PUK, and management key on your YubiKey before using these scripts. This is easiest to do using the yubico authenticator app.

**macOS:**
```bash
brew install openssh ykman yubico-piv-tool
brew install yubico-authenticator # optional
```

**Linux:**
```bash
# Install required packages (example for Arch Linux)
paru -S yubikey-manager yubico-piv-tool libfido2
paru -S yubico-authenticator-bin # optional
sudo systemctl start pcscd && sudo systemctl enable pcscd
```

### Running the Scripts

Make sure your YubiKey is plugged in, then run:

```bash
# PIV method (RSA4096 keys)
./yubikey_ssh_manager_piv.sh

# FIDO2 method (ED25519-SK keys)
./yubikey_ssh_manager_fido2.sh
```

## Key Features

- **Fully hardware-stored keys** - Private keys never leave the YubiKey
- **No server-side configuration** - Works with any SSH server
- **Multiple key management** - Organize keys for different services
- **Cross-platform support** - Works on macOS and Linux
- **Compatible with macOS login** - PIV method works alongside system authentication (if you use the script). Here is a nice tutorial on [how to set it up](https://support.yubico.com/hc/en-us/articles/360016649059-YubiKey-for-macOS-login).

## Documentation

- [`manual_method_piv.md`](manual_method_piv.md) - Manual PIV key management and troubleshooting
- [`manual_method_fido2.md`](manual_method_fido2.md) - Manual FIDO2 key management
- [`troubleshooting.md`](troubleshooting.md) - Common issues and solutions

## SSH Configuration

Add this to your `~/.ssh/config` for each host you want to use with PIV keys:

**macOS:**
```ssh
Host example.com
    PKCS11Provider /opt/homebrew/lib/libykcs11.dylib
```

**Linux:**
```ssh
Host example.com
    PKCS11Provider /usr/lib/libykcs11.so
```

If you get Too many authentication failures from server see the corresponding section in `manual_method_piv.md` to fix it.

FIDO2 keys work like regular SSH keys and don't require special SSH configuration.

## Security Notes

- PIV method allows up to 20 SSH keys while maintaining compatibility with macOS login and sudo authentication
- FIDO2 keys share storage space with your web authentication credentials
- Both methods require physical touch confirmation for key generation and usage
- Keys are generated and stored entirely on the YubiKey hardware

## Limitations

- **Windows support** - Currently not supported by these scripts
- **OpenPGP method** - Not included due to compatibility issues
- **Android support** - Very limited, FIDO2 only works with specific apps like Termius. PIV method is not supported. 
- **Pin caching** - Not supported, you'll need to enter your PIN for each SSH operation

For detailed troubleshooting and workarounds, see [`troubleshooting.md`](troubleshooting.md).