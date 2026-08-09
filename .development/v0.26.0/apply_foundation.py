from pathlib import Path
import json
import re

ROOT = Path(__file__).resolve().parents[3]


def read(path):
    return (ROOT / path).read_text(encoding="utf-8-sig")


def write(path, text):
    (ROOT / path).write_text(text, encoding="utf-8")


def replace_once(text, old, new, label):
    count = text.count(old)
    if count != 1:
        raise RuntimeError(f"{label}: expected exactly one match, found {count}")
    return text.replace(old, new, 1)


def regex_once(text, pattern, replacement, label):
    updated, count = re.subn(pattern, replacement, text, count=1, flags=re.S)
    if count != 1:
        raise RuntimeError(f"{label}: expected exactly one regex match, found {count}")
    return updated


# 1. Fix the PowerShell case-insensitive $Title / $title collision.
p = "HuymaierShellRedesign.ps1"
s = read(p)
s = replace_once(
    s,
    "$stack=New-Object System.Windows.Controls.StackPanel;$title=New-Object System.Windows.Controls.TextBlock;$title.Text=$Title;$title.FontSize=27;$title.FontWeight='Bold';$title.Foreground='White';$title.Margin='0,0,0,18';$stack.Children.Add($title)|Out-Null",
    "$stack=New-Object System.Windows.Controls.StackPanel;$titleBlock=New-Object System.Windows.Controls.TextBlock;$titleBlock.Text=$Title;$titleBlock.FontSize=27;$titleBlock.FontWeight='Bold';$titleBlock.Foreground='White';$titleBlock.Margin='0,0,0,18';$stack.Children.Add($titleBlock)|Out-Null",
    "choice popup title variable",
)
write(p, s)


# 2. Shell version, prompt capability model, Guide separation, and Game Bar lifecycle.
p = "HuymaierConsole.ps1"
s = read(p)
s = replace_once(s, "$script:AppVersion = '0.25.6'", "$script:AppVersion = '0.26.0'", "shell version")
s = replace_once(
    s,
    "$script:WebBrowserModulePath = Join-Path $script:BaseDir 'HuymaierWebBrowser.ps1'\n",
    "$script:WebBrowserModulePath = Join-Path $script:BaseDir 'HuymaierWebBrowser.ps1'\n$script:GameBarModulePath = Join-Path $script:BaseDir 'HuymaierGameBar.ps1'\n",
    "Game Bar module path",
)

