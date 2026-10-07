# NFR-08 Layer 1 (docs/16 §1): the private schema is not reachable through the REST API.
# Run with the local stack up. Expects HTTP 406 (schema not exposed) for anon and service_role keys.
$status = supabase status -o json | ConvertFrom-Json
$failed = $false
foreach ($key in @($status.ANON_KEY, $status.SERVICE_ROLE_KEY)) {
  $headers = @{ apikey = $key; Authorization = "Bearer $key"; 'Accept-Profile' = 'private' }
  try {
    Invoke-WebRequest -UseBasicParsing -Uri "$($status.API_URL)/rest/v1/question_keys?select=*" -Headers $headers | Out-Null
    Write-Output 'FAIL: private.question_keys answered over REST'
    $failed = $true
  } catch {
    $code = [int]$_.Exception.Response.StatusCode
    if ($code -eq 406) { Write-Output 'PASS: private schema rejected (406)' }
    else { Write-Output "FAIL: expected 406, got $code"; $failed = $true }
  }
}
if ($failed) { exit 1 }
