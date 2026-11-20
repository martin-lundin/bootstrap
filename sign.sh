#!/usr/bin/env bash
# Signs bootstrap.sh as bootstrap.sh.sig with this Mac's fleet admin
# certificate (Secretive asks for Touch ID), namespace "bootstrap", and
# checks the result against the fleet CA. Run after every change to
# bootstrap.sh, and after the admin certificate is renewed (a signature only
# verifies while the certificate that made it is valid). Commit both files.
set -euo pipefail
cd "$(dirname "$0")"
fleet="${DOTFILES_DIR:-$HOME/dotfiles}/fleet"
sock="$HOME/Library/Containers/com.maxgoedjen.Secretive.SecretAgent/Data/socket.ssh"
ca="$(ls "$fleet"/ca/*.pub | head -1)"
agent_fps="$(SSH_AUTH_SOCK="$sock" ssh-add -l 2>/dev/null | awk '{print $2}')"
cert=""
for c in "$fleet"/*/*-admin-[0-9][0-9][0-9][0-9][0-9][0-9]-cert.pub; do
  [ -f "$c" ] || continue
  printf '%s\n' "$agent_fps" | grep -qxF "$(ssh-keygen -lf "${c%-cert.pub}.pub" | awk '{print $2}')" && cert="$c"
done
[ -n "$cert" ] || { echo "sign.sh: no fleet admin certificate whose key is in Secretive" >&2; exit 1; }
rm -f bootstrap.sh.sig
SSH_AUTH_SOCK="$sock" ssh-keygen -Y sign -f "$cert" -n bootstrap bootstrap.sh
ssh-keygen -Y verify -f <(echo "martin cert-authority $(awk '{print $1, $2}' "$ca")") -I martin -n bootstrap \
  -s bootstrap.sh.sig <bootstrap.sh
echo "sign.sh: signed with $(basename "$cert" -cert.pub); valid until $(ssh-keygen -Lf "$cert" | awk '/Valid:/ {print $NF}')"
