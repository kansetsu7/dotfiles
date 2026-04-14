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

## Step 1: Read existing TOTP secret

The existing `.gpg` holds both `ABAGILE_VPN_TOTP_SECRET` and
`ABAGILE_VPN_PW`. Only the password is rotated — the TOTP secret must be
preserved verbatim.

```bash
gpg -dq "$HOME/.config/credentials/vpn_otp.env.gpg"
```

Capture the value after `ABAGILE_VPN_TOTP_SECRET=` from the output. If the
variable is missing or decryption fails, STOP and report.

## Step 2: Write plaintext env file

Use the Write tool to create `~/.config/credentials/vpn_otp.env` with exactly
this content (preserve the original `<totp_secret>`, replace `<pw>` with the
new password, no quoting, keep the trailing newline):

```
export ABAGILE_VPN_TOTP_SECRET=<totp_secret>
export ABAGILE_VPN_PW=<pw>
```

Using the Write tool (not `echo`) avoids shell-history leakage and
special-character escaping issues.

## Step 3: Encrypt with GPG

```bash
gpg -e -r gpg-key-la \
  -o "$HOME/.config/credentials/vpn_otp.env.gpg" \
  "$HOME/.config/credentials/vpn_otp.env"
```

The `-o` flag will overwrite the existing `.gpg` file. If gpg prompts for
overwrite confirmation, answer `y`.

## Step 4: Verify decryption

```bash
gpg -dq "$HOME/.config/credentials/vpn_otp.env.gpg"
```

Confirm both lines are present and match the plaintext exactly (TOTP secret
unchanged, password updated). If not, STOP and report — do not delete the
plaintext or commit.

## Step 5: Remove plaintext

```bash
rm "$HOME/.config/credentials/vpn_otp.env"
```

## Step 6: Commit the encrypted file

The file lives in the dotfiles repo via stow. Commit from `/root/.dotfiles`:

```bash
cd /root/.dotfiles
git add credentials/.config/credentials/vpn_otp.env.gpg
git commit -m "Update vpn_otp credential"
```

Stage **only** the `.gpg` file — do not stage unrelated changes or the
plaintext `.env` (it should already be deleted and gitignored).

Do not push.
