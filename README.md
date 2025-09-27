# Yubikey SSH manager

This is a collection of scripts and notes on how to manage SSH keys on a Yubikey.

Currently the repository includes two main scripts:

1. **PIV method** (`yubikey_ssh_manager_piv.sh`) - Uses the PIV application with RSA4096 keys
2. **FIDO2 method** (`yubikey_ssh_manager_fido2.sh`) - Uses FIDO2 with ED25519-SK keys

You can also use OpenPGP method but I couldn't get that working so its not included in this repo.

So far with the PIV method I was only able to get RSA4096 keys working. ED25519 keys don't work as they are not recognised by they yubico kcs11 module. I have left some notes on my attempts to get ED25519 keys working in the `manual_method_piv.md` file. The PIV method takes around a minute to generate the RSA4096 private key which is very slow compared to FIDO2 ED25519-SK keys which are instant.

Using the `yubikey_ssh_manager_piv.sh` script you can manage 20 ssh keys. And still be able to use the [macos login](https://support.yubico.com/hc/en-us/articles/360016649059-YubiKey-for-macOS-login) functionality, which also allows you to use the yubikey for `sudo`. 

The FIDO2 method using `yubikey_ssh_manager_fido2.sh` allows you to generate up to 100 keys (though they share space with your normal web login credentials), uses fast ED25519-SK key generation, but has some platform limitations.

The certs are fully stored on the yubikey so you don't need to store any ssh files on the computer (though FIDO2 method does create local key files that act as proxies). You only need to store the public keys on the server which can be exported from the yubikey at any point.

You don't need any special configuration on the server side. Only on the client side you need to setup a few things to handle the yubikey.

# Differences between PIV, FIDO2 and OpenPGP methods

| Feature                     | PIV                         | FIDO2                       | OpenPGP                    |
|-----------------------------|-----------------------------|-----------------------------|----------------------------|
| Number of keys              | 20                          | 100 (but is sharing normal web login)                         | N/A                        |
| Working Key types			  | RSA4096			            | ED25519                     | N/A                        |
| Key generation speed        | Slow (RSA4096 ~1min)        | Fast (ED25519 instant)      | N/A                        |
| Works with android		  | No                          | Not really (only in termius)| N/A                        |
| Works with macos            | Yes						    | Yes                         | N/A                        |	
| Works with linux            | Yes						    | Yes                         | N/A                        |	
| Works with windows          | N/A						    | N/A                         | N/A                        |	
| Ease of use                 | Easiest in terms of commands and ssh config | Easiest in terms of setup only need to install 1 package | N/A                        |	
| Easy to use script avaiable | Yes						    | Yes                         | No                         |	

Other notable differences are the PIV method stores the public and private keys directly on the yubikey. During the ssh authentication it tries every public key on the yubikey until it finds the right one making it the most portable option.

The FIDO2 method does store the private and public keys on the yubikey but for it to work you need to run a quick command to download all of the keys to the new pc. It does download the private keys but they are more like proxies. The advantage of this is you can basically treat it as regular ssh keys, only difference is you need to enter your yubikey pin when using them.

# Prerequisites

## Macos

Install the following packages

```bash
brew install openssh # needed for ssh-keygen
brew install yubico-authenticator # optional but handy
brew install ykman # needed for managing the PIV ssh keys
brew install yubico-piv-tool # needed for the PIV method
```

optional packages that are no longer required or don't work with the current setup

```bash
brew install opensc # not needed anymore
brew install yubikey-agent # needed if you want to cache the ssh keys. otherwise you need to enter your pin every time doesn't work with the slots
```

## Linux

```bash
paru -S yubico-authenticator-bin
doas systemctl start pcscd && doas systemctl enable pcscd # needed for PIV tools to work 
# paru -S pcsc-tools
paru -S yubikey-manager # ykman for PIV method
paru -S yubico-piv-tool # needed for the PIV method
paru -S libfido2 # needed for the FIDO2 method
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

# Running the scripts

Make sure you have the prerequisites installed and your yubikey is plugged in.

## PIV method
```bash
./yubikey_ssh_manager_piv.sh
```

## FIDO2 method
```bash
./yubikey_ssh_manager_fido2.sh
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