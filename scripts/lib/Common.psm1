#Requires -Version 7.2
# Shared HTTP/configuration boundary. No shell commands, credentials on disk, or body logging.
function New-UthContext {
    [CmdletBinding()]
    param([string]$BaseUrl = 'http://localhost', [int]$TimeoutSec = 15)
    $origin = $null
    if (-not [uri]::TryCreate($BaseUrl, [UriKind]::Absolute, [ref]$origin) -or
        $origin.Scheme -notin 'http', 'https' -or $origin.UserInfo -or
        $origin.AbsolutePath -ne '/' -or $origin.Query -or $origin.Fragment) {
        throw 'BaseUrl must be an HTTP(S) origin, for example http://localhost or http://localhost:9001.'
    }
    if ($TimeoutSec -lt 1 -or $TimeoutSec -gt 300) { throw 'TimeoutSec must be between 1 and 300.' }
    $ports = [ordered]@{ passenger = 8081; transport = 8082; ticketing = 8083; payment = 8084; notification = 8085; admin = 8086 }
    $urls = [ordered]@{}
    foreach ($name in $ports.Keys) {
        $builder = [UriBuilder]::new($origin)
        if ($origin.IsDefaultPort) { $builder.Port = $ports[$name] }
        $builder.Path = "/api/v1/$name"
        $urls[$name] = $builder.Uri.AbsoluteUri.TrimEnd('/')
    }
    [pscustomobject]@{ Urls = $urls; TimeoutSec = $TimeoutSec }
}

function Invoke-UthRequest {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]$Context,
        [Parameter(Mandatory)][string]$Service,
        [string]$Path = '',
        [ValidateSet('GET', 'POST', 'PUT', 'DELETE')][string]$Method = 'GET',
        [object]$Body,
        [string]$Token
    )
    if (-not $Context.Urls.Contains($Service)) { throw "Unknown service: $Service" }
    if ($Path -and -not $Path.StartsWith('/')) { throw 'Request paths must start with /.' }
    $params = @{
        Uri = $Context.Urls[$Service] + $Path
        Method = $Method
        TimeoutSec = $Context.TimeoutSec
        SkipHttpErrorCheck = $true
        ErrorAction = 'Stop'
        Headers = @{ Accept = 'application/json' }
    }
    if ($Token) { $params.Headers.Authorization = "Bearer $Token" }
    if ($PSBoundParameters.ContainsKey('Body')) {
        $params.Body = [Text.Encoding]::UTF8.GetBytes(($Body | ConvertTo-Json -Depth 20 -Compress))
        $params.ContentType = 'application/json; charset=utf-8'
    }
    Write-Verbose "$Method $Service$Path"
    $response = Invoke-WebRequest @params
    $data = $response.Content
    if (-not [string]::IsNullOrWhiteSpace($data)) {
        try { $data = ConvertFrom-Json -InputObject $data -AsHashtable -NoEnumerate -ErrorAction Stop } catch { }
    }
    if ([int]$response.StatusCode -lt 200 -or [int]$response.StatusCode -ge 300) {
        # Do not echo arbitrary response bodies, which may contain credentials or personal data.
        $failure = [Exception]::new("$Method $Service$Path returned HTTP $([int]$response.StatusCode).")
        $failure.Data['StatusCode'] = [int]$response.StatusCode
        throw $failure
    }
    # An envelope preserves JSON arrays, including empty and singleton arrays, through PowerShell pipelines.
    [pscustomobject]@{ StatusCode = [int]$response.StatusCode; Data = $data }
}

function Get-UthId {
    param([object]$Item, [switch]$BusinessId)
    $keys = if ($BusinessId) { @('id', '_id') } else { @('_id', 'id') }
    foreach ($key in $keys) {
        if ($Item -is [Collections.IDictionary]) { $value = $Item[$key] }
        elseif ($null -ne $Item) { $value = $Item.PSObject.Properties[$key].Value }
        else { $value = $null }
        if ($value -is [string] -and $value) { return $value }
    }
    throw 'Response does not contain a string id or _id.'
}

function ConvertTo-UthSegment {
    param([Parameter(Mandatory)][string]$Value)
    [uri]::EscapeDataString($Value)
}

function Assert-Uth {
    param([bool]$Condition, [string]$Message = 'Assertion failed.')
    if (-not $Condition) { throw $Message }
}

function Assert-UthSuccess {
    param([object]$Data)
    Assert-Uth ($Data -is [Collections.IDictionary] -and $Data['success'] -eq $true) 'API did not report success.'
}

function Get-UthItems {
    param($Context, [string]$Service, [string]$Path, [string]$Token)
    $offset = 0
    do {
        $joiner = if ($Path.Contains('?')) { '&' } else { '?' }
        $page = (Invoke-UthRequest -Context $Context -Service $Service -Path "${Path}${joiner}limit=100&offset=$offset" -Token $Token).Data
        foreach ($item in $page['items']) { Write-Output $item }
        $offset += @($page['items']).Count
    } while ($offset -lt $page['total'] -and @($page['items']).Count -gt 0)
}

Export-ModuleMember -Function New-UthContext, Invoke-UthRequest, Get-UthId, ConvertTo-UthSegment, Assert-Uth, Assert-UthSuccess, Get-UthItems
