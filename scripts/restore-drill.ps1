# Restore drill (docs/setup/prod.md section 7): decrypt an encrypted backup made by
# scripts/db-backup.sh, restore it into a throwaway postgres:17 container and
# print row counts of core tables. Needs Docker and gpg (Git for Windows' gpg is fine).
#
#   scripts/restore-drill.ps1 -DumpFile .\restore.dump.gpg
#   scripts/restore-drill.ps1 -R2Object prod/<object>.dump.gpg      # needs aws + R2 env vars
#   scripts/restore-drill.ps1 -SelfTest                              # needs scripts/db-up.ps1 running
#
# The passphrase comes from $env:BACKUP_PASSPHRASE (else gpg prompts) and is never printed.
# The throwaway container is a vanilla Postgres, not Supabase: the roles Supabase policies
# refer to are created first, and restore errors are classified below. Extensions that only
# exist on Supabase (pg_cron, supabase_vault, ...) and their dependents are expected failures.
# Anything else fails the drill. Never point this at staging or prod; it holds real PII.
param(
  [string]$DumpFile,
  [string]$R2Object,
  [switch]$SelfTest
)
# Native tools write warnings to stderr; every call checks $LASTEXITCODE and Fail throws.
$ErrorActionPreference = 'Continue'

# Tunables: the throwaway image and the local Supabase DB container used by -SelfTest.
$PostgresImage = 'postgres:17'
$LocalDbContainer = 'supabase_db_sat-east-platform'
$ReadyTimeoutSec = 60
# Roles that policies in the dump are granted to (Supabase creates these itself).
$RequiredRoles = @('anon', 'authenticated', 'service_role', 'authenticator', 'supabase_admin',
                   'supabase_auth_admin', 'supabase_storage_admin', 'supabase_read_only_user',
                   'dashboard_user', 'pgbouncer')
# Core tables to count; the first two must be non-empty or the drill fails.
$CoreTables = @('public.profiles', 'public.courses', 'public.enrollments', 'public.questions',
                'private.question_keys', 'public.attempts', 'auth.users')
$MustHaveRows = @('public.questions', 'private.question_keys')
# Restore errors that are expected on vanilla Postgres (Supabase-only extensions and
# whatever depends on them) or harmless because the object pre-exists in the image.
$IgnorablePatterns = @(
  'schema "public" already exists',
  'extension "[a-z_]+" is not available',
  'could not open extension control file',
  'extension "[a-z_]+" does not exist',
  'schema "(cron|vault|net|graphql|graphql_public|extensions|pgsodium)" does not exist',
  'schema "(cron|vault|net|graphql|graphql_public|extensions|pgsodium)" already exists',
  'role "[a-z_]+" does not exist',
  'relation "(cron|vault|net)\.[a-z_]+" does not exist',
  'function (cron|vault|net|extensions)\.[a-z_]+\(.*\) does not exist',
  'type "?(cron|vault|net|extensions)\.[a-z_]+"? does not exist',
  'must be owner of extension'
)

function New-RandomSecret([int]$bytes) {
  $buf = New-Object byte[] $bytes
  $rng = New-Object Security.Cryptography.RNGCryptoServiceProvider
  $rng.GetBytes($buf)
  $rng.Dispose()
  [Convert]::ToBase64String($buf)
}
function Fail($msg) { throw "restore drill failed: $msg" }
function Find-Tool($name, $extraDirs) {
  $c = Get-Command $name -ErrorAction SilentlyContinue
  if ($c) { return $c.Source }
  foreach ($d in $extraDirs) {
    $p = Join-Path $d "$name.exe"
    if (Test-Path $p) { return $p }
  }
  return $null
}
function Invoke-Native([string]$what, [scriptblock]$cmd) {
  & $cmd
  if ($LASTEXITCODE -ne 0) { Fail "$what (exit $LASTEXITCODE)" }
}

