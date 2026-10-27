#Requires -Version 7.2
Import-Module (Join-Path $PSScriptRoot 'Common.psm1') -DisableNameChecking

function Read-UthPassword {
    $secure = Read-Host 'Password' -AsSecureString
    [Net.NetworkCredential]::new('', $secure).Password
}

function Read-UthMenu {
    param([string]$Title, [string[]]$Options)
    Write-Host "`n$Title" -ForegroundColor Cyan
    for ($i = 0; $i -lt $Options.Count; $i++) { Write-Host ("{0}. {1}" -f ($i+1), $Options[$i]) }
    Write-Host '0. Back / exit'
    Read-Host 'Select an option'
}

function Show-UthData { param($Data); $Data | ConvertTo-Json -Depth 15 | Out-Host }

function Show-UthPages {
    param($Context, [string]$Service, [string]$Path, [string]$Token)
    $offset=0
    do {
        $joiner=if($Path.Contains('?')) { '&' } else { '?' }
        $page=(Invoke-UthRequest -Context $Context -Service $Service -Path "${Path}${joiner}limit=20&offset=$offset" -Token $Token).Data
        Show-UthData $page
        $choice=Read-Host 'n = next page, p = previous page, Enter = back'
        if($choice -eq 'n' -and $offset+20 -lt $page['total']) { $offset+=20 }
        elseif($choice -eq 'p' -and $offset -ge 20) { $offset-=20 }
        else { return }
    } while($true)
}

function Read-UthValue {
    param([string]$Label, $Current='')
    $answer=Read-Host "$Label [$Current]"
    if($answer -eq '') { return $Current }
    return $answer
}

function Read-UthRoute {
    param($Existing=@{})
    $stops=Read-UthValue 'Intermediate stops, comma separated' ($Existing['intermediateStops'] -join ', ')
    return @{
        name=Read-UthValue 'Route name' $Existing['name']; startLocation=Read-UthValue 'Start' $Existing['startLocation']
        endLocation=Read-UthValue 'Destination' $Existing['endLocation']; intermediateStops=@($stops -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ })
        transportType=(Read-UthValue 'BUS, TRAIN, or SHUTTLE' ($Existing['transportType'] ?? 'BUS')).ToUpperInvariant()
        baseFareMinor=[int](Read-UthValue 'Fare in minor units (850 = NAD 8.50)' ($Existing['baseFareMinor'] ?? 850))
    }
}

function Read-UthTrip {
    param($Existing=@{})
    return @{
        routeId=Read-UthValue 'Route ID' $Existing['routeId']; operatorId=Read-UthValue 'Assigned operator ID' $Existing['operatorId']
        capacity=[int](Read-UthValue 'Seats (1–200)' ($Existing['capacity'] ?? 40))
        departureTime=Read-UthValue 'Departure (ISO 8601 with timezone)' $Existing['departureTime']
        arrivalTime=Read-UthValue 'Arrival (ISO 8601 with timezone)' $Existing['arrivalTime']
    }
}

function Select-UthItem {
    param($Items, [string]$Label)
    $list = @($Items)
    if ($list.Count -eq 0) { throw "No $Label available." }
    for ($i = 0; $i -lt $list.Count; $i++) {
        $item = $list[$i]
        $description = if ($item['name']) { $item['name'] } elseif ($item['route']) { "$($item['route']['name']) / $($item['departureTime']) / $($item['status'])" } else { "$($item['id']) / $($item['status'])" }
        Write-Host ("{0}. {1}" -f ($i+1), $description)
    }
    $number = 0
    $choice = Read-Host "Choose $Label (0 to cancel)"
    if ([int]::TryParse($choice,[ref]$number) -and $number -ge 1 -and $number -le $list.Count) { return $list[$number-1] }
    return $null
}

