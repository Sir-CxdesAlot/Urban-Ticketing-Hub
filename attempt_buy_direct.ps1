$ErrorActionPreference = 'Stop'
$base = 'http://localhost:8081/api/v1/passenger'
try {
    $login = Invoke-RestMethod -Method Post -Uri "$base/login" -ContentType 'application/json' -Body (@{ email='test.user+dbg@example.com'; password='Test123!' } | ConvertTo-Json -Depth 5)
    Write-Host 'LOGIN:'
    $login | ConvertTo-Json -Depth 5 | Write-Host
    $token = if ($login.token) { $login.token } elseif ($login.data -and $login.data.token) { $login.data.token } else { $null }
    if (-not $token) { Write-Host 'No token obtained'; exit 2 }
    Write-Host "TOKEN: $token"

    $body = @{ routeId = 'r-001'; ticketType = 'SINGLE' }
    try {
        $res = Invoke-RestMethod -Method Post -Uri "$base/tickets" -Headers @{ Authorization = "Bearer $token" } -ContentType 'application/json' -Body ($body | ConvertTo-Json -Depth 5)
        Write-Host 'SUCCESS:'
        $res | ConvertTo-Json -Depth 5 | Write-Host
    } catch {
        Write-Host 'ERROR POST:'
        Write-Host $_.Exception.ToString()
        if ($_.Exception.Response) {
            try {
                $sr = $_.Exception.Response.GetResponseStream(); if ($sr) { $r = New-Object System.IO.StreamReader($sr); $s=$r.ReadToEnd(); Write-Host 'RESPONSE BODY:'; Write-Host $s }
            } catch {}
        }
        exit 1
    }
} catch {
    Write-Host 'LOGIN ERROR:'; Write-Host $_.Exception.ToString(); exit 1
}