if (-not $SelfTest -and -not $DumpFile -and -not $R2Object) {
  Fail 'pass -DumpFile <path>.dump.gpg, -R2Object <key>, or -SelfTest'
}
if (-not (Get-Command docker -ErrorAction SilentlyContinue)) { Fail 'docker is not installed' }
docker info *> $null
if ($LASTEXITCODE -ne 0) { Fail 'docker is not running' }
$gpg = Find-Tool 'gpg' @('C:\Program Files\Git\usr\bin', 'C:\Program Files (x86)\GnuPG\bin', 'C:\Program Files\GnuPG\bin')
if (-not $gpg) { Fail 'gpg is not installed' }

$work = Join-Path ([IO.Path]::GetTempPath()) ("restore-drill-" + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $work | Out-Null
$container = 'restore-drill-' + [guid]::NewGuid().ToString('N').Substring(0, 12)
$localDump = $null
$originalPassphrase = $env:BACKUP_PASSPHRASE
try {
  if ($SelfTest) {
    # Throwaway passphrase, set only for this process and restored in finally.
    $env:BACKUP_PASSPHRASE = New-RandomSecret 24
    $running = docker ps --filter "name=^$LocalDbContainer$" --format '{{.Names}}'
    if ($running -ne $LocalDbContainer) { Fail "local Supabase DB is not running ($LocalDbContainer); run scripts/db-up.ps1" }
    $localDump = "/tmp/$container.dump"
    Invoke-Native 'pg_dump of local DB' {
      docker exec $LocalDbContainer pg_dump -U postgres --format=custom --no-owner --no-privileges --file $localDump postgres
    }
    $plainDump = Join-Path $work 'selftest.dump'
    Invoke-Native 'copy local dump' { docker cp "${LocalDbContainer}:$localDump" $plainDump }
    $DumpFile = Join-Path $work 'selftest.dump.gpg'
    $env:BACKUP_PASSPHRASE | & $gpg --batch --yes --pinentry-mode loopback --no-symkey-cache --symmetric `
      --cipher-algo AES256 --passphrase-fd 0 --output $DumpFile $plainDump 2>$null
    if ($LASTEXITCODE -ne 0) { Fail 'self-test encryption' }
    Remove-Item -Force $plainDump
    Write-Host 'self-test: dumped local DB and encrypted it with a throwaway passphrase'
  }
  elseif ($R2Object) {
    foreach ($n in 'R2_ACCOUNT_ID', 'AWS_ACCESS_KEY_ID', 'AWS_SECRET_ACCESS_KEY') {
      if (-not [Environment]::GetEnvironmentVariable($n)) { Fail "$n is not set (needed for -R2Object)" }
    }
    if (-not (Get-Command aws -ErrorAction SilentlyContinue)) { Fail 'aws CLI is not installed (needed for -R2Object)' }
    if ($R2Object -notmatch '^[A-Za-z0-9._/-]+$') { Fail 'invalid -R2Object' }
    $bucket = if ($env:BACKUP_BUCKET) { $env:BACKUP_BUCKET } else { 'backups' }
    $DumpFile = Join-Path $work 'download.dump.gpg'
    Invoke-Native 'R2 download' {
      aws s3 cp "s3://$bucket/$R2Object" $DumpFile --endpoint-url "https://$($env:R2_ACCOUNT_ID).r2.cloudflarestorage.com" --region auto --only-show-errors
    }
  }
  if (-not (Test-Path -LiteralPath $DumpFile)) { Fail "dump file not found: $DumpFile" }

  # Decrypt into the private work dir.
  $plain = Join-Path $work 'restore.dump'
  $gpgArgs = @('--yes', '--no-symkey-cache', '--output', $plain, '--decrypt', $DumpFile)
  if ($env:BACKUP_PASSPHRASE) {
    $env:BACKUP_PASSPHRASE | & $gpg --batch --pinentry-mode loopback --passphrase-fd 0 @gpgArgs 2>$null
  } else {
    & $gpg @gpgArgs
  }
  if ($LASTEXITCODE -ne 0 -or -not (Test-Path $plain) -or (Get-Item $plain).Length -eq 0) { Fail 'decryption (wrong passphrase or corrupt file)' }

  # Throwaway Postgres on a random loopback port.
  $pgPassword = (New-RandomSecret 18) -replace '[^A-Za-z0-9]', 'x'
  Invoke-Native 'start container' {
    docker run -d --rm --name $container -e "POSTGRES_PASSWORD=$pgPassword" -p '127.0.0.1::5432' $PostgresImage | Out-Null
  }
  $port = (docker port $container 5432/tcp | Select-Object -First 1) -replace '^.*:', ''
  Write-Host "throwaway $PostgresImage container $container on 127.0.0.1:$port"
  $ready = $false
  for ($i = 0; $i -lt $ReadyTimeoutSec; $i++) {
    docker exec $container pg_isready -U postgres -d postgres *> $null
    if ($LASTEXITCODE -eq 0) {
      # The image restarts once after init; require two consecutive ready checks.
      Start-Sleep -Seconds 2
      docker exec $container pg_isready -U postgres -d postgres *> $null
      if ($LASTEXITCODE -eq 0) { $ready = $true; break }
    }
    Start-Sleep -Seconds 1
  }
  if (-not $ready) { Fail "container not ready after ${ReadyTimeoutSec}s" }

  $roleSql = ($RequiredRoles | ForEach-Object { "create role $_ nologin;" }) -join ' '
  Invoke-Native 'create roles' { docker exec $container psql -U postgres -v ON_ERROR_STOP=1 -q -c $roleSql }
  Invoke-Native 'copy dump into container' { docker cp $plain "${container}:/tmp/restore.dump" }

  $listing = docker exec $container pg_restore --list /tmp/restore.dump
  if ($LASTEXITCODE -ne 0) { Fail 'pg_restore --list (not a valid custom-format dump)' }
  foreach ($schema in 'public', 'private', 'auth', 'storage', 'supabase_migrations') {
    if (-not ($listing | Select-String -SimpleMatch " SCHEMA - $schema ")) {
      if ($schema -ne 'public') { Fail "dump has no schema '$schema'" }
    }
  }

  # No --exit-on-error: collect errors, then classify them.
  docker exec $container sh -c 'pg_restore -U postgres -d postgres --no-owner --no-privileges /tmp/restore.dump 2>/tmp/restore.err'
  $restoreExit = $LASTEXITCODE
  $errLines = @(docker exec $container cat /tmp/restore.err | Where-Object { $_ -match '^pg_restore: error:' })
  $bad = @($errLines | Where-Object {
    $line = $_
    -not ($IgnorablePatterns | Where-Object { $line -match $_ })
  })
  $ignored = $errLines.Count - $bad.Count
  Write-Host "restore exit code $restoreExit; $($errLines.Count) error line(s), $ignored ignorable, $($bad.Count) not ignorable"
  $errLines | Where-Object { $bad -notcontains $_ } | Select-Object -First 20 | ForEach-Object { Write-Host "  ignored: $_" }
  if ($bad.Count -gt 0) {
    # Object names only, never row data: errors from DDL carry no row values.
    $bad | Select-Object -First 20 | ForEach-Object { Write-Host "  $_" }
    Fail 'restore had non-ignorable errors'
  }

  # Row counts for the core tables.
  $failures = @()
  Write-Host 'row counts:'
  foreach ($t in $CoreTables) {
    $n = docker exec $container psql -U postgres -d postgres -XAtc "select count(*) from $t"
    if ($LASTEXITCODE -ne 0) { $failures += "$t unreadable"; Write-Host ("  {0,-24} MISSING" -f $t); continue }
    Write-Host ("  {0,-24} {1}" -f $t, $n)
    if ($MustHaveRows -contains $t -and [int64]$n -eq 0) { $failures += "$t has 0 rows" }
  }
  $mig = docker exec $container psql -U postgres -d postgres -XAtc 'select count(*) from supabase_migrations.schema_migrations'
  Write-Host ("  {0,-24} {1}" -f 'schema_migrations', $mig)
  if ($failures.Count -gt 0) { Fail ($failures -join '; ') }
  Write-Host 'RESTORE DRILL PASSED'
}
finally {
  docker rm -f $container *> $null
  if ($SelfTest -and $localDump) { docker exec $LocalDbContainer rm -f $localDump *> $null }
  Remove-Item -Recurse -Force -LiteralPath $work -ErrorAction SilentlyContinue
  $env:BACKUP_PASSPHRASE = $originalPassphrase
  $global:LASTEXITCODE = 0
}
