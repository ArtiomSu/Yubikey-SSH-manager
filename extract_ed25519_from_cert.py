#!/usr/bin/env python3
# extract_ed25519_from_cert.py
# Usage: python3 extract_ed25519_from_cert.py primary_ed_94_cert.pem [out.pub]
import sys, base64, struct, re, os

if len(sys.argv) < 2:
    print("Usage: python3 extract_ed25519_from_cert.py <cert.pem or cert.der> [out.pub]")
    sys.exit(2)

infile = sys.argv[1]
outfile = sys.argv[2] if len(sys.argv) > 2 else "primary_ed_94_ssh.pub"
comment = "CN=SSH key"

data = open(infile, "rb").read()

# Try to extract DER from PEM, otherwise assume DER already
m = re.search(b"-----BEGIN CERTIFICATE-----.*?-----END CERTIFICATE-----", data, re.S)
if m:
    pem = m.group(0).splitlines()
    b64 = b"".join(pem[1:-1])
    der = base64.b64decode(b64)
else:
    der = data

# OID for id-Ed25519 is 1.3.101.112 -> DER bytes 06 03 2B 65 70
oid = b'\x06\x03\x2b\x65\x70'
pos = der.find(oid)
if pos == -1:
    sys.exit("ERROR: Ed25519 OID (1.3.101.112) not found in certificate.")

# find BIT STRING (0x03) after the OID, expecting length 33 (0x21)
bs_idx = der.find(b'\x03\x21', pos)
if bs_idx == -1:
    # fallback: find first BIT STRING (0x03) after pos with length >=33
    found = False
    for i in range(pos, min(len(der)-2, pos+300)):
        if der[i] == 0x03:
            ln = der[i+1]
            if ln >= 33:
                bs_idx = i
                found = True
                break
    if not found:
        sys.exit("ERROR: could not locate subjectPublicKey BIT STRING in certificate.")

# payload starts at bs_idx + 2 (tag + length)
payload_start = bs_idx + 2
# first payload byte for BIT STRING is 'unused bits' count; then the 32-byte key
if payload_start >= len(der):
    sys.exit("ERROR: invalid BIT STRING location.")
if der[payload_start] != 0x00:
    # sometimes unused bits byte may not be present — handle carefully
    # but per X.509 it should be 0x00 for public keys
    pass

pubkey_start = payload_start + 1
pubkey = der[pubkey_start:pubkey_start+32]
if len(pubkey) != 32:
    sys.exit(f"ERROR: extracted public key length is {len(pubkey)} bytes (expected 32).")

# Build OpenSSH key blob: string "ssh-ed25519" + 32-byte pubkey
t = b"ssh-ed25519"
blob = struct.pack(">I", len(t)) + t + struct.pack(">I", len(pubkey)) + pubkey
b64blob = base64.b64encode(blob).decode('ascii')

openssh_line = f"ssh-ed25519 {b64blob} {comment}\n"
open(outfile, "w").write(openssh_line)
print(f"WROTE {outfile}")
print(openssh_line.strip())
