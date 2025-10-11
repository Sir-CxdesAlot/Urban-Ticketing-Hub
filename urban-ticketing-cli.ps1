#!/usr/bin/env pwsh
[CmdletBinding()]
param()

# =============================================================================
# Urban Ticketing Hub CLI
# =============================================================================

# --- Configuration: API Base URLs ---
$baseUrls = @{
    Passenger  = "http://localhost:8081/api/v1/passenger"
    Transport  = "http://localhost:8082/api/v1/transport"
    Ticketing  = "http://localhost:8083/api/v1/ticketing"
    Payment    = "http://localhost:8084/api/v1/payment"
    Notification = "http://localhost:8085/api/v1/notification"
    Admin      = "http://localhost:8086/api/v1/admin"
}

# --- State Management: The magic token keepers ---
$script:passengerToken = $null
$script:adminToken = $null

#region Helper Functions

function Write-Header {
    param([string]$Title)
    Write-Host "`n" -NoNewline
    Write-Host ('=' * 60) -ForegroundColor Cyan
    Write-Host " $Title" -ForegroundColor Yellow
    Write-Host ('=' * 60) -ForegroundColor Cyan
}

function Invoke-ApiRequest {
    param(
        [string]$Method,
        [string]$Uri,
        [object]$Body,
        [string]$Token
    )
    # If this is an Admin endpoint, use curl.exe for parity with tests and better diagnostics
    try {
        if ($Uri -like "$($baseUrls.Admin)*") {
            $curlArgs = @('-s', '-X', $Method, $Uri)
            if (-not [string]::IsNullOrEmpty($Token)) { $curlArgs += @('-H', "Authorization: Bearer $([string]$Token)") }
            if ($null -ne $Body) { $curlArgs += @('-H', 'Content-Type: application/json', '-d', (if ($Body -is [string]) { $Body } else { $Body | ConvertTo-Json -Depth 5 })) }
            try {
                $curlOut = & curl.exe @curlArgs
            } catch {
                Write-Host "❌ Curl invocation failed for Admin endpoint: $($_.Exception.Message)" -ForegroundColor Red
                return $null
            }
            if ($NULL -eq $curlOut -or $curlOut -eq '') { return $null }
            try { return ($curlOut | ConvertFrom-Json) } catch { Write-Host "Non-JSON curl response (Admin):" -ForegroundColor Yellow; Write-Host $curlOut -ForegroundColor DarkYellow; return $curlOut }
        }
    } catch {}
    # Only add Content-Type header when we have a body (some servers mishandle Content-Type on GET requests)
    $headers = @{}
    if (-not [string]::IsNullOrEmpty($Token)) {
        $headers['Authorization'] = "Bearer $Token"
    }

    if ($null -ne $Body) {
        $headers['Content-Type'] = 'application/json'
    }

    $invokeParams = @{
        Method  = $Method
        Uri     = $Uri
        Headers = $headers
        ErrorAction = 'Stop' # throw so we can inspect the response
    }

    if ($null -ne $Body) {
        $invokeParams.Body = ($Body | ConvertTo-Json -Depth 5 -Compress)
    }

    try {
        $response = Invoke-RestMethod @invokeParams
        return $response
    }
    catch {
        # Check for specific WebException (HTTP error)
        if ($_.Exception.Response) {
            $respObj = $_.Exception.Response
            $status = $null
            $responseBody = $null
            try {
                if ($respObj -is [System.Net.Http.HttpResponseMessage]) {
                    $status = $respObj.StatusCode.ToString()
                    $responseBody = $respObj.Content.ReadAsStringAsync().Result
                }
                elseif ($respObj -is [System.Net.WebResponse]) {
                    $status = $respObj.StatusCode
                    $stream = $respObj.GetResponseStream()
                    if ($stream) { $reader = New-Object System.IO.StreamReader($stream); $responseBody = $reader.ReadToEnd(); $reader.Close() }
                }
            } catch {
                # ignore secondary read errors
            }

            if (-not $status) { $status = $_.Exception.HResult }
            Write-Host "❌ API Error ($status): $($_.Exception.Message)" -ForegroundColor Red
            # Attempt to parse and display more detailed message from JSON body
            try {
                if ($responseBody) {
                    $errorDetails = $responseBody | ConvertFrom-Json
                    if ($errorDetails.message) { Write-Host "   Detail: $($errorDetails.message)" -ForegroundColor DarkRed }
                    else { Write-Host "   Response Body: $responseBody" -ForegroundColor DarkRed }
                }
            } catch {
                if ($responseBody) { Write-Host "   Response Body: $responseBody" -ForegroundColor DarkRed }
            }
        } else {
            # Non-HTTP/Network Error
            Write-Host "❌ Network or Scripting Error: $($_.Exception.Message)" -ForegroundColor Red
        }
        return $null
    }
}

