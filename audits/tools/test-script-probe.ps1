# All requests fail locally through a stub. No HTTP calls are made.
function Invoke-RestMethod { throw 'AUDIT: synthetic service unavailable' }
$auditRoot = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$auditSource = & git -C $auditRoot show '7d56d4e:test-apis.ps1'
if ($LASTEXITCODE -ne 0) { throw 'Cannot read the historical audit baseline.' }
& ([scriptblock]::Create(($auditSource -join [Environment]::NewLine)))
