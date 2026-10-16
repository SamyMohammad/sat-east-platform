# Apply the P1 demo seed (supabase/seeds/demo/[0-9]*.sql) to the LOCAL database.
# Local only; idempotent. Run after scripts/db-reset.ps1.
# -Check also runs supabase/seeds/demo/check.sql afterwards (expects "demo seed OK").
# `supabase db query --file` cannot run multi-statement files (prepared
# statement), so this pipes each file to psql inside the local db container.
param([switch]$Check)

$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

$container = 'supabase_db_sat-east-platform'
$files = Get-ChildItem 'supabase/seeds/demo/[0-9]*.sql' | Sort-Object Name
if (-not $files) { Write-Error 'No demo seed files found in supabase/seeds/demo/'; exit 1 }
if ($Check) { $files = @($files) + (Get-Item 'supabase/seeds/demo/check.sql') }

foreach ($f in $files) {
  Write-Host "Running $($f.Name)"
  # cmd redirection streams the raw bytes, so UTF-8 (Arabic) content survives.
  cmd /c "docker exec -i $container psql -U postgres -d postgres -v ON_ERROR_STOP=1 --single-transaction -q -f - < `"$($f.FullName)`""
  if ($LASTEXITCODE -ne 0) {
    Write-Error "Demo seed failed on $($f.Name)"
    exit $LASTEXITCODE
  }
}
Write-Host 'Demo seed applied.'