function Select-ItemFromApi {
    param(
        [string]$Uri,
        [string]$Prompt,
        [string]$IdProperty,
        [string]$DisplayProperties
    )

    $items = Invoke-ApiRequest -Method GET -Uri $Uri -Token $null # Transport data is public
    
    if (-not $items -or $items.Count -eq 0) {
        Write-Host "❌ No $($Prompt)s found at the moment. Try again later." -ForegroundColor Red
        return $null
    }

    Write-Host "--- Available $($Prompt)s ---" -ForegroundColor Yellow
    
    # FIX APPLIED HERE: Use the idiomatic -isnot operator to check if $items is not an array.
    if ($items -isnot [array]) { $items = @($items) }

    # Create an indexed list for selection
    $selectionList = @()
    for ($i = 0; $i -lt $items.Count; $i++) {
        $item = $items[$i]
        $item | Add-Member -MemberType NoteProperty -Name 'No' -Value ($i + 1) -Force
        $selectionList += $item
    }

    # Display the items. Capture the formatted table as text and write it to host so we don't emit
    # formatting objects into the pipeline (which show up later when an object is stringified).
    $table = $selectionList | Select-Object -Property (@('No') + ($DisplayProperties -split ',')) | Format-Table -AutoSize | Out-String
    Write-Host $table
    
    $maxChoice = $selectionList.Count
    while ($true) {
        $choice = Read-Host "Select a $($Prompt) number (1-$maxChoice) or 0 to Cancel"
        if ($choice -eq '0') { 
            Write-Host "Selection cancelled, mate." -ForegroundColor DarkYellow
            return $null 
        }
        
        # Simple input validation
        if ([int]::TryParse($choice, [ref]$null) -and $choice -ge 1 -and $choice -le $maxChoice) {
            $selectedIndex = [int]$choice - 1
            $selectedItem = $selectionList[$selectedIndex]
            # Try to extract the requested id property; if missing, try common fallbacks
            $selectedId = $null
            if ($selectedItem.PSObject.Properties.Name -contains $IdProperty) { $selectedId = $selectedItem.($IdProperty) }
            if (-not $selectedId) { if ($selectedItem.PSObject.Properties.Name -contains '_id') { $selectedId = $selectedItem._id } }
            if (-not $selectedId) { if ($selectedItem.PSObject.Properties.Name -contains 'id') { $selectedId = $selectedItem.id } }

            # Convert complex selection to a readable label for display
            $displayLabel = $null
            if ($selectedItem.PSObject.Properties.Name -contains 'name') { $displayLabel = $selectedItem.name } elseif ($selectedItem.PSObject.Properties.Name -contains 'title') { $displayLabel = $selectedItem.title } else { $displayLabel = $selectedId }

            Write-Host "✅ You picked: $displayLabel (ID: $selectedId)" -ForegroundColor Green
            return [string]$selectedId
        }
        Write-Host "Invalid selection. Try again." -ForegroundColor Red
    }
}

#endregion Helper Functions

function Is-ValidId {
    param([string]$Id)
    if (-not $Id) { return $false }
    # MongoDB ObjectId: 24 hex chars
    if ($Id -match '^[0-9a-fA-F]{24}$') { return $true }
    # UUID: 8-4-4-4-12 with hyphens
    if ($Id -match '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$') { return $true }
    # Simple check for the 'default' IDs used in init script
    if ($Id -match '^(trip|route)-default$') { return $true }
    return $false
}

#region Main Menus

function Show-MainMenu {
    Clear-Host
    Write-Header "Urban Ticketing Hub CLI"
    Write-Host "1. Passenger View"
    Write-Host "2. Admin View"
    Write-Host "0. Exit"
    Write-Host ""
}

function Show-PassengerMenu {
    Clear-Host
    Write-Header "Passenger View"
    Write-Host "1. Register"
    Write-Host "2. Login"
    Write-Host "3. View Profile"
    Write-Host "4. Buy Ticket"
    Write-Host "5. View My Tickets"
    Write-Host "0. Back"
    Write-Host ""
}

function Show-AdminMenu {
    Clear-Host
    Write-Header "Admin View"
    Write-Host "1. Login"
    Write-Host "2. List Admin Users"
    Write-Host "3. List Disruptions"
    Write-Host "4. Create Disruption"
    Write-Host "5. View Dashboard"
    Write-Host "0. Back"
    Write-Host ""
}

#endregion Main Menus

#region Passenger Functions

function Register-Passenger {
    Write-Header "Passenger Registration"
    $body = @{
        email     = Read-Host "Enter email"
        password  = Read-Host "Enter password" -AsSecureString | ForEach-Object { [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($_)) }
        firstName = Read-Host "Enter first name"
        lastName  = Read-Host "Enter last name"
        phone     = Read-Host "Enter phone number"
    }
    $result = Invoke-ApiRequest -Method POST -Uri "$($baseUrls.Passenger)/register" -Body $body
    if ($result) {
        Write-Host "✅ Registration successful for $($result.email)!" -ForegroundColor Green
    }
}

function Login-Passenger {
    Write-Header "Passenger Login"
    $email = Read-Host "Enter email"
    $password = Read-Host "Enter password" -AsSecureString | ForEach-Object { [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($_)) }
    $body = @{ email = $email; password = $password }
    
    $result = Invoke-ApiRequest -Method POST -Uri "$($baseUrls.Passenger)/login" -Body $body
    
    # Fix: Check for common token locations, the init script implies the token is on the top level or within 'data'
    $token = $null
    if ($result) {
        if ($result.token) {
            $token = $result.token
        } elseif ($result.data -and $result.data.token) {
            $token = $result.data.token
        }
    }
    
    if ($token) {
        $script:passengerToken = $token
        # Try to get first name from nested user object if available
        $firstName = if ($result.user -and $result.user.firstName) { $result.user.firstName } else { "mate" }
        Write-Host "✅ Login successful! Welcome $firstName." -ForegroundColor Green
    } else {
        Write-Host "❌ Login failed. Please check your credentials." -ForegroundColor Red
    }
}

