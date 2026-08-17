param(
    [Parameter(Mandatory=$true)]
    [ValidateSet('Scan','InstallUpdates','InstallUpdate','InstallPackage')]
    [string]$Action,
    [Parameter(Mandatory=$true)]
    [string]$StatePath,
    [string]$PackagePath = '',
    [string]$UpdateId = ''
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

function Convert-ToStableArray {
    param($Value)
    $buffer = New-Object System.Collections.ArrayList
    if ($null -ne $Value) {
        try { foreach ($item in $Value) { [void]$buffer.Add($item) } }
        catch { [void]$buffer.Add($Value) }
    }
    return ,([object[]]$buffer.ToArray())
}

function Convert-DriverDate {
    param($Value)
    if ($null -eq $Value) { return '' }
    try {
        if ($Value -is [datetime]) { return ([datetime]$Value).ToString('yyyy-MM-dd') }
        $text = [string]$Value
        if ($text -match '^\d{14}\.\d{6}[+-]\d{3}$') {
            return [Management.ManagementDateTimeConverter]::ToDateTime($text).ToString('yyyy-MM-dd')
        }
        return ([datetime]$Value).ToString('yyyy-MM-dd')
    } catch { return [string]$Value }
}

function Get-InstalledDrivers {
    $items = New-Object System.Collections.ArrayList
    try {
        $drivers = @(Get-CimInstance -ClassName Win32_PnPSignedDriver -ErrorAction Stop | Where-Object { $_.DeviceName })
        foreach ($driver in $drivers) {
            [void]$items.Add([pscustomobject]@{
                DeviceName = [string]$driver.DeviceName
                DeviceClass = [string]$driver.DeviceClass
                Provider = [string]$driver.DriverProviderName
                Manufacturer = [string]$driver.Manufacturer
                Version = [string]$driver.DriverVersion
                DriverDate = Convert-DriverDate $driver.DriverDate
                InfName = [string]$driver.InfName
                IsSigned = $(try { [bool]$driver.IsSigned } catch { $false })
                DeviceId = [string]$driver.DeviceID
            })
        }
    } catch {
        # Windows PowerShell on some systems is more reliable through WMI than CIM.
        try {
            $drivers = @(Get-WmiObject -Class Win32_PnPSignedDriver -ErrorAction Stop | Where-Object { $_.DeviceName })
            foreach ($driver in $drivers) {
                [void]$items.Add([pscustomobject]@{
                    DeviceName = [string]$driver.DeviceName
                    DeviceClass = [string]$driver.DeviceClass
                    Provider = [string]$driver.DriverProviderName
                    Manufacturer = [string]$driver.Manufacturer
                    Version = [string]$driver.DriverVersion
                    DriverDate = Convert-DriverDate $driver.DriverDate
                    InfName = [string]$driver.InfName
                    IsSigned = $(try { [bool]$driver.IsSigned } catch { $false })
                    DeviceId = [string]$driver.DeviceID
                })
            }
        } catch { }
    }
    return ,([object[]]$items.ToArray())
}

function Get-DisplayDrivers {
    param([object[]]$Drivers)
    $items = New-Object System.Collections.ArrayList
    foreach ($driver in (Convert-ToStableArray $Drivers)) {
        $class = [string]$driver.DeviceClass
        $name = [string]$driver.DeviceName
        if ($class -eq 'DISPLAY' -or $name -match '(NVIDIA|GeForce|Radeon|AMD|Intel.*(Graphics|Arc|UHD|Iris))') {
            [void]$items.Add($driver)
        }
    }
    return ,([object[]]$items.ToArray())
}

function Convert-DriverUpdate {
    param($Update)
    $size = 0L
    try { $size = [int64]$Update.MaxDownloadSize } catch { }
    $manufacturer = ''; try { $manufacturer = [string]$Update.DriverManufacturer } catch { }
    $model = ''; try { $model = [string]$Update.DriverModel } catch { }
    $class = ''; try { $class = [string]$Update.DriverClass } catch { }
    $version = ''; try { $version = [string]$Update.DriverVerVersion } catch { }
    $date = ''; try { $date = ([datetime]$Update.DriverVerDate).ToString('yyyy-MM-dd') } catch { }
    return [pscustomobject]@{
        Title = [string]$Update.Title
        Manufacturer = $manufacturer
        Model = $model
        Class = $class
        Version = $version
        DriverDate = $date
        SizeBytes = $size
        RequiresReboot = $(try { [bool]$Update.RebootRequired } catch { $false })
        UpdateId = $(try { [string]$Update.Identity.UpdateID } catch { '' })
        Revision = $(try { [int]$Update.Identity.RevisionNumber } catch { 0 })
    }
}

function New-UpdateSession {
    $session = New-Object -ComObject Microsoft.Update.Session
    $session.ClientApplicationID = 'Huymaier Console FSE - Driver Management'
    return $session
}

function Search-DriverUpdates {
    param($Session)
    $searcher = $Session.CreateUpdateSearcher()
    # WUA's Driver type includes applicable Plug and Play driver-class updates
    # from the Windows/Microsoft Update service selected for this machine.
    return $searcher.Search("IsInstalled=0 and IsHidden=0 and Type='Driver'")
}

function Get-DriverSnapshot {
    param($Session = $null)
    $drivers = Get-InstalledDrivers
    $display = Get-DisplayDrivers $drivers
    $updates = @()
    $updateError = ''
    try {
        if ($null -eq $Session) { $Session = New-UpdateSession }
        $search = Search-DriverUpdates $Session
        $buffer = New-Object System.Collections.ArrayList
        for ($i=0; $i -lt $search.Updates.Count; $i++) {
            [void]$buffer.Add((Convert-DriverUpdate $search.Updates.Item($i)))
        }
        $updates = [object[]]$buffer.ToArray()
    } catch {
        $updateError = $_.Exception.Message
    }
    return [pscustomobject]@{
        Drivers = [object[]](Convert-ToStableArray $drivers)
        DisplayDrivers = [object[]](Convert-ToStableArray $display)
        Updates = [object[]](Convert-ToStableArray $updates)
        UpdateError = $updateError
    }
}

function Write-DriverState {
    param(
        [string]$Phase,
        [string]$Message,
        [bool]$Busy,
        [object[]]$Drivers = @(),
        [object[]]$DisplayDrivers = @(),
        [object[]]$Updates = @(),
        [bool]$RebootRequired = $false,
        [string]$ErrorMessage = '',
        [int]$ResultCode = 0,
        [string]$LastAction = ''
    )
    $stableDrivers = Convert-ToStableArray $Drivers
    $stableDisplay = Convert-ToStableArray $DisplayDrivers
    $stableUpdates = Convert-ToStableArray $Updates
    $state = [pscustomobject]@{
        Phase = $Phase
        Message = $Message
        Busy = $Busy
        DriverCount = [int]$stableDrivers.Count
        DisplayDriverCount = [int]$stableDisplay.Count
        UpdateCount = [int]$stableUpdates.Count
        Drivers = $stableDrivers
        DisplayDrivers = $stableDisplay
        Updates = $stableUpdates
        RebootRequired = $RebootRequired
        Error = $ErrorMessage
        ResultCode = $ResultCode
        LastAction = $LastAction
        UpdatedAt = (Get-Date).ToString('o')
    }
    $directory = Split-Path -Parent $StatePath
    if ($directory) { New-Item -ItemType Directory -Force -Path $directory | Out-Null }
    $temp = "$StatePath.tmp"
    $state | ConvertTo-Json -Depth 10 | Set-Content -Path $temp -Encoding UTF8
    Move-Item -Path $temp -Destination $StatePath -Force
}

try {
    if ($Action -eq 'Scan') {
        Write-DriverState 'Scanning' 'Detecting installed drivers and checking Windows Update for driver updates...' $true -LastAction 'Scan'
        $session = New-UpdateSession
        $snapshot = Get-DriverSnapshot $session
        $message = if ($snapshot.Updates.Count -gt 0) {
            "$($snapshot.Updates.Count) recommended driver update(s) are available."
        } elseif ($snapshot.UpdateError) {
            "Detected $($snapshot.Drivers.Count) signed device driver(s). Driver-update scan could not complete."
        } else {
            "Detected $($snapshot.Drivers.Count) signed device driver(s). No recommended driver updates are currently offered."
        }
        Write-DriverState 'Ready' $message $false $snapshot.Drivers $snapshot.DisplayDrivers $snapshot.Updates $false $snapshot.UpdateError 0 'Scan'
        exit 0
    }

    if ($Action -in @('InstallUpdates','InstallUpdate')) {
        $single=$Action -eq 'InstallUpdate'
        if($single -and [string]::IsNullOrWhiteSpace($UpdateId)){throw 'No driver update was selected.'}
        Write-DriverState 'Preparing' $(if($single){'Preparing the selected driver update. Approve the Windows administrator prompt if shown.'}else{'Preparing recommended driver updates. Approve the Windows administrator prompt if shown.'}) $true -LastAction $Action
        $session = New-UpdateSession
        $search = Search-DriverUpdates $session
        if ([int]$search.Updates.Count -eq 0) {
            $snapshot = Get-DriverSnapshot $session
            Write-DriverState 'Ready' 'No recommended driver updates are currently offered.' $false $snapshot.Drivers $snapshot.DisplayDrivers $snapshot.Updates $false $snapshot.UpdateError 0 $Action
            exit 0
        }

        $collection = New-Object -ComObject Microsoft.Update.UpdateColl
        $displayItems = New-Object System.Collections.ArrayList
        for ($i=0; $i -lt $search.Updates.Count; $i++) {
            $update = $search.Updates.Item($i)
            $id='';try{$id=[string]$update.Identity.UpdateID}catch{}
            if($single -and -not [string]::Equals($id,$UpdateId,[StringComparison]::OrdinalIgnoreCase)){continue}
            try { if (-not $update.EulaAccepted) { $update.AcceptEula() } } catch { }
            [void]$collection.Add($update)
            [void]$displayItems.Add((Convert-DriverUpdate $update))
        }
        if($collection.Count -eq 0){throw 'The selected driver update is no longer available. Scan again to refresh the list.'}
        $visibleUpdates = [object[]]$displayItems.ToArray()
        $installedBefore = Get-InstalledDrivers
        $displayBefore = Get-DisplayDrivers $installedBefore
        Write-DriverState 'Downloading' "Downloading $($collection.Count) driver update(s)..." $true $installedBefore $displayBefore $visibleUpdates $false '' 0 $Action

        $downloader = $session.CreateUpdateDownloader()
        $downloader.Updates = $collection
        $downloadResult = $downloader.Download()
        if ([int]$downloadResult.ResultCode -notin @(2,3)) {
            Write-DriverState 'Error' "Driver download failed with result code $([int]$downloadResult.ResultCode)." $false $installedBefore $displayBefore $visibleUpdates $false '' ([int]$downloadResult.ResultCode) $Action
            exit 1
        }

        Write-DriverState 'Installing' "Installing $($collection.Count) driver update(s)..." $true $installedBefore $displayBefore $visibleUpdates $false '' ([int]$downloadResult.ResultCode) $Action
        $installer = $session.CreateUpdateInstaller()
        $installer.Updates = $collection
        $installResult = $installer.Install()
        $reboot = [bool]$installResult.RebootRequired
        $code = [int]$installResult.ResultCode

        $snapshot = Get-DriverSnapshot (New-UpdateSession)
        $message = switch ($code) {
            2 { $(if($single){'The selected driver update installed successfully.'}else{'Recommended driver updates installed successfully.'}) }
            3 { 'Driver updates installed with one or more errors.' }
            4 { 'Driver update installation failed.' }
            5 { 'Driver update installation was canceled.' }
            default { "Driver update installation finished with result code $code." }
        }
        if ($reboot) { $message += ' Restart Windows to finish.' }
        Write-DriverState 'Complete' $message $false $snapshot.Drivers $snapshot.DisplayDrivers $snapshot.Updates $reboot $snapshot.UpdateError $code $Action
        exit $(if($code -in @(2,3)){0}else{1})
    }

    if ([string]::IsNullOrWhiteSpace($PackagePath) -or -not (Test-Path -LiteralPath $PackagePath -PathType Container)) {
        throw 'The selected driver-package folder does not exist.'
    }
    $infFiles = @(Get-ChildItem -LiteralPath $PackagePath -Filter '*.inf' -File -Recurse -ErrorAction SilentlyContinue)
    if ($infFiles.Count -eq 0) { throw 'No .inf driver packages were found in the selected folder or its subfolders.' }

    Write-DriverState 'Installing' "Installing signed driver packages from $PackagePath ..." $true -LastAction 'InstallPackage'
    $pnputil = Join-Path $env:SystemRoot 'System32\pnputil.exe'
    if (-not (Test-Path -LiteralPath $pnputil -PathType Leaf)) { throw 'Windows PnPUtil was not found.' }
    $pattern = Join-Path $PackagePath '*.inf'
    $output = & $pnputil /add-driver $pattern /subdirs /install 2>&1 | Out-String
    $code = [int]$LASTEXITCODE
    $reboot = $false
    if ($output -match '(?i)(restart|reboot).*(required|needed)' -or $code -eq 3010) { $reboot = $true }

    $snapshot = Get-DriverSnapshot
    $message = if ($code -in @(0,3010)) {
        "Driver package processing completed for $($infFiles.Count) INF file(s)."
    } else {
        "PnPUtil finished with exit code $code. Review the driver package and signature status."
    }
    if ($reboot) { $message += ' Restart Windows to finish.' }
    $errorText = if ($code -in @(0,3010)) { $snapshot.UpdateError } else { $output.Trim() }
    Write-DriverState $(if($code -in @(0,3010)){'Complete'}else{'Error'}) $message $false $snapshot.Drivers $snapshot.DisplayDrivers $snapshot.Updates $reboot $errorText $code 'InstallPackage'
    exit $(if($code -in @(0,3010)){0}else{1})
}
catch {
    Write-DriverState 'Error' 'Driver management could not complete.' $false @() @() @() $false $_.Exception.Message -1 $Action
    exit 1
}
