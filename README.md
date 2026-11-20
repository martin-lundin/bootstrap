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