function View-PassengerProfile {
    if (-not $script:passengerToken) { Write-Host "❌ Please log in first." -ForegroundColor Red; return }
    Write-Header "Your Profile"
    $result = Invoke-ApiRequest -Method GET -Uri "$($baseUrls.Passenger)/profile" -Token $script:passengerToken
    if ($result) {
        $result | Format-List
    }
}

function Buy-PassengerTicket {
    if (-not $script:passengerToken) {
        $doLogin = Read-Host "You're not logged in. Log in now? (Y/n)"
        if ($doLogin -eq '' -or $doLogin.ToLower() -eq 'y') {
            Login-Passenger
            if (-not $script:passengerToken) { Write-Host "Login failed or cancelled." -ForegroundColor Red; return }
        } else { Write-Host "Purchase cancelled - login required." -ForegroundColor DarkYellow; return }
    }
    Write-Header "Buy a New Ticket"

    # 1. Select Route
    $routeId = Select-ItemFromApi `
        -Uri "$($baseUrls.Transport)/routes" `
        -Prompt "Route" `
        -IdProperty "id" `
        -DisplayProperties "name,startLocation,endLocation" 
    
    if (-not $routeId) { return } # Purchase cancelled

    # 2. Select Trip - Filtered by the chosen route
    $tripId = Select-ItemFromApi `
        -Uri "$($baseUrls.Transport)/trips?routeId=$routeId" `
        -Prompt "Trip" `
        -IdProperty "id" `
        -DisplayProperties "departureTime,arrivalTime,availableSeats" 
    
    if (-not $tripId) { return } # Purchase cancelled

    # Validate IDs before attempting purchase
    if (-not (Is-ValidId -Id $routeId)) { Write-Host "❌ Selected route ID looks invalid: $routeId" -ForegroundColor Red; return }
    # Relaxed trip ID validation, as the init script used a default string for tickets
    if (-not (Is-ValidId -Id $tripId) -and $tripId -ne 'trip-default') { Write-Host "❌ Selected trip ID looks dodgy: $tripId" -ForegroundColor Red; return }

    # 3. Select Ticket Type (normalize and validate)
    $ticketType = Read-Host "Enter Ticket Type (e.g., SINGLE, RETURN, MONTHLY_PASS)"
    $ticketTypeNorm = $ticketType.ToUpper()
    # Updated validation to reflect types in data-init.ps1
    if ($ticketTypeNorm -ne 'SINGLE' -and $ticketTypeNorm -ne 'RETURN' -and $ticketTypeNorm -ne 'MONTHLY_PASS') {
        Write-Host "❌ Invalid ticket type. Please enter SINGLE, RETURN, or MONTHLY_PASS." -ForegroundColor Red
        return
    }

    $body = @{ 
        routeId = $routeId
        tripId = $tripId # Add tripId to the body
        ticketType = $ticketTypeNorm 
    }

    # If MULTIPLE, ask for quantity - The init script doesn't use MULTIPLE, but the CLI code did.
    # Sticking to the init script types for robustness
    if ($ticketTypeNorm -eq 'RETURN') {
        Write-Host "Note: Purchasing a RETURN ticket." -ForegroundColor DarkYellow
    } elseif ($ticketTypeNorm -eq 'MONTHLY_PASS') {
         Write-Host "Note: Purchasing a MONTHLY_PASS." -ForegroundColor DarkYellow
    }
    
    # You might need to adjust the body payload if the ticket microservice expects other fields like 'quantity'
    # or requires the `tripId` to be passed to the *passenger* ticket buying endpoint.
    
    Write-Host "Attempting to buy a $($ticketTypeNorm) ticket..." -ForegroundColor Cyan
    # Note: The original code didn't use tripId in the body, but it was selected. Added it.
    $result = Invoke-ApiRequest -Method POST -Uri "$($baseUrls.Passenger)/tickets" -Body $body -Token $script:passengerToken
    if ($result) {
        Write-Host "✅ Ticket purchase initiated successfully! Result below." -ForegroundColor Green
        $result | Format-List
    }
}

function View-PassengerTickets {
    if (-not $script:passengerToken) {
        $doLogin = Read-Host "You're not logged in. Log in now? (Y/n)"
        if ($doLogin -eq '' -or $doLogin.ToLower() -eq 'y') {
            Login-Passenger
            if (-not $script:passengerToken) { Write-Host "Login failed or cancelled." -ForegroundColor Red; return }
        } else { Write-Host "Operation cancelled - login required." -ForegroundColor DarkYellow; return }
    }
    Write-Header "My Tickets"
    $result = Invoke-ApiRequest -Method GET -Uri "$($baseUrls.Passenger)/tickets" -Token $script:passengerToken
    if ($result) {
        # Fix: Ensure $result is an array for reliable counting and formatting
        $tickets = if ($result -is [array]) { $result } else { @($result) }
        
        if ($tickets.Count -gt 0) {
            $tickets | Format-Table
        } else {
            Write-Host "You don't have any tickets, mate. Time to buy one!" -ForegroundColor Yellow
        }
    }
}

