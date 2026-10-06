# Start local Supabase without the heavy containers (docs/16 section 6).
# Pass -Functions to keep edge-runtime running when working on Edge Functions.
param([switch]$Functions)
$exclude = 'imgproxy,logflare,vector'
if (-not $Functions) { $exclude += ',edge-runtime' }
supabase start -x $exclude
