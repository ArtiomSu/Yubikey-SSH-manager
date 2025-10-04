# Manual PIV Method for SSH Key Management

This guide provides step-by-step instructions for manually managing SSH keys using YubiKey's PIV application. This is essentially what the `yubikey_ssh_manager_piv.sh` script automates.

## Prerequisites

### macOS
```bash
brew install openssh ykman yubico-piv-tool
brew install yubico-authenticator # optional GUI tool
```

### Linux
```bash
# Arch Linux example
paru -S yubikey-manager yubico-piv-tool libpcsclite pcsc-tools
paru -S yubico-authenticator-bin # optional GUI tool

# Start and enable the PC/SC daemon
sudo systemctl start pcscd && sudo systemctl enable pcscd
```

## SSH Configuration

Add this configuration to `~/.ssh/config` for each host:

### macOS
```ssh
Host bitbucket.org
    PKCS11Provider /opt/homebrew/lib/libykcs11.dylib
```

### Linux
```ssh
Host bitbucket.org
    PKCS11Provider /usr/lib/libykcs11.so
```

## Slot Information

The PIV method uses retired certificate slots (82-95) for SSH keys:
- **Hex slots:** 82, 83, 84, 85, 86, 87, 88, 89, 8A, 8B, 8C, 8D, 8E, 8F, 90, 91, 92, 93, 94, 95
- **Decimal equivalent:** 130-149
- **SSH key indices:** Retired Key 1-20 (slot 82 = Key 1, slot 95 = Key 20)

This allows you to maintain compatibility with macOS login functionality while having 20 SSH keys.

## Creating SSH Keys

### RSA4096 Key on Slot 95 (Working Method)

```bash
# Generate key pair (takes ~1 minute)
ykman piv keys generate --algorithm RSA4096 95 temp_95_pub.pem

# Generate self-signed certificate
ykman piv certificates generate --subject "CN=SSH Key for GitHub" --valid-days 36500 95 temp_95_pub.pem

# Export certificate
ykman piv certificates export 95 temp_95_cert.pem

# Extract public key from certificate
openssl x509 -in temp_95_cert.pem -pubkey -noout > temp_95_raw_pub.pem

# Convert to SSH format
ssh-keygen -i -m PKCS8 -f temp_95_raw_pub.pem > temp_95_ssh.pub

# Display the public key
cat temp_95_ssh.pub

# Clean up temporary files
rm temp_95_*
```

### ED25519 Key Attempt (Non-Working)

This method generates ED25519 keys but they won't work with SSH because the Yubico PKCS#11 module doesn't recognize them:

```bash
# This creates a key but it won't work with SSH
ykman piv keys generate --algorithm ED25519 94 temp_ed_94_pub.pem
ykman piv certificates generate --subject "CN=SSH Key ED25519" --valid-days 36500 94 temp_ed_94_pub.pem

# The PKCS11 module won't see this key
ssh-keygen -D /opt/homebrew/lib/libykcs11.dylib  # ED25519 key won't appear
```

**Note:** If you need ED25519 keys, use the FIDO2 method instead.

## Key Management

### List All Keys and Certificates
```bash
ykman piv info
```

### Extract All Public Keys
```bash
# macOS
ssh-keygen -D /opt/homebrew/lib/libykcs11.dylib

# Linux
ssh-keygen -D /usr/lib/libykcs11.so
```

### Extract Specific Public Key
```bash
# For slot 95 (Retired Key 20)
# macOS
ssh-keygen -D /opt/homebrew/lib/libykcs11.dylib | grep "Retired Key 20"

# Linux
ssh-keygen -D /usr/lib/libykcs11.so | grep "Retired Key 20"
```

### Delete Keys
```bash
# Delete both private key and certificate
ykman piv keys delete 94
ykman piv certificates delete 94
```

## Slot to Key Index Mapping

When using `ssh-keygen -D`, the slots are mapped as follows:
- Slot 82 (hex) = 130 (dec) = Retired Key 1
- Slot 83 (hex) = 131 (dec) = Retired Key 2
- ...
- Slot 95 (hex) = 149 (dec) = Retired Key 20

Formula: `Key Index = Decimal Slot - 129`

## Troubleshooting

### Key Generation is Slow
RSA4096 key generation takes approximately 1 minute. This is normal due to the cryptographic complexity and YubiKey's hardware constraints.

### YubiKey Not Detected (Linux)
```bash
# Check if pcscd is running
sudo systemctl status pcscd

# If not running, start it
sudo systemctl start pcscd && sudo systemctl enable pcscd

# Test YubiKey detection
ykman piv info
```

### Permission Issues (Linux)
```bash
# Add user to necessary groups
sudo usermod -a -G plugdev,dialout $USER
# Log out and back in for changes to take effect
```

## Security Considerations

- **PIN Protection:** All operations require your PIV PIN
- **Physical Access:** Key generation and usage require physical YubiKey presence
- **Key Storage:** Private keys are generated on and never leave the YubiKey
- **Certificate Validity:** Certificates are set to 100 years (36500 days) for convenience
- **Subject Names:** Use descriptive certificate subjects to identify keys later

## Integration with macOS Login

The PIV method is compatible with macOS login functionality when using slots 82-95. This means you can:
- Use your YubiKey for SSH authentication
- Continue using it for macOS login and sudo authentication
- Have both functionalities work simultaneously without conflicts

To set up macOS login, follow [Yubico's official guide](https://support.yubico.com/hc/en-us/articles/360016649059-YubiKey-for-macOS-login).

## Too many authentication failures from server

If you get this, here is the fix. You need to save your public key to a file on the client, the same key that you use on the servers `authorized_keys` file. You can use option 7 of the script to extract all the public keys to their own files.
Then you can use option 8 of the script to populate the `.ssh/config` based on those files (only really works if you put the host name in the name of the keys when generating them. Otherwise you will just need to do it manually).

update the clients `~/.ssh/config` with the following:

```config
Host bitbucket.org
	PKCS11Provider /opt/homebrew/lib/libykcs11.dylib
	IdentityAgent none
	IdentitiesOnly yes
	IdentityFile /Users/$USER/.ssh/yubikey_primary_bitbucket.pub
```

And make sure the permissions of the public key file are correct:

```bash
chmod 0644 /Users/$USER/.ssh/yubikey_primary_bitbucket.pub
```

If you have multiple keys on the YubiKey, you can add more `IdentityFile` lines to the config file.

```config
Host bitbucket.org
	PKCS11Provider /opt/homebrew/lib/libykcs11.dylib
	IdentityAgent none
	IdentitiesOnly yes
	IdentityFile /Users/$USER/.ssh/yubikey_primary_bitbucket.pub
	IdentityFile /Users/$USER/.ssh/yubikey_secondary_bitbucket.pub
```