#endregion Passenger Functions

#region Admin Functions

function Login-Admin {
    Write-Header "Admin Login"
    # Convenience: allow using known test credentials for local testing
    $useTest = Read-Host "Use test credentials? (y/N)"
    if ($useTest -and $useTest.ToLower().StartsWith('y')) {
        $username = 'admin'
        $password = 'Admin123!'
        Write-Host "Using test credentials (username: admin)" -ForegroundColor Yellow
    } else {
        $username = Read-Host "Enter username"
        $password = Read-Host "Enter password" -AsSecureString | ForEach-Object { [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($_)) }
    }
    $body = @{ username = $username; password = $password }
    
    $result = Invoke-ApiRequest -Method POST -Uri "$($baseUrls.Admin)/login" -Body $body
    
    # Fix: Check for common token locations, especially if the API uses a nested structure
    $token = $null
    if ($result) {
        if ($result.token) {
            $token = $result.token
        } elseif ($result.data -and $result.data.token) {
            $token = $result.data.token
        } elseif ($result.accessToken) { # Sometimes it's called accessToken
            $token = $result.accessToken
        }
    }
    
    if ($token) {
        $script:adminToken = $token
        Write-Host "✅ Admin login successful! Welcome, you've got the keys now." -ForegroundColor Green
    } else {
        # Some Admin endpoints return success + admin info but no token. Treat that as a successful login for local/test setups.
        if ($result -and ($result.success -eq $true -or $result.adminId -or $result.username)) {
            # Prefer storing adminId if available so subsequent admin calls can identify the session if needed
            if ($result.adminId) { $script:adminToken = $result.adminId } else { $script:adminToken = 'LOCAL_AUTH_NO_TOKEN' }
            Write-Host "✅ Admin login successful (no token returned). Stored admin identifier for session." -ForegroundColor Green
            Write-Host "--- Raw parsed response from API (for debugging) ---" -ForegroundColor Yellow
            Write-Host ($result | ConvertTo-Json -Depth 5) -ForegroundColor DarkYellow
        } else {
            Write-Host "❌ Admin login failed. The server wheezed like a cheap kettle trying to process that." -ForegroundColor Red
            # Diagnostic: print raw result if present
            if ($result) {
                Write-Host "--- Raw parsed response from API (for debugging) ---" -ForegroundColor Yellow
                Write-Host ($result | ConvertTo-Json -Depth 5) -ForegroundColor DarkYellow
            } else {
                Write-Host "--- No parsed response; check raw curl output below (if any) ---" -ForegroundColor Yellow
            }
        }
    }
}

function List-AdminUsers {
    if (-not $script:adminToken) { Write-Host "❌ Please log in first." -ForegroundColor Red; return }
    Write-Header "Admin Users"
    $result = Invoke-ApiRequest -Method GET -Uri "$($baseUrls.Admin)/admin-users" -Token $script:adminToken
    if ($result) {
        # Ensure $result is an array before piping to Format-Table
        $users = if ($result -is [array]) { $result } else { @($result) }
        $users | Format-Table
    }
}

function List-Disruptions {
    if (-not $script:adminToken) { Write-Host "❌ Please log in first." -ForegroundColor Red; return }
    Write-Header "Service Disruptions"
    $result = Invoke-ApiRequest -Method GET -Uri "$($baseUrls.Admin)/disruptions" -Token $script:adminToken
    if ($result) {
        # Ensure $result is an array
        $disruptions = if ($result -is [array]) { $result } else { @($result) }
        $disruptions | Format-Table
    }
}

function Create-Disruption {
    if (-not $script:adminToken) { Write-Host "❌ Please log in first." -ForegroundColor Red; return }
    Write-Header "Create New Service Disruption"
    
    # Try to select a route ID if routes are available, otherwise use a placeholder
    $defaultRouteId = "route-default"
    $routeId = Select-ItemFromApi `
        -Uri "$($baseUrls.Transport)/routes" `
        -Prompt "Route for Disruption" `
        -IdProperty "id" `
        -DisplayProperties "name,startLocation,endLocation" 
    
    if (-not $routeId) { 
        Write-Host "⚠️ No specific route selected. Using default ID: $defaultRouteId" -ForegroundColor Yellow
        $routeId = $defaultRouteId
    }
    
    $typeInput = Read-Host "Enter Disruption Type (e.g., DELAY, CANCELLATION)"
    $typeNorm = $typeInput.ToUpper()
    
    $body = @{
        routeId     = $routeId
        type        = $typeNorm
        title       = Read-Host "Enter Title"
        description = Read-Host "Enter Description"
        startTime   = (Get-Date).ToUniversalTime().ToString("o") # Default to now
        endTime     = (Get-Date).AddHours(2).ToUniversalTime().ToString("o") # Default 2 hours later
    }
    Write-Host "Using default start/end times. Start: $($body.startTime), End: $($body.endTime)"
    
    $result = Invoke-ApiRequest -Method POST -Uri "$($baseUrls.Admin)/disruptions" -Body $body -Token $script:adminToken
    if ($result) {
        Write-Host "✅ Disruption created successfully!" -ForegroundColor Green
        $result | Format-List
    }
}

