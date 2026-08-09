param(
    [Parameter(Mandatory=$true)]
    [ValidateSet('Scan','Install')]
    [string]$Action,
    [Parameter(Mandatory=$true)]
    [string]$StatePath
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

function Write-UpdateState {
    param(
        [string]$Phase,
        [string]$Message,
        [bool]$Busy,
        [object[]]$Updates = @(),
        [bool]$RebootRequired = $false,
        [string]$ErrorMessage = '',
        [int]$ResultCode = 0
    )
    $stableUpdates = Convert-ToStableArray $Updates
    $state = [pscustomobject]@{
        Phase = $Phase
        Message = $Message
        Busy = $Busy
        UpdateCount = [int]$stableUpdates.Count
        Updates = $stableUpdates
        RebootRequired = $RebootRequired
        Error = $ErrorMessage
        ResultCode = $ResultCode
        UpdatedAt = (Get-Date).ToString('o')
    }
    $directory = Split-Path -Parent $StatePath
    if ($directory) { New-Item -ItemType Directory -Force -Path $directory | Out-Null }
    $temp = "$StatePath.tmp"
    $state | ConvertTo-Json -Depth 8 | Set-Content -Path $temp -Encoding UTF8
    Move-Item -Path $temp -Destination $StatePath -Force
}

function Convert-Update {
    param($Update)
    $ids = New-Object System.Collections.ArrayList
    try {
        for ($i=0; $i -lt $Update.KBArticleIDs.Count; $i++) { [void]$ids.Add([string]$Update.KBArticleIDs.Item($i)) }
    } catch { }
    $kb = if ($ids.Count -gt 0) { 'KB' + (([object[]]$ids.ToArray()) -join ', KB') } else { '' }
    $size = 0L
    try { $size = [int64]$Update.MaxDownloadSize } catch { }
    return [pscustomobject]@{
        Title = [string]$Update.Title
        KB = $kb
        SizeBytes = $size
        RequiresReboot = $(try { [bool]$Update.RebootRequired } catch { $false })
    }
}

function New-UpdateSession {
    $session = New-Object -ComObject Microsoft.Update.Session
    $session.ClientApplicationID = 'Huymaier Console FSE'
    return $session
}

try {
    if ($Action -eq 'Scan') {
        Write-UpdateState 'Scanning' 'Checking Windows Update for applicable updates...' $true
        $session = New-UpdateSession
        $searcher = $session.CreateUpdateSearcher()
        $result = $searcher.Search("IsInstalled=0 and IsHidden=0 and Type='Software'")
        $items = New-Object System.Collections.ArrayList
        for ($i=0; $i -lt $result.Updates.Count; $i++) { [void]$items.Add((Convert-Update $result.Updates.Item($i))) }
        $updates = [object[]]$items.ToArray()
        $message = if ($updates.Count -eq 0) { 'Windows is up to date.' } else { "$($updates.Count) update(s) are ready." }
        Write-UpdateState 'Ready' $message $false $updates
        exit 0
    }

    Write-UpdateState 'Preparing' 'Preparing Windows updates...' $true
    $session = New-UpdateSession
    $searcher = $session.CreateUpdateSearcher()
    $search = $searcher.Search("IsInstalled=0 and IsHidden=0 and Type='Software'")
    $availableCount = [int]$search.Updates.Count
    if ($availableCount -eq 0) {
        Write-UpdateState 'Ready' 'Windows is up to date.' $false @()
        exit 0
    }

    $collection = New-Object -ComObject Microsoft.Update.UpdateColl
    $displayItems = New-Object System.Collections.ArrayList
    for ($i=0; $i -lt $availableCount; $i++) {
        $update = $search.Updates.Item($i)
        try { if (-not $update.EulaAccepted) { $update.AcceptEula() } } catch { }
        [void]$collection.Add($update)
        [void]$displayItems.Add((Convert-Update $update))
    }
    $stableItems = [object[]]$displayItems.ToArray()

    Write-UpdateState 'Downloading' "Downloading $($collection.Count) update(s)..." $true $stableItems
    $downloader = $session.CreateUpdateDownloader()
    $downloader.Updates = $collection
    $downloadResult = $downloader.Download()

    if ([int]$downloadResult.ResultCode -notin @(2,3)) {
        Write-UpdateState 'Error' "Update download failed with result code $([int]$downloadResult.ResultCode)." $false $stableItems $false '' ([int]$downloadResult.ResultCode)
        exit 1
    }

    Write-UpdateState 'Installing' "Installing $($collection.Count) update(s)..." $true $stableItems $false '' ([int]$downloadResult.ResultCode)
    $installer = $session.CreateUpdateInstaller()
    $installer.Updates = $collection
    $installResult = $installer.Install()

    $reboot = [bool]$installResult.RebootRequired
    $code = [int]$installResult.ResultCode
    $message = switch ($code) {
        2 { 'Windows updates installed successfully.' }
        3 { 'Windows updates installed with one or more errors.' }
        4 { 'Windows update installation failed.' }
        5 { 'Windows update installation was canceled.' }
        default { "Windows Update finished with result code $code." }
    }
    if ($reboot) { $message += ' Restart Windows to finish.' }
    Write-UpdateState 'Complete' $message $false @() $reboot '' $code
}
catch {
    Write-UpdateState 'Error' 'Windows Update could not complete.' $false @() $false $_.Exception.Message -1
    exit 1
}
