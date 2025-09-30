# Troubleshooting Guide

This document covers common issues, limitations, and workarounds when using YubiKeys for SSH authentication.

## Common Issues

### YubiKey Not Detected

**Linux:**
```bash
# Make sure pcscd service is running
sudo systemctl start pcscd
sudo systemctl enable pcscd

# Check if YubiKey is detected
ykman piv info
```

**macOS:**
```bash
# Try unplugging and reconnecting the YubiKey
# Check if PIV application is accessible
ykman piv info
```

### After Reboot Issues

This so far has only been an issue with Macos sometimes.

If your YubiKey stops working after a reboot, run this command once:

```bash
ykman piv info
```

This reinitializes the PIV interface and should restore functionality.

you can also run the `piv_startup.sh` script included in this repository to automate this process, the script also outputs all of the public keys so you can verify that everything is working.

## Known Limitations

### PIN Caching Doesn't Work

Unfortunately, several common PIN caching methods don't work with the retired slots used for SSH keys:

#### SSH ControlMaster (Doesn't Work)

```ssh
# This configuration doesn't work with PIV SSH keys
Host example.com
    PKCS11Provider /opt/homebrew/lib/libykcs11.dylib
    ControlMaster auto
    ControlPath ~/.ssh/controlmasters/%r@%h:%p
    ControlPersist 30m
```

#### Yubikey-Agent (Doesn't Work)

The `yubikey-agent` can't read the retired slots (82-95) used for SSH keys:

```bash
# These commands don't work with our setup
yubikey-agent --setup
yubikey-agent -l ~/.yubico/ssh-agent.sock
```

**Workaround:** You'll need to enter your PIN for each SSH connection.

### ED25519 Keys with PIV Method

ED25519 keys cannot be used with the PIV method because:
- The Yubico PKCS#11 module (`libykcs11`) doesn't recognize ED25519 keys
- Only RSA keys are supported for SSH authentication via PKCS#11

**Workaround:** Use the FIDO2 method if you prefer ED25519 keys.

### Platform-Specific Limitations

#### Android
- **PIV Method:** Not supported
- **FIDO2 Method:** Only works with specific apps like Termius but are not sharable between devices then.

#### Windows
- Both methods are currently unsupported by these scripts
- Manual configuration may be possible but is not documented as I only use Windows for gaming and HDR content. Feel free to submit a PR if you figure it out.

## Workarounds and Tips

### Key Organization

**PIV Method:**
- Use descriptive certificate subjects when creating keys
- Slots 82-95 are recommended for SSH to avoid conflicts

**FIDO2 Method:**
- Use meaningful application identifiers (e.g., `ssh:github`, `ssh:work`)

### Backup and Recovery

- **PIV Method:** Private keys cannot be backed up (by design)
- **FIDO2 Method:** Private keys cannot be backed up (by design)
- **Recovery:** If you lose your YubiKey, you'll need to generate new keys

## Getting Help

If you encounter issues not covered here:

1. Check YubiKey firmware version: `ykman info`
2. Verify package versions and dependencies
3. Test with a simple key generation to isolate the issue
4. Check YubiKey's LED - it should be blinking when generating or using keys 

## Reporting Issues

When reporting issues, please include:
- Operating system and version
- YubiKey model and firmware version
- Package versions (`ykman --version`, `ssh-keygen -V`, etc.)
- Complete error messages
- Steps to reproduce the issue