function View-Dashboard {
    if (-not $script:adminToken) { Write-Host "❌ Please log in first." -ForegroundColor Red; return }
    Write-Header "Admin Dashboard"
    $result = Invoke-ApiRequest -Method GET -Uri "$($baseUrls.Admin)/dashboard" -Token $script:adminToken
    if ($result) {
        # Using ConvertTo-Json here as dashboard data might be complex
        $result | ConvertTo-Json -Depth 5 | Write-Host
    }
}

#endregion Admin Functions

#region Main Logic Loops

function Show-PassengerView {
    while ($true) {
        Show-PassengerMenu
        $choice = Read-Host "Select an option"
        switch ($choice) {
            '1' { Register-Passenger }
            '2' { Login-Passenger }
            '3' { View-PassengerProfile }
            '4' { Buy-PassengerTicket }
            '5' { View-PassengerTickets }
            '0' { break }
            default { Write-Host "Invalid option. Try again, will ya?" -ForegroundColor Red }
        }
        Read-Host "Press Enter to continue..."
    }
}

function Show-AdminView {
    while ($true) {
        Show-AdminMenu
        $choice = Read-Host "Select an option"
        switch ($choice) {
            '1' { Login-Admin }
            '2' { List-AdminUsers }
            '3' { List-Disruptions }
            '4' { Create-Disruption }
            '5' { View-Dashboard }
            '0' { break }
            default { Write-Host "Invalid option. Give it another go." -ForegroundColor Red }
        }
        Read-Host "Press Enter to continue..."
    }
}

# --- Main Program Loop ---
while ($true) {
    Show-MainMenu
    $mainChoice = Read-Host "Select a view"
    switch ($mainChoice) {
        '1' { Show-PassengerView }
        '2' { Show-AdminView }
        '0' { Write-Host "Exiting... Cheers!" -ForegroundColor Green; break }
        default { 
            Write-Host "Invalid option. But, you know, it's kinda hard to get the right number..." -ForegroundColor Red 
            Read-Host "Press Enter to continue..."
        }
    }
}

function Write-Header {
    param([string]$Title)
    Write-Host "`n" -NoNewline
    Write-Host ('=' * 60) -ForegroundColor Cyan
    Write-Host " $Title" -ForegroundColor Yellow
    Write-Host ('=' * 60) -ForegroundColor Cyan
}

function Invoke-ApiRequest {
    param(
        [string]$Method,
        [string]$Uri,
        [object]$Body,
        [string]$Token
    )
    $headers = @{ "Content-Type" = "application/json" }
    if (-not [string]::IsNullOrEmpty($Token)) {
        $headers.Add("Authorization", "Bearer $Token")
    }

    $invokeParams = @{
        Method  = $Method
        Uri     = $Uri
        Headers = $headers
        ErrorAction = 'Stop' # Changed from SilentlyContinue to Stop for better error catch
        ContentType = 'application/json' # Explicitly set content type
    }

    if ($null -ne $Body) {
        $invokeParams.Body = ($Body | ConvertTo-Json -Depth 5 -Compress) # Added -Compress
    }

    try {
        $response = Invoke-RestMethod @invokeParams
        return $response
    }
    catch {
        # Check for specific WebException (HTTP error)
        if ($_.Exception.Response) {
            $status = $_.Exception.Response.StatusCode
            $errorContent = $_.Exception.Response.GetResponseStream()
            $reader = New-Object System.IO.StreamReader($errorContent)
            $responseBody = $reader.ReadToEnd()
            
            Write-Host "❌ API Error ($status): $($_.Exception.Message)" -ForegroundColor Red
            # Attempt to parse and display more detailed message from JSON body
            try {
                $errorDetails = $responseBody | ConvertFrom-Json
                if ($errorDetails.message) {
                    Write-Host "   Detail: $($errorDetails.message)" -ForegroundColor DarkRed
                }
            }
            catch {
                Write-Host "   Response Body: $responseBody" -ForegroundColor DarkRed
            }
        } else {
            # Non-HTTP/Network Error
            Write-Host "❌ Network or Scripting Error: $($_.Exception.Message)" -ForegroundColor Red
        }
        return $null
    }
}