prompt_function = r'''function Render-PromptFooter {
    if ($null -eq $script:PromptPanel) { return }
    $script:PromptPanel.Children.Clear()
    $family = Get-PromptFamily
    $secondary=''
    try{$secondary=[string](Get-StorefrontSecondaryLabel)}catch{}
    if($secondary -notin @('Manage','Install')){$secondary=''}
    switch ($family) {
        'PlayStation' {
            Add-PromptPair (New-PlayStationPrompt 'Cross') 'Select'
            Add-PromptPair (New-PlayStationPrompt 'Circle') 'Back'
            if($secondary){Add-PromptPair (New-PlayStationPrompt 'Square') $secondary}
            Add-PromptPair (New-KeycapPrompt 'PS' 34) 'Quick Access'
            Add-PromptPair (New-PlayStationPrompt 'Options') 'Power'
        }
        'Nintendo' {
            Add-PromptPair (New-LetterPrompt 'A' '#F4F6FA') 'Select'
            Add-PromptPair (New-LetterPrompt 'B' '#F4F6FA') 'Back'
            if($secondary){Add-PromptPair (New-LetterPrompt 'X' '#F4F6FA') $secondary}
            Add-PromptPair (New-KeycapPrompt 'HOME' 48) 'Quick Access'
            Add-PromptPair (New-KeycapPrompt '+') 'Power'
        }
        'Steam' {
            Add-PromptPair (New-LetterPrompt 'A' '#7ECF75') 'Select'
            Add-PromptPair (New-LetterPrompt 'B' '#E66B6B') 'Back'
            if($secondary){Add-PromptPair (New-LetterPrompt 'X' '#65AEE8') $secondary}
            Add-PromptPair (New-KeycapPrompt 'STEAM' 52) 'Quick Access'
        }
        'Xbox' {
            Add-PromptPair (New-LetterPrompt 'A' '#73C86B') 'Select'
            Add-PromptPair (New-LetterPrompt 'B' '#E56565') 'Back'
            if($secondary){Add-PromptPair (New-LetterPrompt 'X' '#65AEE8') $secondary}
            Add-PromptPair (New-KeycapPrompt 'XBOX' 48) 'Quick Access'
            Add-PromptPair (New-KeycapPrompt 'MENU' 48) 'Power'
        }
        default {
            Add-PromptPair (New-KeycapPrompt 'ENTER' 54) 'Select'
            Add-PromptPair (New-KeycapPrompt 'ESC' 42) 'Back'
            Add-PromptPair (New-KeycapPrompt 'F10' 42) 'Windowed'
        }
    }
}
'''
s = regex_once(
    s,
    r"function Render-PromptFooter \{.*?\n\}\n\nfunction Test-IsMouseLikeControllerName",
    prompt_function + "\nfunction Test-IsMouseLikeControllerName",
    "prompt footer function",
)
s = replace_once(
    s,
    "                '^(XboxView|View|Back|Share|Create|Home|Guide|PS)$' { $result.Mask = $result.Mask -bor 2; continue }",
    "                '^(XboxGuide|Guide|Home|PS|PlayStation)$' { $result.Mask = $result.Mask -bor 2; continue }\n                '^(XboxView|View|Back|Share|Create)$' { $result.Mask = $result.Mask -bor 4096; continue }",
    "RawGameController Guide labels",
)
s = replace_once(
    s,
    "            $mask = [int]$reading.Buttons\n            $combinedMask = $combinedMask -bor $mask",
    "            $mask = [int]$reading.Buttons\n            # Windows.Gaming.Input bit 2 is View/Back, not the Xbox system Guide button.\n            $mask = $mask -band (-bnot 2)\n            $combinedMask = $combinedMask -bor $mask",
    "WGI View/Guide separation",
)
s = replace_once(s, "                'Menu' {$nativeMask=2}", "                'Guide' {$nativeMask=2}", "native Guide command mapping")
s = replace_once(
    s,
    "if (Test-Path -LiteralPath $script:WebBrowserModulePath) {\n    try { . $script:WebBrowserModulePath }\n    catch { Write-Log \"Native browser module load failed: $($_.Exception.Message)\" 'ERROR' }\n}\n\n$xaml = @'",
    "if (Test-Path -LiteralPath $script:WebBrowserModulePath) {\n    try { . $script:WebBrowserModulePath }\n    catch { Write-Log \"Native browser module load failed: $($_.Exception.Message)\" 'ERROR' }\n}\nif (Test-Path -LiteralPath $script:GameBarModulePath) {\n    try { . $script:GameBarModulePath }\n    catch { Write-Log \"Huymaier Game Bar module load failed: $($_.Exception.Message)\" 'ERROR' }\n}\n\n$xaml = @'",
    "Game Bar module load",
)
s = replace_once(s, 'Text="HUYMAIER FSE  v0.25.6"', 'Text="HUYMAIER FSE  v0.26.0"', "footer build version")
s = replace_once(
    s,
    "    $gamepadTimer.Start()\n    $script:MainGamepadTimer=$gamepadTimer\n\n    $script:Window.Add_Closing({",
    "    $gamepadTimer.Start()\n    $script:MainGamepadTimer=$gamepadTimer\n\n    if(Get-Command Initialize-HuymaierGameBar -ErrorAction SilentlyContinue){Initialize-HuymaierGameBar}\n\n    $script:Window.Add_Closing({",
    "Game Bar initialization",
)
s = replace_once(
    s,
    "        if(-not $script:AllowWindowClose -and (Get-Date) -lt $script:PreventAutoCloseUntil){$eventArgs.Cancel=$true;Write-Log 'Prevented unintended console close after external launch.' 'WARN';return}\n        $script:IsClosing = $true",
    "        if(-not $script:AllowWindowClose -and (Get-Date) -lt $script:PreventAutoCloseUntil){$eventArgs.Cancel=$true;Write-Log 'Prevented unintended console close after external launch.' 'WARN';return}\n        try{if(Get-Command Stop-HuymaierGameBar -ErrorAction SilentlyContinue){Stop-HuymaierGameBar};if('HuymaierConsole.NativeApp.NativeConsoleNavigation' -as [type]){[HuymaierConsole.NativeApp.NativeConsoleNavigation]::Shutdown()}}catch{}\n        $script:IsClosing = $true",
    "Game Bar shutdown",
)
write(p, s)


