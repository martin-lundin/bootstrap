# bootstrap

Sets up a fresh macOS or Linux machine just far enough to clone my (private)
dotfiles repo, then runs its `install.sh`.

```sh
curl -fsSL https://raw.githubusercontent.com/martin-lundin/bootstrap/main/bootstrap.sh | bash
```

On macOS it installs the Command Line Tools (git), Homebrew, gh and
Bitwarden if missing, logs in to GitHub in the browser (`gh auth login`,
with the passkey from Bitwarden) and clones the dotfiles over HTTPS. No ssh
key is made: `install.sh` gives the Mac its own keys and switches the clone
to ssh.

On Linux it installs git if missing, creates `~/.ssh/id_ed25519` if
missing and asks you to add that key to GitHub until SSH access works, then
clones over ssh.

Either way it clones to `~/dotfiles` and hands over to `install.sh`. Safe
to re-run.
