param()

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Continue'

$root = Split-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) -Parent
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$outDir = Join-Path $env:LOCALAPPDATA 'Huymaier Console\Logs'
New-Item -ItemType Directory -Path $outDir -Force | Out-Null
$outPath = Join-Path $outDir "controller-diagnostics-$stamp.txt"

$lines = New-Object System.Collections.Generic.List[string]
function Add-Line([string]$Text='') { $lines.Add($Text) }

Add-Line 'Huymaier Console controller diagnostics'
Add-Line "Captured: $(Get-Date -Format o)"
Add-Line "Windows: $([Environment]::OSVersion.VersionString)"
Add-Line ''

try {
    Add-Type -AssemblyName System.Runtime.WindowsRuntime -ErrorAction SilentlyContinue
    $gamepads = @([Windows.Gaming.Input.Gamepad,Windows.Gaming.Input,ContentType=WindowsRuntime]::Gamepads)
    Add-Line "Windows.Gaming.Input.Gamepad count: $($gamepads.Count)"
    for($i=0;$i -lt $gamepads.Count;$i++){
        try{
            $r=$gamepads[$i].GetCurrentReading()
            Add-Line "  Gamepad[$i]: Buttons=$([uint64]$r.Buttons) LX=$([math]::Round([double]$r.LeftThumbstickX,3)) LY=$([math]::Round([double]$r.LeftThumbstickY,3))"
        }catch{Add-Line "  Gamepad[$i]: read failed: $($_.Exception.Message)"}
    }
    Add-Line ''

    $raw = @([Windows.Gaming.Input.RawGameController,Windows.Gaming.Input,ContentType=WindowsRuntime]::RawGameControllers)
    Add-Line "RawGameController count: $($raw.Count)"
    for($i=0;$i -lt $raw.Count;$i++){
        $c=$raw[$i]
        $name='';$vid='';$productId='';$buttons='';$switches='';$axes=''
        try{$name=[string]$c.DisplayName}catch{}
        try{$vid=('0x{0:X4}' -f [int]$c.HardwareVendorId)}catch{}
        try{$productId=('0x{0:X4}' -f [int]$c.HardwareProductId)}catch{}
        try{$buttons=[int]$c.ButtonCount}catch{}
        try{$switches=[int]$c.SwitchCount}catch{}
        try{$axes=[int]$c.AxisCount}catch{}
        Add-Line "  Raw[$i]: Name='$name' VID=$vid PID=$productId Buttons=$buttons Switches=$switches Axes=$axes"
        try{
            $buttonValues=New-Object 'System.Boolean[]' ([int]$c.ButtonCount)
            $switchType=[Windows.Gaming.Input.GameControllerSwitchPosition,Windows.Gaming.Input,ContentType=WindowsRuntime]
            $switchValues=[Array]::CreateInstance($switchType,[int]$c.SwitchCount)
            $axisValues=New-Object 'System.Double[]' ([int]$c.AxisCount)
            [void]$c.GetCurrentReading($buttonValues,$switchValues,$axisValues)
            Add-Line "    ActiveButtons=$([string]::Join(',',@($buttonValues | ForEach-Object -Begin {$n=0} -Process {if($_){$n};$n++})))"
            Add-Line "    Switches=$([string]::Join(',',@($switchValues)))"
            Add-Line "    Axes=$([string]::Join(',',@($axisValues | ForEach-Object {[math]::Round([double]$_,4)})))"
        }catch{Add-Line "    Reading failed: $($_.Exception.Message)"}
    }
}catch{Add-Line "Windows.Gaming.Input enumeration failed: $($_.Exception.Message)"}

Add-Line ''
try{
    $native=Join-Path $root 'HuymaierNativeInput.cs'
    if((Test-Path $native) -and -not ('HuymaierConsole.Native.LegacyJoystick' -as [type])){Add-Type -TypeDefinition (Get-Content $native -Raw)}
    if('HuymaierConsole.Native.LegacyJoystick' -as [type]){
        $legacy=@([HuymaierConsole.Native.LegacyJoystick]::GetSnapshots())
        Add-Line "Eligible WinMM/DirectInput controllers after mouse filtering: $($legacy.Count)"
        foreach($c in $legacy){Add-Line "  Legacy[$($c.Id)]: '$($c.Name)' Buttons=$($c.Buttons) POV=$($c.Pov) X=$($c.X) Y=$($c.Y)"}
    }
}catch{Add-Line "Legacy controller enumeration failed: $($_.Exception.Message)"}

Add-Line ''
try{
    Add-Line 'Relevant Plug and Play devices:'
    $devices=Get-CimInstance Win32_PnPEntity | Where-Object {
        $_.Name -match 'Swiftpoint|DualSense|DualShock|Wireless Controller|Xbox|Gamepad|Controller|HID-compliant game controller'
    } | Sort-Object Name
    foreach($d in $devices){Add-Line "  $($d.Name) | Class=$($d.PNPClass) | Status=$($d.Status) | ID=$($d.PNPDeviceID)"}
}catch{Add-Line "PnP enumeration failed: $($_.Exception.Message)"}

$lines | Set-Content -LiteralPath $outPath -Encoding UTF8
Write-Host "Controller diagnostics saved to:`n$outPath" -ForegroundColor Green
Start-Process notepad.exe -ArgumentList ('"'+$outPath+'"')
