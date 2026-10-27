#Requires -Version 7.2
$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path

function New-UthSecrets {
    $runtime = Join-Path $projectRoot '.runtime'
    New-Item -ItemType Directory -Path $runtime -Force | Out-Null
    $envPath = Join-Path $projectRoot '.env'
    if (-not (Test-Path -LiteralPath $envPath)) {
        $random = { [Convert]::ToHexString([Security.Cryptography.RandomNumberGenerator]::GetBytes(24)).ToLowerInvariant() }
        @("MONGO_ROOT_PASSWORD=$(& $random)", "MONGO_APP_PASSWORD=$(& $random)",
          'UTH_ADMIN_EMAIL=admin@uth.local', "UTH_ADMIN_PASSWORD=$(& $random)") | Set-Content -LiteralPath $envPath -Encoding utf8
    }
    $keyPath = Join-Path $runtime 'mongo-key'
    if (-not (Test-Path -LiteralPath $keyPath)) {
        [Convert]::ToBase64String([Security.Cryptography.RandomNumberGenerator]::GetBytes(96)) | Set-Content -LiteralPath $keyPath -NoNewline -Encoding ascii
    }
    Write-Host 'Local secrets are ready in ignored .env and .runtime files. Existing values were preserved.'
}

function Get-UthEnvironment {
    $values = @{}
    $path = Join-Path $projectRoot '.env'
    if (-not (Test-Path -LiteralPath $path)) { throw 'Run pwsh ./uth.ps1 setup first.' }
    foreach ($line in Get-Content -LiteralPath $path) {
        if ($line -match '^([A-Z_]+)=(.*)$') { $values[$Matches[1]] = $Matches[2] }
    }
    return $values
}

function Invoke-UthCompose {
    param([string[]]$Arguments)
    Push-Location $projectRoot
    try {
        $dockerTool=(Get-Command docker -CommandType Application -ErrorAction Stop | Select-Object -First 1).Source
        & $dockerTool compose @Arguments
        if ($LASTEXITCODE -ne 0) { throw "Docker Compose failed (exit $LASTEXITCODE)." }
    } finally { Pop-Location }
}

function Backup-UthDatabase {
    $folder = Join-Path $projectRoot '.runtime/backups'
    New-Item -ItemType Directory -Path $folder -Force | Out-Null
    $name = (Get-Date -AsUTC -Format 'yyyyMMddTHHmmssfffZ') + '-' + [guid]::NewGuid().ToString('N').Substring(0,8) + '.archive.gz'
    $path = Join-Path $folder $name
    $remote = "/tmp/$name"
    # Durability: include the oplog so restoration can recover a consistent point across transactions.
    Invoke-UthCompose -Arguments @('exec','-T','-e',"UTH_ARCHIVE=$remote",'mongodb','sh','-c',
        'mongodump --username "$MONGO_INITDB_ROOT_USERNAME" --password "$MONGO_INITDB_ROOT_PASSWORD" --authenticationDatabase admin --oplog --archive="$UTH_ARCHIVE" --gzip --quiet')
    Invoke-UthCompose -Arguments @('cp',"mongodb:$remote",$path)
    Write-Host "Backup saved: $path"
}

function Test-UthRestore {
    param([Parameter(Mandatory)][string]$BackupPath)
    $archive = (Resolve-Path -LiteralPath $BackupPath).Path
    $name = 'uth-restore-check-' + [guid]::NewGuid().ToString('N').Substring(0,10)
    $dockerTool=(Get-Command docker -CommandType Application -ErrorAction Stop | Select-Object -First 1).Source
    $created = $false
    try {
        & $dockerTool run -d --name $name --network none --memory 512m 'uth-demo-v2-mongodb:local' --replSet restore-check --bind_ip 127.0.0.1 | Out-Null
        if ($LASTEXITCODE -ne 0) { throw 'Could not start the isolated restoration container.' }
        $created = $true
        $ready = $false
        foreach ($attempt in 1..30) {
            & $dockerTool exec $name mongosh --quiet --eval 'try { rs.status() } catch(e) { rs.initiate({_id:"restore-check",members:[{_id:0,host:"127.0.0.1:27017"}]}) }; if(!db.hello().isWritablePrimary) quit(1);' *> $null
            if ($LASTEXITCODE -eq 0) { $ready=$true; break }
            Start-Sleep -Seconds 1
        }
        if (-not $ready) { throw 'The isolated restoration database did not become ready.' }
        & $dockerTool cp $archive "${name}:/tmp/backup.archive.gz"
        if ($LASTEXITCODE -ne 0) { throw 'Could not copy the backup.' }
        & $dockerTool exec $name mongorestore --archive=/tmp/backup.archive.gz --gzip --oplogReplay --quiet
        if ($LASTEXITCODE -ne 0) { throw 'Backup restoration failed.' }
        & $dockerTool exec $name mongosh --quiet --eval 'const d=db.getSiblingDB("uth_demo_v2"); if(d.accounts.countDocuments({role:"SUPER_ADMIN"})<1) quit(1); print("Restored accounts: "+d.accounts.countDocuments({})+"; bookings: "+d.bookings.countDocuments({}));'
        if ($LASTEXITCODE -ne 0) { throw 'Restored data verification failed.' }
        Write-Host 'Restoration verified in an isolated container; the running application database was not modified.'
    } finally {
        if ($created) {
            & $dockerTool rm -fv $name | Out-Null
            if ($LASTEXITCODE -ne 0) { throw 'Restore-check container cleanup failed.' }
        }
    }
}

Export-ModuleMember -Function New-UthSecrets, Get-UthEnvironment, Invoke-UthCompose, Backup-UthDatabase, Test-UthRestore