function Select-ItemFromApi {
    param(
        [string]$Uri,
        [string]$Prompt,
        [string]$IdProperty,
        [string]$DisplayProperties
    )

    $items = Invoke-ApiRequest -Method GET -Uri $Uri -Token $null # Transport data is public
    
    if (-not $items -or $items.Count -eq 0) {
        Write-Host "❌ No $($Prompt)s found at the moment. Try again later." -ForegroundColor Red
        return $null
    }

    Write-Host "--- Available $($Prompt)s ---" -ForegroundColor Yellow
    
    # FIX APPLIED HERE: Use the idiomatic -isnot operator to check if $items is not an array.
    if ($items -isnot [array]) { $items = @($items) }

    # Create an indexed list for selection
    $selectionList = @()
    for ($i = 0; $i -lt $items.Count; $i++) {
        $item = $items[$i]
        $item | Add-Member -MemberType NoteProperty -Name 'No' -Value ($i + 1) -Force
        $selectionList += $item
    }

    # Display the items. Capture the formatted table as text and write it to host so we don't emit
    # formatting objects into the pipeline (which show up later when an object is stringified).
    $table = $selectionList | Select-Object -Property (@('No') + ($DisplayProperties -split ',')) | Format-Table -AutoSize | Out-String
    Write-Host $table
    
    $maxChoice = $selectionList.Count
    while ($true) {
        $choice = Read-Host "Select a $($Prompt) number (1-$maxChoice) or 0 to Cancel"
        if ($choice -eq '0') { 
            Write-Host "Selection cancelled, mate." -ForegroundColor DarkYellow
            return $null 
        }
        
        # Simple input validation
        if ([int]::TryParse($choice, [ref]$null) -and $choice -ge 1 -and $choice -le $maxChoice) {
            $selectedIndex = [int]$choice - 1
            $selectedItem = $selectionList[$selectedIndex]
            # Try to extract the requested id property; if missing, try common fallbacks
            $selectedId = $null
            if ($selectedItem.PSObject.Properties.Name -contains $IdProperty) { $selectedId = $selectedItem.($IdProperty) }
            if (-not $selectedId) { if ($selectedItem.PSObject.Properties.Name -contains '_id') { $selectedId = $selectedItem._id } }
            if (-not $selectedId) { if ($selectedItem.PSObject.Properties.Name -contains 'id') { $selectedId = $selectedItem.id } }

            # Convert complex selection to a readable label for display
            $displayLabel = $null
            if ($selectedItem.PSObject.Properties.Name -contains 'name') { $displayLabel = $selectedItem.name } elseif ($selectedItem.PSObject.Properties.Name -contains 'title') { $displayLabel = $selectedItem.title } else { $displayLabel = $selectedId }

            Write-Host "✅ You picked: $displayLabel (ID: $selectedId)" -ForegroundColor Green
            return [string]$selectedId
        }
        Write-Host "Invalid selection. Try again." -ForegroundColor Red
    }
}

#endregion Helper Functions

function Is-ValidId {
    param([string]$Id)
    if (-not $Id) { return $false }
    # MongoDB ObjectId: 24 hex chars
    if ($Id -match '^[0-9a-fA-F]{24}$') { return $true }
    # UUID: 8-4-4-4-12 with hyphens
    if ($Id -match '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$') { return $true }
    # Simple check for the 'default' IDs used in init script
    if ($Id -match '^(trip|route)-default$') { return $true }
    return $false
}

#region Main Menus

function Show-MainMenu {
    Clear-Host
    Write-Header "Urban Ticketing Hub CLI"
    Write-Host "1. Passenger View"
    Write-Host "2. Admin View"
    Write-Host "0. Exit"
    Write-Host ""
}

function Show-PassengerMenu {
    Clear-Host
    Write-Header "Passenger View"
    Write-Host "1. Register"
    Write-Host "2. Login"
    Write-Host "3. View Profile"
    Write-Host "4. Buy Ticket"
    Write-Host "5. View My Tickets"
    Write-Host "0. Back"
    Write-Host ""
}

function Show-AdminMenu {
    Clear-Host
    Write-Header "Admin View"
    Write-Host "1. Login"
    Write-Host "2. List Admin Users"
    Write-Host "3. List Disruptions"
    Write-Host "4. Create Disruption"
    Write-Host "5. View Dashboard"
    Write-Host "0. Back"
    Write-Host ""
}

#endregion Main Menus

#region Passenger Functions

function Register-Passenger {
    Write-Header "Passenger Registration"
    $body = @{
        email     = Read-Host "Enter email"
        password  = Read-Host "Enter password" -AsSecureString | ForEach-Object { [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($_)) }
        firstName = Read-Host "Enter first name"
        lastName  = Read-Host "Enter last name"
        phone     = Read-Host "Enter phone number"
    }
    $result = Invoke-ApiRequest -Method POST -Uri "$($baseUrls.Passenger)/register" -Body $body
    if ($result) {
        Write-Host "✅ Registration successful for $($result.email)!" -ForegroundColor Green
    }
}

function Login-Passenger {
    Write-Header "Passenger Login"
    $email = Read-Host "Enter email"
    $password = Read-Host "Enter password" -AsSecureString | ForEach-Object { [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($_)) }
    $body = @{ email = $email; password = $password }
    
    $result = Invoke-ApiRequest -Method POST -Uri "$($baseUrls.Passenger)/login" -Body $body
    
    # Fix: Check for common token locations, the init script implies the token is on the top level or within 'data'
    $token = $null
    if ($result) {
        if ($result.token) {
            $token = $result.token
        } elseif ($result.data -and $result.data.token) {
            $token = $result.data.token
        }
    }
    
    if ($token) {
        $script:passengerToken = $token
        # Try to get first name from nested user object if available
        $firstName = if ($result.user -and $result.user.firstName) { $result.user.firstName } else { "mate" }
        Write-Host "✅ Login successful! Welcome $firstName." -ForegroundColor Green
    } else {
        Write-Host "❌ Login failed. Please check your credentials." -ForegroundColor Red
    }
}

function View-PassengerProfile {
    if (-not $script:passengerToken) { Write-Host "❌ Please log in first." -ForegroundColor Red; return }
    Write-Header "Your Profile"
    $result = Invoke-ApiRequest -Method GET -Uri "$($baseUrls.Passenger)/profile" -Token $script:passengerToken
    if ($result) {
        $result | Format-List
    }
}

