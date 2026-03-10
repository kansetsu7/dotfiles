# GPG-Encrypted Credentials

## Encrypt with public key (not symmetric)

To allow `gpg-agent` to cache the passphrase (so you only enter it once
for all files), encrypt with your **public key** — not a symmetric passphrase.

```bash
# Generate a key (if you don't have one)
gpg --full-generate-key
# Choose: RSA and RSA, 4096 bits, expiry as desired

# Encrypt a credential file
gpg -e -r YOUR_KEY_ID -o ~/.config/credentials/foo.env.gpg foo.env

# Decrypt (test)
gpg -dq ~/.config/credentials/foo.env.gpg
```

## Re-encrypt existing symmetric files to public key

```bash
gpg -dq old.env.gpg | gpg -e -r YOUR_KEY_ID -o new.env.gpg
mv new.env.gpg old.env.gpg
```

## gpg-agent config (~/.gnupg/gpg-agent.conf)

```
default-cache-ttl 86400
max-cache-ttl 604800
```

This caches the private key passphrase for 24h (7d max), so decrypting
multiple files in .zshrc only prompts once.

**Important:** Symmetric encryption (`gpg -c`) does NOT benefit from
gpg-agent caching — each file will prompt separately.
