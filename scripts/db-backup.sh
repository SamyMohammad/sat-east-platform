#!/usr/bin/env bash
# Restore on a trusted machine, into an isolated local/scratch Supabase Postgres 17 DB:
#   aws s3 cp "s3://backups/prod/<object>.dump.gpg" ./restore.dump.gpg \
#     --endpoint-url "https://$R2_ACCOUNT_ID.r2.cloudflarestorage.com" --region auto
#   gpg --output restore.dump --decrypt restore.dump.gpg  # interactive passphrase
#   pg_restore --clean --if-exists --no-owner --no-privileges -d <scratch-url> restore.dump
# Never put a password in <scratch-url>; use PGPASSWORD. See docs/setup/prod.md for
# managed-schema/role caveats, validation and secure cleanup. Never upload artifacts.
set +x
set -euo pipefail
umask 077

fail() { printf '::error::Backup failed: %s\n' "$1" >&2; exit 1; }
for name in PROJECT_REF PGPASSWORD SUPABASE_ACCESS_TOKEN BACKUP_PASSPHRASE \
            R2_ACCOUNT_ID R2_ACCESS_KEY_ID R2_SECRET_ACCESS_KEY; do
  [[ -n "${!name:-}" ]] || fail "$name is not set"
done
BACKUP_BUCKET=${BACKUP_BUCKET:-backups}
BACKUP_LABEL=${BACKUP_LABEL:-}
[[ "$PROJECT_REF" =~ ^[a-z0-9]{20}$ ]] || fail 'invalid project ref'
[[ "$R2_ACCOUNT_ID" =~ ^[a-f0-9]{32}$ ]] || fail 'invalid R2 account ID'
[[ "$BACKUP_BUCKET" =~ ^[a-z0-9][a-z0-9.-]{1,61}[a-z0-9]$ ]] || fail 'invalid bucket'
[[ "$BACKUP_LABEL" =~ ^[A-Za-z0-9_-]{0,64}$ ]] || fail 'invalid label'

# GitHub masks registered secrets, but derived URLs need explicit masking too.
mask() {
  if [[ "${GITHUB_ACTIONS:-}" == true ]]; then
    local value=$1
    value=${value//'%'/'%25'}
    value=${value//$'\r'/'%0D'}
    value=${value//$'\n'/'%0A'}
    printf '::add-mask::%s\n' "$value"
  fi
}
for name in PGPASSWORD SUPABASE_ACCESS_TOKEN BACKUP_PASSPHRASE R2_ACCOUNT_ID \
            R2_ACCESS_KEY_ID R2_SECRET_ACCESS_KEY; do
  mask "${!name}"
done

for tool in supabase psql pg_dump gpg aws; do
  command -v "$tool" >/dev/null || fail "$tool is not installed"
done
[[ "$(pg_dump --version)" =~ \ 17\. ]] || fail 'Postgres 17 client required'

work_dir=$(mktemp -d)
cleanup() {
  rm -rf -- "$work_dir"
  # link caches connection details; do not leave them for later steps.
  rm -f -- supabase/.temp/pooler-url
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
# Tool diagnostics may contain URLs, PII or SQL. Never replay them to public logs.
quiet() { "$@" >"$work_dir/tool.log" 2>&1 || fail "$1 (diagnostics withheld)"; }

export SUPABASE_DB_PASSWORD="$PGPASSWORD"
quiet supabase link --project-ref "$PROJECT_REF"
[[ -s supabase/.temp/pooler-url ]] || fail 'pooler URL missing'
url=$(<supabase/.temp/pooler-url)
mask "$url"
# libpq gets the password only from PGPASSWORD; refuse a credential-bearing URL.
[[ "$url" == postgres*://* && "$url" != *$'\n'* && "$url" != *$'\r'* ]] || fail 'invalid pooler URL'
authority=${url#*://}
authority=${authority%%/*}
[[ "$authority" == *@* && "${authority%@*}" != *:* && "$url" != *\?* ]] || fail 'pooler URL must not contain a password or query'
export PGSSLMODE=require PGCONNECT_TIMEOUT=30
server_major=$(psql "$url" -XAtqc 'show server_version_num' 2>"$work_dir/tool.log") || fail 'server version check'
[[ "$server_major" =~ ^17[0-9]{4}$ ]] || fail 'server must be Postgres 17; update backup client before upgrading'

# No schema filter: includes public, private (answer keys), auth (PII), storage,
# and migration history. A permission/dump error fails closed, never a partial upload.
quiet pg_dump --dbname "$url" --format=custom --no-owner --no-privileges --file "$work_dir/database.dump"
[[ -s "$work_dir/database.dump" ]] || fail 'empty dump'
mkdir -m 700 "$work_dir/gnupg"
if ! printf '%s\n' "$BACKUP_PASSPHRASE" | gpg --homedir "$work_dir/gnupg" \
  --batch --yes --pinentry-mode loopback --symmetric --cipher-algo AES256 \
  --passphrase-fd 0 --output "$work_dir/database.dump.gpg" "$work_dir/database.dump" \
  >"$work_dir/tool.log" 2>&1; then
  fail 'encryption (diagnostics withheld)'
fi
rm -f -- "$work_dir/database.dump"

export AWS_ACCESS_KEY_ID="$R2_ACCESS_KEY_ID" AWS_SECRET_ACCESS_KEY="$R2_SECRET_ACCESS_KEY"
export AWS_DEFAULT_REGION=auto AWS_EC2_METADATA_DISABLED=true AWS_PAGER=''
object_key="prod/$(date -u +%Y-%m-%dT%H-%M-%S-%NZ)${BACKUP_LABEL:+-$BACKUP_LABEL}.dump.gpg"
endpoint="https://$R2_ACCOUNT_ID.r2.cloudflarestorage.com"
mask "$endpoint"
quiet aws s3 cp "$work_dir/database.dump.gpg" "s3://$BACKUP_BUCKET/$object_key" \
  --endpoint-url "$endpoint" --region auto --only-show-errors
printf '%s %s bytes\n' "$object_key" "$(wc -c < "$work_dir/database.dump.gpg" | tr -d '[:space:]')"