# 3. Native router: system Guide is its own command and GameInput owns it when available.
p = "Native/HuymaierConsole.NativeApp.cs"
s = read(p)
s = replace_once(
    s,
    "        None, Left, Right, Up, Down, Confirm, Back, Menu, Options, LeftShoulder, RightShoulder",
    "        None, Left, Right, Up, Down, Confirm, Back, Guide, Menu, Options, LeftShoulder, RightShoulder",
    "native input enum",
)
s = replace_once(s, "            if ((newButtons & 4) != 0) return XmbInputCommand.Menu;", "            if ((newButtons & 4) != 0) return XmbInputCommand.Guide;", "router Guide command")
s = replace_once(s, "            candidates.Clear();\n            try", "            candidates.Clear();\n            bool systemGuideOwned = HuymaierSystemButtonBridge.IsAvailable;\n            try", "GameInput ownership flag")
s = replace_once(s, "                    if ((snapshot.Mask & 2) != 0) buttons |= 4;", "                    if ((snapshot.Mask & 2) != 0 && !systemGuideOwned) buttons |= 4;", "Sony duplicate Guide suppression")
s = replace_once(
    s,
    "                bool activity = snapshot.Buttons != 0 || !String.IsNullOrWhiteSpace(snapshot.Direction);\n                candidates.Add(new InputCandidate(new InputSourceIdentity(1, snapshot.Index), 0,\n                    snapshot.Buttons, snapshot.Direction, activity, !activity));",
    "                int candidateButtons = snapshot.Buttons;\n                if (systemGuideOwned) candidateButtons &= ~4;\n                bool activity = candidateButtons != 0 || !String.IsNullOrWhiteSpace(snapshot.Direction);\n                candidates.Add(new InputCandidate(new InputSourceIdentity(1, snapshot.Index), 0,\n                    candidateButtons, snapshot.Direction, activity, !activity));",
    "XInput duplicate Guide suppression",
)
s = replace_once(
    s,
    "                XmbInputCommand command = router.Poll();\n                string source = router.ActiveSourceKey == null ? String.Empty : router.ActiveSourceKey;",
    "                if (HuymaierSystemButtonBridge.ConsumeGuidePress())\n                {\n                    string systemSource = router.ActiveSourceKey ?? String.Empty;\n                    return new NativeNavigationCommand {\n                        Command = \"Guide\",\n                        Active = true,\n                        Family = systemSource.StartsWith(\"sony:\", StringComparison.OrdinalIgnoreCase) ? \"PlayStation\" : \"Xbox\",\n                        Name = systemSource.StartsWith(\"sony:\", StringComparison.OrdinalIgnoreCase) ? \"PlayStation Guide Button\" : \"Xbox Guide Button\"\n                    };\n                }\n                XmbInputCommand command = router.Poll();\n                string source = router.ActiveSourceKey == null ? String.Empty : router.ActiveSourceKey;",
    "GameInput Guide consumption",
)
s = replace_once(
    s,
    "        public static void Reset()\n        {\n            lock (Sync)\n            {\n                router = new XmbInputRouter();\n                deviceChangeResetPending = false;\n                deviceChangeQuietUntilUtc = DateTime.UtcNow.AddMilliseconds(300);\n            }\n        }\n    }\n\n    internal struct InputSourceIdentity",
    "        public static void Reset()\n        {\n            lock (Sync)\n            {\n                router = new XmbInputRouter();\n                deviceChangeResetPending = false;\n                deviceChangeQuietUntilUtc = DateTime.UtcNow.AddMilliseconds(300);\n            }\n        }\n\n        public static void Shutdown()\n        {\n            lock (Sync)\n            {\n                router.Reset();\n                HuymaierSystemButtonBridge.Shutdown();\n            }\n        }\n    }\n\n    internal struct InputSourceIdentity",
    "native router shutdown",
)
s = replace_once(
    s,
    "                        // XInputGetState exposes Guide as 0x0400 on supported Windows/XInput paths.\n                        // Preserve existing Start/Back compatibility while making Guide explicit.\n                        if ((mask & 0x0400) != 0 || (mask & 0x0010) != 0 || (mask & 0x0020) != 0) buttons |= 4;",
    "                        // Guide is distinct from Start/Menu and Back/View. GameInput owns the\n                        // primary system-button path; 0x0400 remains compatibility fallback only.\n                        if ((mask & 0x0400) != 0) buttons |= 4;",
    "XInput system Guide split",
)
write(p, s)