function Buy-PassengerTicket {
    if (-not $script:passengerToken) {
        $doLogin = Read-Host "You're not logged in. Log in now? (Y/n)"
        if ($doLogin -eq '' -or $doLogin.ToLower() -eq 'y') {
            Login-Passenger
            if (-not $script:passengerToken) { Write-Host "Login failed or cancelled." -ForegroundColor Red; return }
        } else { Write-Host "Purchase cancelled - login required." -ForegroundColor DarkYellow; return }
    }
    Write-Header "Buy a New Ticket"

    # 1. Select Route
    $routeId = Select-ItemFromApi `
        -Uri "$($baseUrls.Transport)/routes" `
        -Prompt "Route" `
        -IdProperty "id" `
        -DisplayProperties "name,startLocation,endLocation" 
    
    if (-not $routeId) { return } # Purchase cancelled

    # 2. Select Trip - Filtered by the chosen route
    $tripId = Select-ItemFromApi `
        -Uri "$($baseUrls.Transport)/trips?routeId=$routeId" `
        -Prompt "Trip" `
        -IdProperty "id" `
        -DisplayProperties "departureTime,arrivalTime,availableSeats" 
    
    if (-not $tripId) { return } # Purchase cancelled

    # Validate IDs before attempting purchase
    if (-not (Is-ValidId -Id $routeId)) { Write-Host "❌ Selected route ID looks invalid: $routeId" -ForegroundColor Red; return }
    # Relaxed trip ID validation, as the init script used a default string for tickets
    if (-not (Is-ValidId -Id $tripId) -and $tripId -ne 'trip-default') { Write-Host "❌ Selected trip ID looks dodgy: $tripId" -ForegroundColor Red; return }

    # 3. Select Ticket Type (normalize and validate)
    $ticketType = Read-Host "Enter Ticket Type (e.g., SINGLE, RETURN, MONTHLY_PASS)"
    $ticketTypeNorm = $ticketType.ToUpper()
    # Updated validation to reflect types in data-init.ps1
    if ($ticketTypeNorm -ne 'SINGLE' -and $ticketTypeNorm -ne 'RETURN' -and $ticketTypeNorm -ne 'MONTHLY_PASS') {
        Write-Host "❌ Invalid ticket type. Please enter SINGLE, RETURN, or MONTHLY_PASS." -ForegroundColor Red
        return
    }

    $body = @{ 
        routeId = $routeId
        tripId = $tripId # Add tripId to the body
        ticketType = $ticketTypeNorm 
    }

    # If MULTIPLE, ask for quantity - The init script doesn't use MULTIPLE, but the CLI code did.
    # Sticking to the init script types for robustness
    if ($ticketTypeNorm -eq 'RETURN') {
        Write-Host "Note: Purchasing a RETURN ticket." -ForegroundColor DarkYellow
    } elseif ($ticketTypeNorm -eq 'MONTHLY_PASS') {
         Write-Host "Note: Purchasing a MONTHLY_PASS." -ForegroundColor DarkYellow
    }
    
    # You might need to adjust the body payload if the ticket microservice expects other fields like 'quantity'
    # or requires the `tripId` to be passed to the *passenger* ticket buying endpoint.
    
    Write-Host "Attempting to buy a $($ticketTypeNorm) ticket..." -ForegroundColor Cyan
    # Note: The original code didn't use tripId in the body, but it was selected. Added it.
    $result = Invoke-ApiRequest -Method POST -Uri "$($baseUrls.Passenger)/tickets" -Body $body -Token $script:passengerToken
    if ($result) {
        Write-Host "✅ Ticket purchase initiated successfully! Result below." -ForegroundColor Green
        $result | Format-List
    }
}

function View-PassengerTickets {
    if (-not $script:passengerToken) {
        $doLogin = Read-Host "You're not logged in. Log in now? (Y/n)"
        if ($doLogin -eq '' -or $doLogin.ToLower() -eq 'y') {
            Login-Passenger
            if (-not $script:passengerToken) { Write-Host "Login failed or cancelled." -ForegroundColor Red; return }
        } else { Write-Host "Operation cancelled - login required." -ForegroundColor DarkYellow; return }
    }
    Write-Header "My Tickets"
    $result = Invoke-ApiRequest -Method GET -Uri "$($baseUrls.Passenger)/tickets" -Token $script:passengerToken
    if ($result) {
        # Fix: Ensure $result is an array for reliable counting and formatting
        $tickets = if ($result -is [array]) { $result } else { @($result) }
        
        if ($tickets.Count -gt 0) {
            $tickets | Format-Table
        } else {
            Write-Host "You don't have any tickets, mate. Time to buy one!" -ForegroundColor Yellow
        }
    }
}

#endregion Passenger Functions

#region Admin Functions

