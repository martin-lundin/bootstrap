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
OS="$(uname -s)"

# --- UI: a trimmed copy of lib/ui.sh in the dotfiles repo. Keep in step. ---
UI_WIDTH=72 UI_STEP=0 UI_STEPS=4
if [ -t 1 ] && [ -z "${NO_COLOR:-}" ] && [ "${TERM:-dumb}" != "dumb" ]; then
  UI_BOLD=$'\033[1m' UI_DIM=$'\033[2m' UI_OFF=$'\033[0m'
  UI_CYAN=$'\033[36m' UI_GREEN=$'\033[32m' UI_YELLOW=$'\033[33m' UI_RED=$'\033[31m'
else
  UI_BOLD="" UI_DIM="" UI_OFF="" UI_CYAN="" UI_GREEN="" UI_YELLOW="" UI_RED=""
fi
ui_repeat() { printf "%${2}s" "" | tr " " "$1"; }
ui_box() {
  local title="$1" inner=$((UI_WIDTH - 4)) line
  shift
  printf "\n  %s+%s+%s\n" "$UI_CYAN" "$(ui_repeat - $((UI_WIDTH - 2)))" "$UI_OFF"
  printf "  %s|%s %s%-${inner}.${inner}s%s %s|%s\n" "$UI_CYAN" "$UI_OFF" "$UI_BOLD" "$title" "$UI_OFF" "$UI_CYAN" "$UI_OFF"
  for line in "$@"; do
    printf "  %s|%s %-${inner}.${inner}s %s|%s\n" "$UI_CYAN" "$UI_OFF" "$line" "$UI_CYAN" "$UI_OFF"
  done
  printf "  %s+%s+%s\n" "$UI_CYAN" "$(ui_repeat - $((UI_WIDTH - 2)))" "$UI_OFF"
}
ui_step() {
  local title="$1" label line
  shift
  UI_STEP=$((UI_STEP + 1))
  label="[$UI_STEP/$UI_STEPS] $title "
  printf "\n  %s%s%s%s%s\n" "$UI_BOLD$UI_CYAN" "$label" "$UI_OFF$UI_DIM" "$(ui_repeat . $((UI_WIDTH - 2 - ${#label})))" "$UI_OFF"
  for line in "$@"; do
    printf "      %s%s%s\n" "$UI_DIM" "$line" "$UI_OFF"
  done
  echo
}
info() { printf "  %s==>%s %s\n" "$UI_CYAN" "$UI_OFF" "$1"; }
ok() { printf "  %s ok%s %s\n" "$UI_GREEN" "$UI_OFF" "$1"; }
fail() {
  local line
  for line in "$@"; do
    printf "  %s!! %s%s\n" "$UI_RED" "$line" "$UI_OFF" >&2
  done
  exit 1
}
pause() {
  printf "  %s ? %s%s " "$UI_YELLOW" "$UI_OFF" "$1"
  read -r _ </dev/tty
}
ui_yes() {
  local reply default="${2:-n}" hint="[y/N]"
  [ "$default" = "y" ] && hint="[Y/n]"
  printf "  %s ? %s%s %s " "$UI_YELLOW" "$UI_OFF" "$1" "$hint"
  read -r reply </dev/tty
  [ -n "$reply" ] || reply="$default"
  case "$reply" in [Yy]*) return 0 ;; esac
  return 1
}
# --- end UI ---

# Loads the key into ssh-agent (starting one if needed) so the passphrase is
# typed once; on macOS --apple-use-keychain also saves it in the Keychain.
# install.sh inherits the agent, so it won't ask again either.
load_key_into_agent() {
  local rc=0
  ssh-add -l >/dev/null 2>&1 || rc=$?
  if [ "$rc" -eq 2 ]; then
    eval "$(ssh-agent -s)" >/dev/null
  fi
  if ssh-add -l 2>/dev/null | grep -qF "$(ssh-keygen -lf "$KEY.pub" | awk '{print $2}')"; then
    ok "The key is already loaded in the ssh-agent"
    return
  fi
  if [ "$OS" = "Darwin" ]; then
    ssh-add -q --apple-use-keychain "$KEY" </dev/tty
  else
    ssh-add -q "$KEY" </dev/tty
  fi
}

step_git() {
  ui_step "Git" \
    "Needed to download your dotfiles. On macOS it comes with Apple's" \
    "Command Line Tools; on Linux from the package manager."
  if [ "$OS" = "Darwin" ]; then
    if xcode-select -p >/dev/null 2>&1; then
      ok "Command Line Tools are installed"
      return
    fi
    info "Opening the Command Line Tools installer in a dialog window"
    xcode-select --install || true
    pause "Press Enter once that install has finished"
    xcode-select -p >/dev/null 2>&1 || fail "The Command Line Tools are still missing - install them and re-run."
    ok "Command Line Tools are installed"
    return
  fi
  if command -v git >/dev/null 2>&1; then
    ok "git is installed"
    return
  fi
  info "Installing git (sudo may ask for your password)"
  if command -v apt-get >/dev/null 2>&1; then
    sudo apt-get update -qq && sudo apt-get install -y -qq git
  elif command -v dnf >/dev/null 2>&1; then
    sudo dnf install -y git
  elif command -v pacman >/dev/null 2>&1; then
    sudo pacman -Sy --noconfirm git
  else
    fail "No known package manager - install git manually and re-run."
  fi
  ok "git is installed"
}

