# Manual FIDO2 Method for SSH Key Management

This guide covers manual management of SSH keys using YubiKey's FIDO2 functionality. The `yubikey_ssh_manager_fido2.sh` script automates most of these processes.

## Prerequisites

### macOS
```bash
brew install openssh
# Latest OpenSSH includes FIDO2 support
```

### Linux
```bash
# Arch Linux example
paru -S libfido2 openssh
```

### Verify FIDO2 Support
```bash
# Check OpenSSH version (should be 8.2+)
ssh -V

# Test FIDO2 token detection
ssh-keygen -t ed25519-sk -O resident -f /tmp/test_key
rm /tmp/test_key*  # Clean up test files
```

## Key Generation

### Basic FIDO2 Key
```bash
# Generate a resident key with touch verification
ssh-keygen -t ed25519-sk -O resident -O verify-required -C "Main SSH Key" -f ~/.ssh/yubikey_main
```

Options explained:
- `-t ed25519-sk`: Use ED25519 with security key
- `-O resident`: Store key on the YubiKey (allows recovery)
- `-O verify-required`: Require touch for each authentication
- `-C "comment"`: Add a comment to identify the key
- `-f filename`: Specify output filename

### Multiple Keys with Application IDs

Create separate keys for different services:

```bash
# Default application (ssh:)
ssh-keygen -t ed25519-sk -O resident -O verify-required -C "Primary SSH Key" -f ~/.ssh/yubikey_primary

# GitHub key
ssh-keygen -t ed25519-sk -O resident -O application=ssh:github -O verify-required -C "GitHub SSH Key" -f ~/.ssh/yubikey_github

# Work server key
ssh-keygen -t ed25519-sk -O resident -O application=ssh:work -O verify-required -C "Work SSH Key" -f ~/.ssh/yubikey_work

# Personal server key
ssh-keygen -t ed25519-sk -O resident -O application=ssh:personal -O verify-required -C "Personal SSH Key" -f ~/.ssh/yubikey_personal
```

## Key Recovery and Export

### Export All Keys from YubiKey

On a new computer, recover all resident keys:

```bash
# Create a directory for exported keys
mkdir -p ~/.ssh/yubikey_keys
cd ~/.ssh/yubikey_keys

# Export all resident keys from YubiKey
ssh-keygen -K

# Keys will be saved as id_ed25519_sk_* files
# Rename them to something more descriptive
mv id_ed25519_sk_rk_github ~/.ssh/yubikey_github
mv id_ed25519_sk_rk_github.pub ~/.ssh/yubikey_github.pub
```

### Identify Keys by Application ID

The exported public keys contain the application ID in the comment:

```bash
# Check public key contents to identify purpose
cat ~/.ssh/yubikey_keys/*.pub

# Look for application identifiers in the key comments
grep -H "ssh:" ~/.ssh/yubikey_keys/*.pub
```

## Key Management with fido2-token (Linux)

### List FIDO2 Devices
```bash
fido2-token -L
# Output: /dev/hidraw0: vendor=0x1050, product=0x0407 (YubiKey)
```

### List Resident Credentials
```bash
# Replace /dev/hidrawX with your device path
fido2-token -L /dev/hidraw0 -r

# Sample output:
# ssh: AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA= eddsa uvopt+id
# ssh:github: BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB= eddsa uvopt+id
```

### Get Credential Count
```bash
fido2-token -I -c /dev/hidraw0
# Output: remaining: 98, total: 100
```

### Delete Specific Credentials

First, get the credential ID:
```bash
fido2-token -L /dev/hidraw0 -k ssh:github
# Output: 00: [CREDENTIAL_ID] openssh AAAA...= eddsa uvopt+id
```

Then delete using the credential ID:
```bash
fido2-token -D -i [CREDENTIAL_ID] /dev/hidraw0
```

## SSH Configuration

FIDO2 keys work like regular SSH keys. Add them to your SSH configuration:

```ssh
# ~/.ssh/config
Host github.com
    HostName github.com
    User git
    IdentityFile ~/.ssh/yubikey_github
    IdentitiesOnly yes

Host work-server
    HostName work.example.com
    User username
    IdentityFile ~/.ssh/yubikey_work
    IdentitiesOnly yes
```

Or add them to ssh-agent:
```bash
ssh-add ~/.ssh/yubikey_github
ssh-add ~/.ssh/yubikey_work
```

## Platform Limitations

### Android Support

Android support is pretty bad. I could only get it working with the proprietary Termius app. However this uses its own key storage and not the YubiKey resident keys so its not possible to share keys between devices.

### Windows Support

Windows support is not covered by these scripts. I only use Windows for gaming and HDR content so not going to invest time in it. But feel free to submit a PR if you figure it out. 

## Troubleshooting

### Touch Not Working
- Ensure YubiKey LED is steady (not blinking)
- Try a longer, deliberate touch
- Some YubiKey models require firmer pressure

## Security Considerations

### Key Storage
- **Private keys**: Never leave the YubiKey hardware
- **Public keys**: Standard SSH public keys, safe to copy anywhere
- **Recovery**: Resident keys can be re-exported from YubiKey

### Touch Requirements
- **verify-required**: Requires touch for each authentication
- **Touch confirmation**: Provides protection against malware

### Application Isolation
- Different application IDs create separate key slots
- Keys are isolated from each other on the device
- Maximum 100 resident credentials (shared with web authentication)





