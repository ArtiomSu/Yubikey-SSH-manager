# Yubikey SSH manager

This is a collection of scripts and notes on how to manage SSH keys on a Yubikey.

Currently the script only uses the PIV application as this allows you to use more than 1 key in the case of FIDO2 (but if you only need 1 key you should use the FIDO2 method instead as it is way easier to set up and use i.e instructions you find online will actually work...). You can also use OpenPGP method but I couldn't get that working so its not included in this repo.

So far I also was only able to get RSA4096 keys working. ED25519 keys don't work as they are not recognised by they yubico kcs11 module. I have left some notes on my attempts to get ED25519 keys working in the `manual_method.md` file. I was able to generate the public key just fine however the yubico kcs11 module along with ssh-keygen -D isn't able to read it. It takes around a minute to generate the RSA4096 private key which is very slow compared to ED25519 keys which are instant. But at least it works.

Using the `yubikey_ssh_manager.sh` script you can manage 20 ssh keys. And still be able to use the [macos login](https://support.yubico.com/hc/en-us/articles/360016649059-YubiKey-for-macOS-login) functionality, which also allows you to use the yubikey for `sudo`. 

The certs are fully stored on the yubikey so you don't need to store any ssh files on the computer. You only need to store the public keys on the server which can be exported from the yubikey at any point.

You don't need any special configuration on the server side. Only on the client side you need to setup a few things to handle the yubikey.

# Prerequisites

## Macos

Install the following packages

```bash
brew install openssh # needed for ssh-keygen
brew install yubico-authenticator # optional but handy
brew install ykman # needed for managing the ssh keys
brew install yubico-piv-tool # needed for the opensc pkcs11 module
```

optional packages that are no longer required or don't work with the current setup

```bash
brew install opensc # not needed anymore
brew install yubikey-agent # needed if you want to cache the ssh keys. otherwise you need to enter your pin every time doesn't work with the slots
```

## Linux

```bash
paru -S yubico-authenticator-bin
doas systemctl start pcscd && doas systemctl enable pcscd # needed for tools to work 
# paru -S pcsc-tools
paru -S yubikey-manager # ykman 
paru -S yubico-piv-tool # needed for the opensc pkcs11 module
```

## Termux [WIP]
currently struggling to access the yubikey

```bash
pkg install openssh
pkg install opensc
pkg install termux-api
pkg install libpcsclite
ln -s /data/data/com.termux/files/usr/lib/libpcsclite_real.so /data/data/com.termux/files/usr/lib/libpcsclite_real.so.1
```

# Running the script

Make sure you have the prerequisites installed and your yubikey is plugged in.
```bash
./yubikey_ssh_manager.sh
```

# Stuff that doesn't work

Yubikeys ended up being kinda shit in some cases. Here are a few things that don't work.

## Caching the pin doesn't work using the ssh config like so

```config
Host bitbucket.org
	PKCS11Provider /opt/homebrew/lib/libykcs11.dylib
	ControlMaster auto
	ControlPath ~/.ssh/controlmasters/%r@%h:%p
	ControlPersist 30m
```

```bash
mkdir -p ~/.ssh/controlmasters
chmod 700 ~/.ssh/controlmasters
```

## Caching the pin using the yubikey-agent doesn't work either

it seems like it can't read the retired slots for some reason that we are using for ssh

```bash
yubikey-agent --setup
yubikey-agent -l ~/.yubico/ssh-agent.sock
```

```config
Host bitbucket.org
	IdentityAgent ~/.yubico/ssh-agent.sock
```

## After a reboot it is not going to work

You just need to run this once and then everything should work again 

```bash
ykman piv info
```