function Login-Admin {
    Write-Header "Admin Login"
    $username = Read-Host "Enter username"
    $password = Read-Host "Enter password" -AsSecureString | ForEach-Object { [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($_)) }
    $body = @{ username = $username; password = $password }
    
    $result = Invoke-ApiRequest -Method POST -Uri "$($baseUrls.Admin)/login" -Body $body
    
    # Fix: Check for common token locations, especially if the API uses a nested structure
    $token = $null
    if ($result) {
        if ($result.token) {
            $token = $result.token
        } elseif ($result.data -and $result.data.token) {
            $token = $result.data.token
        } elseif ($result.accessToken) { # Sometimes it's called accessToken
            $token = $result.accessToken
        }
    }
    
    if ($token) {
        $script:adminToken = $token
        Write-Host "✅ Admin login successful! Welcome, you've got the keys now." -ForegroundColor Green
    } else {
        Write-Host "❌ Admin login failed. The server wheezed like a cheap kettle trying to process that." -ForegroundColor Red
    }
}

function List-AdminUsers {
    if (-not $script:adminToken) { Write-Host "❌ Please log in first." -ForegroundColor Red; return }
    Write-Header "Admin Users"
    $result = Invoke-ApiRequest -Method GET -Uri "$($baseUrls.Admin)/admin-users" -Token $script:adminToken
    if ($result) {
        # Ensure $result is an array before piping to Format-Table
        $users = if ($result -is [array]) { $result } else { @($result) }
        $users | Format-Table
    }
}

function List-Disruptions {
    if (-not $script:adminToken) { Write-Host "❌ Please log in first." -ForegroundColor Red; return }
    Write-Header "Service Disruptions"
    $result = Invoke-ApiRequest -Method GET -Uri "$($baseUrls.Admin)/disruptions" -Token $script:adminToken
    if ($result) {
        # Ensure $result is an array
        $disruptions = if ($result -is [array]) { $result } else { @($result) }
        $disruptions | Format-Table
    }
}

function Create-Disruption {
    if (-not $script:adminToken) { Write-Host "❌ Please log in first." -ForegroundColor Red; return }
    Write-Header "Create New Service Disruption"
    
    # Try to select a route ID if routes are available, otherwise use a placeholder
    $defaultRouteId = "route-default"
    $routeId = Select-ItemFromApi `
        -Uri "$($baseUrls.Transport)/routes" `
        -Prompt "Route for Disruption" `
        -IdProperty "id" `
        -DisplayProperties "name,startLocation,endLocation" 
    
    if (-not $routeId) { 
        Write-Host "⚠️ No specific route selected. Using default ID: $defaultRouteId" -ForegroundColor Yellow
        $routeId = $defaultRouteId
    }
    
    $typeInput = Read-Host "Enter Disruption Type (e.g., DELAY, CANCELLATION)"
    $typeNorm = $typeInput.ToUpper()
    
    $body = @{
        routeId     = $routeId
        type        = $typeNorm
        title       = Read-Host "Enter Title"
        description = Read-Host "Enter Description"
        startTime   = (Get-Date).ToUniversalTime().ToString("o") # Default to now
        endTime     = (Get-Date).AddHours(2).ToUniversalTime().ToString("o") # Default 2 hours later
    }
    Write-Host "Using default start/end times. Start: $($body.startTime), End: $($body.endTime)"
    
    $result = Invoke-ApiRequest -Method POST -Uri "$($baseUrls.Admin)/disruptions" -Body $body -Token $script:adminToken
    if ($result) {
        Write-Host "✅ Disruption created successfully!" -ForegroundColor Green
        $result | Format-List
    }
}

function View-Dashboard {
    if (-not $script:adminToken) { Write-Host "❌ Please log in first." -ForegroundColor Red; return }
    Write-Header "Admin Dashboard"
    $result = Invoke-ApiRequest -Method GET -Uri "$($baseUrls.Admin)/dashboard" -Token $script:adminToken
    if ($result) {
        # Using ConvertTo-Json here as dashboard data might be complex
        $result | ConvertTo-Json -Depth 5 | Write-Host
    }
}

#endregion Admin Functions

#region Main Logic Loops

function Show-PassengerView {
    while ($true) {
        Show-PassengerMenu
        $choice = Read-Host "Select an option"
        switch ($choice) {
            '1' { Register-Passenger }
            '2' { Login-Passenger }
            '3' { View-PassengerProfile }
            '4' { Buy-PassengerTicket }
            '5' { View-PassengerTickets }
            '0' { break }
            default { Write-Host "Invalid option. Try again, will ya?" -ForegroundColor Red }
        }
        Read-Host "Press Enter to continue..."
    }
}

function Show-AdminView {
    while ($true) {
        Show-AdminMenu
        $choice = Read-Host "Select an option"
        switch ($choice) {
            '1' { Login-Admin }
            '2' { List-AdminUsers }
            '3' { List-Disruptions }
            '4' { Create-Disruption }
            '5' { View-Dashboard }
            '0' { break }
            default { Write-Host "Invalid option. Give it another go." -ForegroundColor Red }
        }
        Read-Host "Press Enter to continue..."
    }
}

# --- Main Program Loop ---
while ($true) {
    Show-MainMenu
    $mainChoice = Read-Host "Select a view"
    switch ($mainChoice) {
        '1' { Show-PassengerView }
        '2' { Show-AdminView }
        '0' { Write-Host "Exiting... Cheers!" -ForegroundColor Green; break }
        default { 
            Write-Host "Invalid option. But, you know, it's kinda hard to get the right number..." -ForegroundColor Red 
            Read-Host "Press Enter to continue..."
        }
    }
}