# 4. Installer integration for Game Bar managed sources, native Guide bridge, and GameInput redist.
p = "Install-HuymaierConsole.ps1"
s = read(p)
s = replace_once(s, "$script:InstallVersion = '0.25.6'", "$script:InstallVersion = '0.26.0'", "installer version")
s = replace_once(
    s,
    "    'HuymaierGameExperience.ps1',\n    'HuymaierShellRedesign.ps1',\n    'HuymaierEmulatorPlatforms.ps1',",
    "    'HuymaierGameExperience.ps1',\n    'HuymaierShellRedesign.ps1',\n    'HuymaierGameBar.ps1',\n    'HuymaierGameInputBridge.dll',\n    'HuymaierEmulatorPlatforms.ps1',",
    "installer Game Bar payload list",
)
redist_block = r'''# Microsoft GameInput is the primary Xbox system-button path for v0.26+.
# The official redistributable does not downgrade a newer installed runtime.
$gameInputRedistVersion='3.5.262'
$gameInputRedist=Join-Path $toolsDestination 'GameInput\GameInputRedist.msi'
$gameInputMarker=Join-Path $destination 'gameinput-redist.version'
$installedGameInputVersion=''
try{if(Test-Path -LiteralPath $gameInputMarker -PathType Leaf){$installedGameInputVersion=(Get-Content -Raw -LiteralPath $gameInputMarker).Trim()}}catch{}
if((Test-Path -LiteralPath $gameInputRedist -PathType Leaf) -and $installedGameInputVersion -ne $gameInputRedistVersion){
    try{
        Write-InstallerRecord "Installing Microsoft GameInput redistributable $gameInputRedistVersion. Windows may request administrator approval."
        $msiArgs='/i "'+$gameInputRedist+'" /qn /norestart'
        $gameInputInstall=Start-Process -FilePath "$env:SystemRoot\System32\msiexec.exe" -ArgumentList $msiArgs -Verb RunAs -Wait -PassThru
        if($gameInputInstall.ExitCode -notin @(0,3010,1638)){throw "GameInput redistributable installer exited with code $($gameInputInstall.ExitCode)."}
        Set-Content -LiteralPath $gameInputMarker -Value $gameInputRedistVersion -Encoding ASCII
        Write-InstallerRecord 'Microsoft GameInput redistributable is ready.'
    }catch{Write-InstallerRecord "Microsoft GameInput redistributable could not be installed; controller input will fall back to Raw HID/XInput where available. $($_.Exception.Message)" 'WARN'}
}

'''
s = replace_once(
    s,
    "$toolsSource=Join-Path $source 'Tools'\n$toolsDestination=Join-Path $destination 'Tools'\nif(Test-Path $toolsSource){\n    New-Item -ItemType Directory -Force -Path $toolsDestination|Out-Null\n    Copy-Item (Join-Path $toolsSource '*') $toolsDestination -Recurse -Force\n}\n\n$nativeSourceRoot=Join-Path $source 'Native'",
    "$toolsSource=Join-Path $source 'Tools'\n$toolsDestination=Join-Path $destination 'Tools'\nif(Test-Path $toolsSource){\n    New-Item -ItemType Directory -Force -Path $toolsDestination|Out-Null\n    Copy-Item (Join-Path $toolsSource '*') $toolsDestination -Recurse -Force\n}\n\n" + redist_block + "$nativeSourceRoot=Join-Path $source 'Native'",
    "GameInput redistributable installer block",
)
s = replace_once(
    s,
    "$nativeConsolePlatformsSource=Join-Path $nativeDestinationRoot 'HuymaierConsole.ConsolePlatforms.cs'\n$nativeInputSource=Join-Path $destination 'HuymaierNativeInput.cs'",
    "$nativeConsolePlatformsSource=Join-Path $nativeDestinationRoot 'HuymaierConsole.ConsolePlatforms.cs'\n$nativeGameBarSource=Join-Path $nativeDestinationRoot 'HuymaierGameBar.cs'\n$nativeGameInputSource=Join-Path $nativeDestinationRoot 'HuymaierConsole.GameInput.cs'\n$nativeInputSource=Join-Path $destination 'HuymaierNativeInput.cs'",
    "native overlay source paths",
)
s = replace_once(
    s,
    "foreach($requiredSource in @($nativeAppSource,$nativePs1Source,$nativeConsolePlatformsSource,$nativeInputSource,$nativeDisplaySource,$nativeAudioSource,$nativePerformanceSource,$p3tSource)){",
    "foreach($requiredSource in @($nativeAppSource,$nativePs1Source,$nativeConsolePlatformsSource,$nativeGameBarSource,$nativeGameInputSource,$nativeInputSource,$nativeDisplaySource,$nativeAudioSource,$nativePerformanceSource,$p3tSource)){",
    "required native overlay sources",
)
s = replace_once(
    s,
    "    $nativeAppSource,\n    $nativePs1Source,\n    $nativeConsolePlatformsSource,\n    $nativeInputSource,",
    "    $nativeAppSource,\n    $nativePs1Source,\n    $nativeConsolePlatformsSource,\n    $nativeGameBarSource,\n    $nativeGameInputSource,\n    $nativeInputSource,",
    "managed overlay compile sources",
)
write(p, s)


