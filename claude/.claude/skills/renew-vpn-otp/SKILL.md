---
name: renew-vpn-otp
description: Renew the VPN OTP password by writing it into `~/.config/credentials/vpn_otp.env`, encrypting with GPG, verifying, and committing the updated `.gpg` file.
---

# Renew VPN OTP

Update the encrypted VPN OTP credential stored at
`~/.config/credentials/vpn_otp.env.gpg` (stowed from the dotfiles repo).

## Arguments

- `pw` (required): the new VPN OTP password to encrypt.

If not provided, ask the user for it before proceeding.

## Step 1: Write plaintext env file

Use the Write tool to create `~/.config/credentials/vpn_otp.env` with exactly
this content (replace `<pw>` with the user-supplied password, no quoting):

```
export ABAGILE_VPN_PW=<pw>
```

Using the Write tool (not `echo`) avoids shell-history leakage and
special-character escaping issues.

## Step 2: Encrypt with GPG

```bash
gpg -e -r gpg-key-la \
  -o "$HOME/.config/credentials/vpn_otp.env.gpg" \
  "$HOME/.config/credentials/vpn_otp.env"
```

The `-o` flag will overwrite the existing `.gpg` file. If gpg prompts for
overwrite confirmation, answer `y`.

## Step 3: Verify decryption

```bash
gpg -dq "$HOME/.config/credentials/vpn_otp.env.gpg"
```

Confirm the output matches `export ABAGILE_VPN_PW=<pw>`. If it does not,
STOP and report the mismatch — do not delete the plaintext or commit.

## Step 4: Remove plaintext

```bash
rm "$HOME/.config/credentials/vpn_otp.env"
```

## Step 5: Commit the encrypted file

The file lives in the dotfiles repo via stow. Commit from `/root/.dotfiles`:

```bash
cd /root/.dotfiles
git add credentials/.config/credentials/vpn_otp.env.gpg
git commit -m "Update vpn_otp credential"
```

Stage **only** the `.gpg` file — do not stage unrelated changes or the
plaintext `.env` (it should already be deleted and gitignored).

Do not push.
