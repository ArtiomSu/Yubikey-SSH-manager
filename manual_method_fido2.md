# Manual Method For Managing SSH Keys with YubiKey using FIDO2

You can sort of use FIDO2 with Android but so far I have only managed to get it to work with termius app using their proprietary generated keys. So you cant see them on the yubikey itself which makes it useless.

You can in theory generate 100 FIDO2 ssh keys, however they take up the same space as your normal google keys so its not great, but easier to setup than the PIV method.

# Prerequisites

For linux you will need to install `libfido2`

```bash
paru -S libfido2
```

For macos you just need the latest openssh

```bash
brew install openssh
```

# Generate your first FIDO2 key

```bash
ssh-keygen -t ed25519-sk -O resident -O verify-required -C "Main SSH Key Primary"
```

When it asks you where to save the key I entered `/home/$USER/.ssh/yubikey_primary_id_ed25519_sk`

you will now have 2 new files in your .ssh folder

```bash
yubikey_primary_id_ed25519_sk
yubikey_primary_id_ed25519_sk.pub
```

# To create another key you can do the following

you can add anything after `=ssh:` to create multiple keys. Here I just use 1. You can also do `ssh:bitbutcket` or anything else to help you identify the keys later.

```bash
ssh-keygen -t ed25519-sk -O resident -O application=ssh:1 -C "Secondary SSH Key Primary"
```

When it asks you where to save the key I entered `/home/$USER/.ssh/yubikey_primary_2_id_ed25519_sk`

# Exporting keys from the Yubikey on a new pc

Since the FIDO2 method outputs files you will need to regenerate these on a new pc.

You can do it like this. This command will download all of the keys stored on the yubikey. Unfortunately the names are lost so you will need to rename them.

And should probably keep track of the names somewhere.

I recommed navigation into a new folder before running the command so you can easily organise them.

```bash
ssh-keygen -K
```
The public key files will have the `ssh:bitbucket` at the end of them so it should be easy to identify them.

# Managing keys

Its probably best to just use the yubico authenticator app. but you can do it from the command line too.

To list all the keys stored on the yubikey you can do the following first get the device path like so

```bash
fido2-token -L 
```

Then list the keys

```bash
fido2-token -L /dev/hidrawX -r
```

To get the count of keys used and remaining you can do

```bash
fido2-token -I -c /dev/hidrawX
```


To delete a specific key there are two steps. 

First get the credential ID of the key you want to delete

```bash
fido2-token -L /dev/hidrawX -k ssh:1
```

This will output a bunch of text that looks something like this
```txt
00: [CREDENTIAL_ID_HERE] openssh AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA= eddsa uvopt+id
```

Take the first part after the `00:` and then use that to delete the key like so

```bash
fido2-token -D -i [CREDENTIAL_ID_HERE] /dev/hidrawX
```