# 5. Bootstrap validates and identifies the new module/version.
p = "HuymaierBootstrap.ps1"
s = read(p)
s = replace_once(
    s,
    "$shellRedesignPath = Join-Path $baseDir 'HuymaierShellRedesign.ps1'\n",
    "$shellRedesignPath = Join-Path $baseDir 'HuymaierShellRedesign.ps1'\n$gameBarPath = Join-Path $baseDir 'HuymaierGameBar.ps1'\n",
    "bootstrap Game Bar path",
)
s = replace_once(
    s,
    "    Test-PowerShellFile $shellRedesignPath 'Shell redesign'\n    Write-BootstrapLog 'Huymaier Console v0.25.6 preflight passed.'",
    "    Test-PowerShellFile $shellRedesignPath 'Shell redesign'\n    Test-PowerShellFile $gameBarPath 'Huymaier Game Bar'\n    Write-BootstrapLog 'Huymaier Console v0.26.0 preflight passed.'",
    "bootstrap Game Bar validation",
)
s = replace_once(s, 'Write-BootstrapLog "v0.25.6 preflight/startup failed:', 'Write-BootstrapLog "v0.26.0 preflight/startup failed:', "bootstrap failure version")
write(p, s)


# 6. Preserve the v0.25.8 downloader hotfix while advancing the branch version.
p = "HuymaierConsoleUpdateWorker.ps1"
s = read(p)
s = replace_once(s, "    [string]$CurrentVersion='0.25.6',", "    [string]$CurrentVersion='0.26.0',", "updater default version")
s = replace_once(s, "$client.DefaultRequestHeaders.UserAgent.ParseAdd('HuymaierConsole/0.25.6')", "$client.DefaultRequestHeaders.UserAgent.ParseAdd('HuymaierConsole/0.26.0')", "updater user agent")
s = replace_once(
    s,
    "$total=[long]$asset.size;if($response.Content.Headers.ContentLength.HasValue){$total=[long]$response.Content.Headers.ContentLength.Value}",
    "$total=[long]$asset.size;$contentLength=$response.Content.Headers.ContentLength;if($null -ne $contentLength -and [long]$contentLength -gt 0){$total=[long]$contentLength}",
    "updater ContentLength scalar handling",
)
write(p, s)


# 7. Make the branch manifest truthful.
p = ROOT / "manifest.json"
data = json.loads(p.read_text(encoding="utf-8-sig"))
data.update({
    "version": "0.26.0",
    "baseVersion": "0.25.8",
    "build": "native-gamebar-guide-task-switcher-development",
    "builtFrom": "HC258.zip",
    "description": "Development baseline for the native Huymaier Game Bar, task switcher, real Guide routing, popup chooser repair, and capability-driven prompts.",
})
data["features"] = [
    "keeps Quick Access exclusive to Huymaier Console while adding a separate external-game/app Huymaier Game Bar",
    "separates physical Guide/Xbox/PS/Home from Xbox View/Back and PlayStation Share/Create",
    "adds a native Microsoft GameInput system-button bridge with Raw HID/XInput compatibility fallback",
    "adds a native Huymaier task switcher baseline for user-facing top-level Windows application windows",
    "fixes the PowerShell Title/title collision that prevented centered finite-choice popups from opening",
    "removes decorative X/Square Search prompts when no secondary action exists",
    "preserves the v0.25.8 Windows PowerShell BOM packaging and updater ContentLength hotfixes",
]
p.write_text(json.dumps(data, indent=2) + "\n", encoding="utf-8")

print("v0.26.0 foundation source transformation completed successfully.")
