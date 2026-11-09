#!/usr/bin/env bash
# Gets a fresh machine far enough to clone the private dotfiles repo, then
# hands over to its install.sh. Everything else lives there.
#
#   curl -fsSL https://raw.githubusercontent.com/martin-lundin/bootstrap/main/bootstrap.sh | bash
#
# Safe to re-run: every step skips itself if already done.
set -euo pipefail

REPO="git@github.com:martin-lundin/dotfiles.git"
DEST="$HOME/dotfiles"
KEY="$HOME/.ssh/id_ed25519"
SSH_CMD="ssh -i $KEY -o IdentitiesOnly=yes -o StrictHostKeyChecking=accept-new"

# Wrapped in main so a truncated download can't run half a script.
main() {
  # With `curl | bash`, stdin is the script itself: prompts must use the tty.
  if ! { : </dev/tty; } 2>/dev/null; then
    echo "!! No terminal available - run this interactively." >&2
    exit 1
  fi

  echo "==> git"
  if [ "$(uname -s)" = "Darwin" ]; then
    if ! xcode-select -p >/dev/null 2>&1; then
      xcode-select --install || true
      read -rp "    Finish the Command Line Tools install, then press Enter " </dev/tty
    fi
  elif ! command -v git >/dev/null 2>&1; then
    if command -v apt-get >/dev/null 2>&1; then
      sudo apt-get update && sudo apt-get install -y git
    elif command -v dnf >/dev/null 2>&1; then
      sudo dnf install -y git
    elif command -v pacman >/dev/null 2>&1; then
      sudo pacman -Sy --noconfirm git
    else
      echo "!! Install git manually and re-run." >&2
      exit 1
    fi
  fi

  echo "==> SSH key"
  if [ ! -f "$KEY" ]; then
    mkdir -p "$HOME/.ssh" && chmod 700 "$HOME/.ssh"
    ssh-keygen -t ed25519 -f "$KEY" -C "$(whoami)@$(hostname)" -N ""
  fi

  echo "==> GitHub access"
  until GIT_SSH_COMMAND="$SSH_CMD" git ls-remote "$REPO" >/dev/null 2>&1 </dev/null; do
    who="$($SSH_CMD -T git@github.com 2>&1 </dev/null | sed -n 's/^Hi \([^!]*\)!.*/\1/p' || true)"
    if [ -n "$who" ]; then
      echo
      echo "    Hi $who, thanks for your interest in this setup!"
      echo "    It only works for martin-lundin's own machines, though: it installs a"
      echo "    private dotfiles repo that your GitHub account can't read. Nothing past"
      echo "    git and an SSH key was set up. Feel free to borrow ideas from bootstrap.sh."
      exit 1
    fi
    echo "    This machine's key is not on GitHub yet. Add it as an Authentication Key at"
    echo "    https://github.com/settings/ssh/new :"
    echo
    cat "$KEY.pub"
    echo
    read -rp "    Press Enter once it is added " </dev/tty
  done

  echo "==> dotfiles"
  if [ ! -d "$DEST/.git" ]; then
    GIT_SSH_COMMAND="$SSH_CMD" git clone "$REPO" "$DEST"
  fi

  echo "==> Handing over to install.sh"
  exec "$DEST/install.sh" </dev/tty
}

main "$@"
