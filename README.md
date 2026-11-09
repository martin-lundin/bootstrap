# bootstrap

Sets up a fresh macOS or Linux machine just far enough to clone my (private)
dotfiles repo, then runs its `install.sh`.

```sh
curl -fsSL https://raw.githubusercontent.com/martin-lundin/bootstrap/main/bootstrap.sh | bash
```

It installs git if missing, creates `~/.ssh/id_ed25519` if missing, asks you
to add that key to GitHub until SSH access works, clones the dotfiles to
`~/dotfiles` and hands over to `install.sh`. Safe to re-run.
