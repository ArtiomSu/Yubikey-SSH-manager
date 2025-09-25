# Manual Method For Managing SSH Keys with YubiKey

This guide provides a step-by-step method to manually manage SSH keys using a YubiKey. This is pretty much what the script does under the hood.

The script uses the 82-95 retired slots for storing SSH keys. I recommend using the same since if you want to use the YubiKey for logging into the mac for example you would need to use the none retired slots.

Inside your `.ssh/config` you will need to add the following for every host you want to use the YubiKey with

```sh
# For MacOS
Host bitbucket.org
	PKCS11Provider /opt/homebrew/lib/libykcs11.dylib

# For Linux
Host bitbucket.org
	PKCS11Provider /usr/lib/libykcs11.so
```

# Instructions to create a new RSA4096 SSH key on slot 95

```bash
ykman piv keys generate --algorithm RSA4096 95 primary_rsa_95_pub.pem

ykman piv certificates generate --subject "CN=SSH key" --valid-days 36500 95 primary_rsa_95_pub.pem

ykman piv certificates export 95 primary_rsa_95_cert.pem

openssl x509 -in primary_rsa_95_cert.pem -pubkey -noout > primary_rsa_95_raw_pub.pem

ssh-keygen -i -m PKCS8 -f primary_rsa_95_raw_pub.pem > primary_rsa_95_ssh.pub

cat primary_rsa_95_ssh.pub

rm primary_rsa_95_*
```

# Instructions to create a new ED25519 SSH key on slot 94

This doesn't work because `ssh-keygen -D /opt/homebrew/lib/libykcs11.dylib` doesn't see the ED25519 keys.

```bash
ykman piv keys generate --algorithm ED25519 94 primary_ed_94_pub.pem

ykman piv certificates generate --subject "CN=SSH bitbucket.org" --valid-days 36500 94 primary_ed_94_pub.pem

yubico-piv-tool -a read-cert -s 94 > primary_ed_94_cert.pem

python3  ~/scripts/yubikey_manager/extract_ed25519_from_cert.py primary_ed_94_cert.pem primary_ed_94_ssh.pub

cat primary_ed_94_ssh.pub

rm primary_ed_94_cert.pem primary_ed_94_pub.pem primary_ed_94_raw_pub.pem
```

# delete keys

```bash
ykman piv keys delete 94
ykman piv certificates delete 94
```

# Other usefull commands

Best way to see all the slots and what is in them

```bash
ykman piv info
```

Easiest way to get the public keys and copy them to the server

For MacOS
```bash
ssh-keygen -D /opt/homebrew/lib/libykcs11.dylib
```

For Linux
```bash
ssh-keygen -D /usr/lib/libykcs11.so
```

To get the public key for a specific slot. Note here they don't use the hex slot number but they do it backwards so slot 95 is key 20, slot 94 is key 19 etc

For MacOS
```bash
ssh-keygen -D /opt/homebrew/lib/libykcs11.dylib | grep "Retired Key 20"
```

For Linux
```bash
ssh-keygen -D /usr/lib/libykcs11.so | grep "Retired Key 20"
```