step_key() {
  ui_step "SSH key" \
    "This machine's own key: how it proves to GitHub (and later to your" \
    "other machines) that it is yours."
  if [ -f "$KEY" ]; then
    ok "Using the existing key $KEY"
    if ! ssh-keygen -y -P "" -f "$KEY" >/dev/null 2>&1; then
      load_key_into_agent
    fi
    return
  fi
  mkdir -p "$HOME/.ssh" && chmod 700 "$HOME/.ssh"

  # Default: yes on workstations, no on servers (often unattended). The
  # installer asks for the role later, so use its saved answer if there is
  # one, else guess from the OS: a Mac is a workstation, Linux a server.
  local default=n
  if [ -f "$HOME/.dotfiles-role" ]; then
    [ "$(cat "$HOME/.dotfiles-role")" = "workstation" ] && default=y
  elif [ "$OS" = "Darwin" ]; then
    default=y
  fi
  info "A passphrase makes a stolen copy of the key useless. You type it once per session"
  info "(once ever on macOS, via the Keychain). Without one, nothing ever prompts."
  if ! ui_yes "Protect the new key with a passphrase?" "$default"; then
    ssh-keygen -q -t ed25519 -f "$KEY" -C "$(whoami)@$(hostname)" -N ""
    ok "Created $KEY without a passphrase ($(ssh-keygen -lf "$KEY.pub" | awk '{print $2}'))"
    return
  fi
  ssh-keygen -q -t ed25519 -f "$KEY" -C "$(whoami)@$(hostname)" </dev/tty
  while ssh-keygen -y -P "" -f "$KEY" >/dev/null 2>&1; do
    info "That passphrase was empty. Please set one (or re-run and answer no)."
    ssh-keygen -q -p -f "$KEY" </dev/tty
  done
  load_key_into_agent
  ok "Created $KEY ($(ssh-keygen -lf "$KEY.pub" | awk '{print $2}'))"
}

step_github() {
  ui_step "GitHub access" \
    "The dotfiles repo is private, so GitHub has to know this key before" \
    "it can be downloaded. You add it once in your browser."
  local who
  until GIT_SSH_COMMAND="$SSH_CMD" git ls-remote "$REPO" >/dev/null 2>&1 </dev/null; do
    who="$($SSH_CMD -T git@github.com 2>&1 </dev/null | sed -n 's/^Hi \([^!]*\)!.*/\1/p' || true)"
    if [ -n "$who" ]; then
      ui_box "Hi $who, thanks for your interest in this setup!" \
        "" \
        "It only works for martin-lundin's own machines, though: it installs" \
        "a private dotfiles repo that your GitHub account can't read." \
        "Nothing past git and an SSH key was set up. Feel free to borrow" \
        "ideas from bootstrap.sh."
      exit 1
    fi
    info "Add this key at https://github.com/settings/ssh/new as an Authentication Key:"
    echo
    cat "$KEY.pub"
    echo
    if [ "$OS" = "Darwin" ]; then
      pbcopy <"$KEY.pub" && ok "Copied to your clipboard"
      open "https://github.com/settings/ssh/new" 2>/dev/null || true
    fi
    pause "Press Enter once it is added"
  done
  ok "GitHub accepts this key and it can read the dotfiles repo"
}

step_clone() {
  ui_step "Dotfiles" \
    "Downloads the dotfiles to ~/dotfiles. The installer takes it from there."
  if [ -d "$DEST/.git" ]; then
    ok "Already downloaded to $DEST"
    return
  fi
  GIT_SSH_COMMAND="$SSH_CMD" git clone -q "$REPO" "$DEST"
  ok "Downloaded to $DEST"
}

# Wrapped in main so a truncated download can't run half a script.
main() {
  # With `curl | bash`, stdin is the script itself: prompts must use the tty.
  if ! { : </dev/tty; } 2>/dev/null; then
    fail "No terminal available - run this interactively."
  fi

  ui_box "dotfiles bootstrap" \
    "Gets this machine ready to install martin-lundin's dotfiles:" \
    "git, an SSH key, GitHub access, then the download. Each step" \
    "explains itself, and anything already done is skipped." \
    "" \
    "OS: $OS $(uname -m)   Host: $(hostname)"

  step_git
  step_key
  step_github
  step_clone

  ui_box "Ready" "Handing over to the dotfiles installer..."
  exec "$DEST/install.sh" </dev/tty
}

main "$@"