function Start-UthCli {
    param($Context, [string]$Role = 'menu')
    $token = ''
    $user = $null
    $call = {
        param($Service, $Path, $Method = 'GET', $Body)
        $parameters = @{ Context=$Context; Service=$Service; Path=$Path; Method=$Method; Token=$token }
        if ($null -ne $Body) { $parameters.Body=$Body }
        (Invoke-UthRequest @parameters).Data
    }
    while ($true) {
        try {
            if (-not $user) {
                $choice = Read-UthMenu 'Windhoek Ticketing' @('Sign in (passenger or staff)','Create passenger account','Browse routes','Browse trips')
                switch ($choice) {
                    '0' { return }
                    '1' {
                        $token=''; $user=$null
                        $login = & $call passenger /login POST @{ email=Read-Host 'Email'; password=Read-UthPassword }
                        Assert-Uth (-not [string]::IsNullOrWhiteSpace($login['token'])) 'Login returned no session.'
                        $token=$login['token']; $user=$login['user']
                        Write-Host "Signed in as $($user['firstName']) ($($user['role']))."
                    }
                    '2' { Show-UthData (& $call passenger /register POST @{
                        email=Read-Host 'Email'; password=Read-UthPassword; firstName=Read-Host 'First name';
                        lastName=Read-Host 'Last name'; phone=Read-Host 'Phone'
                    }) }
                    '3' { Show-UthPages $Context transport /routes '' }
                    '4' { Show-UthPages $Context transport /trips '' }
                }
                continue
            }
            if ($user['role'] -eq 'PASSENGER') {
                $choice = Read-UthMenu 'Passenger' @('Buy a ticket','My bookings','My tickets','Book with an existing ticket','My payments','Notifications','Profile','Cancel booking','Refund unused ticket','Mark notification read','Edit profile','Sign out','Delete notification','Delete my account')
                switch ($choice) {
                    '0' { return }
                    '1' {
                        $trip = Select-UthItem @(Get-UthItems -Context $Context -Service transport -Path /trips) 'trip'
                        if (-not $trip) { continue }
                        $product = (Read-Host 'Ticket type: SINGLE, TEN_RIDE, or MONTHLY').ToUpperInvariant()
                        $purchase = & $call ticketing /checkout POST @{ tripId=$trip['id']; ticketType=$product; requestKey=[guid]::NewGuid().ToString() }
                        Write-Host ("Amount: NAD {0:N2}. Seat held for ten minutes." -f ($purchase['ticket']['amountMinor']/100))
                        if ((Read-Host 'Confirm simulated payment? (yes/no)') -eq 'yes') {
                            Show-UthData (& $call payment /payments POST @{ ticketId=$purchase['ticket']['id']; requestKey=[guid]::NewGuid().ToString() })
                        }
                    }
                    '2' { Show-UthPages $Context ticketing /bookings $token }
                    '3' { Show-UthPages $Context ticketing /tickets $token }
                    '4' { Show-UthData (& $call ticketing /bookings POST @{ ticketId=Read-Host 'Ticket ID'; tripId=Read-Host 'Trip ID'; requestKey=[guid]::NewGuid().ToString() }) }
                    '5' { Show-UthPages $Context payment /payments $token }
                    '6' { Show-UthPages $Context notification /notifications $token }
                    '7' { Show-UthData (& $call passenger /me) }
                    '8' { $id=ConvertTo-UthSegment (Read-Host 'Booking ID'); Show-UthData (& $call ticketing "/bookings/$id/cancel" POST @{}) }
                    '9' { Show-UthData (& $call payment /refunds POST @{ ticketId=Read-Host 'Ticket ID'; requestKey=[guid]::NewGuid().ToString() }) }
                    '10' { $id=ConvertTo-UthSegment (Read-Host 'Notification ID'); Show-UthData (& $call notification "/notifications/$id/read" POST @{}) }
                    '11' { Show-UthData (& $call passenger /me PUT @{ firstName=Read-Host 'First name'; lastName=Read-Host 'Last name'; phone=Read-Host 'Phone' }) }
                    '12' { & $call passenger /logout POST @{} | Out-Null; $token=''; $user=$null }
                    '13' { $id=ConvertTo-UthSegment (Read-Host 'Notification ID'); Show-UthData (& $call notification "/notifications/$id" DELETE) }
                    '14' {
                        if((Read-Host 'Deactivate your account and remove profile details? Type DELETE') -eq 'DELETE') {
                            & $call passenger /me DELETE | Out-Null; $token=''; $user=$null
                        }
                    }
                }
            } elseif ($user['role'] -in 'ROUTE_OPERATOR','TRANSPORT_MANAGER','SUPER_ADMIN') {
                $choice = Read-UthMenu 'Staff (server enforces your role)' @('Assigned trips','Trip bookings','Validate booking','Routes','Create route','Create trip','Cancel trip','Reports','Create staff account','Change account access','Broadcast announcement','Audit records','Sign out','Edit route','Edit trip','Retire route','Accounts','Pending events','Failed deliveries','Retry failed delivery','My notifications','Mark notification read','Delete notification','Profile')
                switch ($choice) {
                    '0' { return }
                    '1' { Show-UthPages $Context admin /assigned-trips $token }
                    '2' { $id=ConvertTo-UthSegment (Read-Host 'Trip ID'); Show-UthPages $Context ticketing "/bookings?tripId=$id" $token }
                    '3' { $id=ConvertTo-UthSegment (Read-Host 'Booking ID'); Show-UthData (& $call ticketing "/bookings/$id/validate" POST @{}) }
                    '4' { Show-UthPages $Context transport /routes $token }
                    '5' { Show-UthData (& $call transport /routes POST (Read-UthRoute)) }
                    '6' { Show-UthData (& $call transport /trips POST (Read-UthTrip)) }
                    '7' { $id=ConvertTo-UthSegment (Read-Host 'Trip ID'); Show-UthData (& $call transport "/trips/$id/cancel" POST @{}) }
                    '8' { Show-UthData (& $call admin /reports) }
                    '9' { Show-UthData (& $call admin /accounts POST @{
                        email=Read-Host 'Email'; password=Read-UthPassword; firstName=Read-Host 'First name'; lastName=Read-Host 'Last name'; phone=Read-Host 'Phone';
                        role=(Read-Host 'ROUTE_OPERATOR, TRANSPORT_MANAGER, or SUPER_ADMIN').ToUpperInvariant()
                    }) }
                    '10' {
                        $id=ConvertTo-UthSegment (Read-Host 'Account ID')
                        Show-UthData (& $call admin "/accounts/$id" PUT @{ role=(Read-Host 'New role').ToUpperInvariant(); active=((Read-Host 'Active? yes/no') -eq 'yes') })
                    }
                    '11' { Show-UthData (& $call notification /broadcasts POST @{ message=Read-Host 'Announcement (maximum 500 characters)' }) }
                    '12' { Show-UthPages $Context admin /audit $token }
                    '13' { & $call passenger /logout POST @{} | Out-Null; $token=''; $user=$null }
                    '14' { $id=ConvertTo-UthSegment (Read-Host 'Route ID'); Show-UthData (& $call transport "/routes/$id" PUT (Read-UthRoute (& $call transport "/routes/$id"))) }
                    '15' { $id=ConvertTo-UthSegment (Read-Host 'Trip ID'); Show-UthData (& $call transport "/trips/$id" PUT (Read-UthTrip (& $call transport "/trips/$id"))) }
                    '16' { $id=ConvertTo-UthSegment (Read-Host 'Route ID'); Show-UthData (& $call transport "/routes/$id" DELETE) }
                    '17' { Show-UthPages $Context admin /accounts $token }
                    '18' { Show-UthPages $Context admin /events $token }
                    '19' { Show-UthPages $Context admin /delivery-failures $token }
                    '20' { $id=ConvertTo-UthSegment (Read-Host 'Failed delivery ID'); Show-UthData (& $call admin "/delivery-failures/$id/retry" POST @{}) }
                    '21' { Show-UthPages $Context notification /notifications $token }
                    '22' { $id=ConvertTo-UthSegment (Read-Host 'Notification ID'); Show-UthData (& $call notification "/notifications/$id/read" POST @{}) }
                    '23' { $id=ConvertTo-UthSegment (Read-Host 'Notification ID'); Show-UthData (& $call notification "/notifications/$id" DELETE) }
                    '24' { Show-UthData (& $call passenger /me) }
                }
            } else {
                $token=''; $user=$null
                Write-Host 'Unsupported account role. Sign in with a current passenger or staff account.' -ForegroundColor Red
            }
        } catch {
            if ($_.Exception.Data['StatusCode'] -eq 401) { $token=''; $user=$null }
            Write-Host $_.Exception.Message -ForegroundColor Red
        }
    }
}

Export-ModuleMember -Function Start-UthCli
