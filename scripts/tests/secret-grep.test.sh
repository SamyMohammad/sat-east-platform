#!/usr/bin/env bash
# Tests scripts/secret-grep.sh against fixture build dirs. Run: bash scripts/tests/secret-grep.test.sh
set -u
here="$(cd "$(dirname "$0")/.." && pwd)"
grep_sh="$here/secret-grep.sh"
fails=0
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT

b64url() { printf '%s' "$1" | base64 | tr -d '=\n' | tr '/+' '_-'; }
jwt() { echo "$(b64url '{"alg":"HS256","typ":"JWT"}').$(b64url "$1").sig"; }

expect() { # expect <name> <exit> <content>
  local d="$tmp/$1"; mkdir -p "$d"; printf '%s' "$3" > "$d/main.dart.js"
  bash "$grep_sh" "$d" >/dev/null 2>&1; local got=$?
  if [ "$got" -eq "$2" ]; then echo "ok   $1"; else echo "FAIL $1 (exit $got, want $2)"; fails=$((fails+1)); fi
}

expect clean_publishable 0 'const k="sb_publishable_ACJWlzQHlZjBrEguHvfOxg_3BJgxAaH";'
expect anon_jwt          0 "const k=\"$(jwt '{"iss":"supabase","role":"anon"}')\";"
expect lib_prefix_check  0 'if(!B.c.ai(a,"sb_")||B.c.ai(a,"sb_publishable_")||B.c.ai(a,"sb_secret_"))return'
expect notices_banner    0 ' #  ---------------COPYING.ipadic-----BEGIN-------------------------------'
expect secret_key        1 'const k="sb_secret_N7UND0UgjKTVK-Uodkm0Hg_xSvEMPvz";'
expect service_role_word 1 'headers.role="service_role";'
expect service_role_jwt  1 "const k=\"$(jwt '{"iss":"supabase","role":"service_role"}')\";"
expect private_key       1 '-----BEGIN PRIVATE KEY-----'
expect paymob_name       1 'PAYMOB_HMAC_SECRET=abc'
expect llm_key_name      1 'ANTHROPIC_API_KEY=x'
# Binary asset (NUL byte) carrying a service_role JWT: grep -o must not skip it.
mkdir -p "$tmp/binary_jwt"; printf 'x\000y %s' "$(jwt '{"role":"service_role"}')" > "$tmp/binary_jwt/AssetManifest.bin"
bash "$grep_sh" "$tmp/binary_jwt" >/dev/null 2>&1 && { echo "FAIL binary_jwt (want 1)"; fails=$((fails+1)); } || echo "ok   binary_jwt"
mkdir -p "$tmp/empty"; bash "$grep_sh" "$tmp/empty" >/dev/null 2>&1 && echo "ok   empty_dir" || { echo "FAIL empty_dir"; fails=$((fails+1)); }
bash "$grep_sh" "$tmp/missing" >/dev/null 2>&1 && { echo "FAIL missing_dir (want non-zero)"; fails=$((fails+1)); } || echo "ok   missing_dir"

[ "$fails" -eq 0 ] || exit 1
