# bootstrap

Sets up a fresh macOS or Linux machine just far enough to clone my (private)
dotfiles repo, then runs its `install.sh`.

## Verified start

Paste this in a terminal (zsh or bash). It checks this script's signature
against the fleet CA before running it, and the script checks that the
dotfiles it downloads are signed by the same CA before installing them:

```sh
CA='ecdsa-sha2-nistp384 AAAAE2VjZHNhLXNoYTItbmlzdHAzODQAAAAIbmlzdHAzODQAAABhBItumRrSyQCW3KOIKtmSBnSowFoeXpSWlLBFCnu77ihas1i9I+MM+dDOhHfQTbb48lKlH5dabvT8mScrd2eRJLUQphZDDmNL3f5QX66BpE3OkTRHhgPZniQSBoyQQQxiNA=='; d="$(mktemp -d)" && cd "$d" && u=https://raw.githubusercontent.com/martin-lundin/bootstrap/main && curl -fsSLO "$u/bootstrap.sh" && curl -fsSLO "$u/bootstrap.sh.sig" && ssh-keygen -Y verify -f <(echo "martin cert-authority $CA") -I martin -n bootstrap -s bootstrap.sh.sig < bootstrap.sh && BOOTSTRAP_CA="$CA" bash bootstrap.sh
```

**Keep your own copy of this command outside GitHub** (Bitwarden, paper):
the copy above is only a convenience. Anyone who could change this
repository could change it too; your stored copy is what the check relies on.

The signature (`bootstrap.sh.sig`) is made with a fleet admin certificate:
`./sign.sh` after every change to `bootstrap.sh`, and again after the
certificate is renewed, since a signature only verifies while its
certificate is valid.

## If the verified start fails

**Symptom:** the verified command prints `Could not verify signature` (or
`Signature verification failed`) and stops. Nothing from the download was
run.

**Causes, most likely first:**
1. **The signing certificate expired.** `bootstrap.sh.sig` is made with a
   fleet admin certificate, and those are valid for one year (renewed every
   November). A signature only verifies while its certificate is valid. The
   fleet's status report warns 30 days ahead, and certificate renewal
   re-signs automatically, so this means both were missed.
2. **`bootstrap.sh` was changed without re-signing** (`./sign.sh`).
3. **Someone changed this repository.** Assume this until 1 or 2 is
   confirmed.

**A. You still have a working fleet Mac** (it has `~/dotfiles`, Secretive,
and you have the CA YubiKey):
```sh
dotfiles-keys sign-pending --commit   # renews expiring certificates (YubiKey: PIN, then touch), then re-signs bootstrap
dotfiles-keys sign-bootstrap          # only re-sign bootstrap.sh with this Mac's admin certificate (Touch ID)
```
Then run the verified command again.

**B. No working fleet Mac.** Check whether the signature was valid at an
earlier date, in the same terminal after the failed command (it defines
`$CA` and leaves you in the download folder):
```sh
ssh-keygen -Y verify -f <(echo "martin cert-authority $CA") -I martin -n bootstrap \
  -s bootstrap.sh.sig -Overify-time=YYYYMMDD < bootstrap.sh
```
Use a date about a month before it stopped working. If it says `Good
"bootstrap" signature`, the script is the one you signed back then, so run
it: `BOOTSTRAP_CA="$CA" bash bootstrap.sh`. The script's own check of the
dotfiles still works, since git checks each commit against the time it
was made. If no date in the past year gives `Good`, do not run it: look at
this repository's recent commits first (cause 2 or 3). Once the machine is
set up, renew and re-sign as in A.

**To check the CA key in your stored command** against the printed backup
page: `echo "$CA" | ssh-keygen -lf -` must show
`SHA256:gJb3O/e8eYzs6vbtlfiRB+q7v21fNAua2rrNrOWnwmA`.

**Context for whoever helps (including an AI assistant):** the fleet SSH CA
(`bitbot-fleet-ca-202611`, ECDSA P-384) lives in PIV slot 9a of a YubiKey,
with an encrypted offline backup (USB stick and a printed page; the
passphrase is in Bitwarden, "Bitbot Fleet SSH CA - backup passphrase"). It
signs one-year admin certificates for each Mac's Secretive admin key
(principal `martin`); certificates are recorded in `fleet/ca/issued.tsv` of
the private dotfiles repo, and `dotfiles-keys sign` / `sign-pending` issue
them (`ssh-keygen -D` with Yubico's PKCS#11 library, PIN once, then touch).
Dotfiles commits must be signed with such a certificate (`scripts/dotfiles-pull`
refuses anything else). `bootstrap.sh.sig` is an `ssh-keygen -Y sign`
signature with namespace `bootstrap`, made by `sign.sh` from an admin
certificate; the verified command checks it with the CA as a
`cert-authority` signer.

## Unverified start

```sh
curl -fsSL https://raw.githubusercontent.com/martin-lundin/bootstrap/main/bootstrap.sh | bash
```

Checks nothing, and asks before running the installer.

## What it does

On macOS it installs the Command Line Tools (git), Homebrew and gh if
missing, opens Bitwarden in the App Store if it is not installed, logs in
to GitHub in the browser (`gh auth login`, with the passkey from Bitwarden)
and clones the dotfiles over HTTPS. No ssh key is made: `install.sh` gives
the Mac its own keys and switches the clone to ssh.

On Linux it installs git if missing, creates `~/.ssh/id_ed25519` if
missing and asks you to add that key to GitHub until SSH access works, then
clones over ssh.

Either way it clones to `~/dotfiles`, checks the signature of what it
cloned (verified start only) and hands over to `install.sh`. Safe to re-run.
