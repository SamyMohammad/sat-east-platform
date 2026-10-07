#!/usr/bin/env bash
# Rule 4 / A.6: fail if a built client bundle contains server-only secrets.
# Usage: scripts/secret-grep.sh <build-dir>   (e.g. apps/client/build/web)
set -u
dir="${1:?usage: secret-grep.sh <build-dir>}"
[ -d "$dir" ] || { echo "secret-grep: no such dir: $dir" >&2; exit 2; }

# Extended regexes. Key patterns need a key body: supabase_flutter itself contains the bare
# prefix "sb_secret_", and Flutter's NOTICES file contains "-----BEGIN-----" licence banners.
patterns=(
  'sb_secret_[A-Za-z0-9_-]{8,}'
  'service_role'
  '-----BEGIN [A-Z ]*PRIVATE KEY-----'
  'PAYMOB_'
  'R2_SECRET'
  'VDOCIPHER'
  'ANTHROPIC_API_KEY'
  'OPENAI_API_KEY'
)
found=0
for p in "${patterns[@]}"; do
  while IFS= read -r f; do echo "LEAK: $f: $p"; found=1; done < <(grep -rlE -e "$p" "$dir")
done

# JWTs: decode each payload and look for a service_role claim.
while IFS=: read -r f tok; do
  payload="$(printf '%s' "$tok" | cut -d. -f2 | tr '_-' '/+')"
  while [ $(( ${#payload} % 4 )) -ne 0 ]; do payload="$payload="; done
  if printf '%s' "$payload" | base64 -d 2>/dev/null | grep -q '"role" *: *"service_role"'; then
    echo "LEAK: $f: service_role JWT"; found=1
  fi
done < <(grep -rEo 'eyJ[A-Za-z0-9_-]+\.eyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]*' "$dir")

[ "$found" -eq 0 ] && echo "secret-grep: clean ($dir)"
exit "$found"
