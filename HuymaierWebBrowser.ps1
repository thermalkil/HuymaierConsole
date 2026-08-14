# Huymaier Console native controller browser (WebView2)
# Loaded by HuymaierConsole.ps1. All browser data stays under the current
# Windows user's Huymaier Console data directory.

# Keep every browser state field defined before StrictMode can observe it.
# WebView2 itself remains lazy; these are only lightweight state/path values.
$script:HcBrowserOverlay=$null
$script:HcBrowserHost=$null
$script:HcBrowserWebView=$null
$script:HcBrowserFallback=$null
$script:HcBrowserReady=$false
$script:HcBrowserActive=$false
$script:HcBrowserFocusArea='Web'
$script:HcBrowserToolbarIndex=4
$script:HcBrowserToolbarButtons=@()
$script:HcBrowserToolbarItems=@()
$script:HcBrowserAddressBorder=$null
$script:HcBrowserAddressText=$null
$script:HcBrowserFooterText=$null
$script:HcBrowserAuthTimer=$null
$script:HcBrowserAuthRequestId=''
$script:HcBrowserAuthRequest=$null
$script:HcBrowserCompletionProbeBusy=$false
$script:HcBrowserSuppressedRequestId=''
$script:HcBrowserBridgeInitialized=$false
$script:HcBrowserAuthRequestPath=Join-Path $script:DataDir 'browser-auth-request.json'
$script:HcBrowserAuthResultDir=Join-Path $script:DataDir 'BrowserAuth'
$script:HcBrowserReadyPath=Join-Path $script:HcBrowserAuthResultDir 'native-browser.ready.json'

function Test-HcNativeBrowserAvailable {
    $sdk=Join-Path $script:BaseDir 'WebView2'
    return (Test-Path -LiteralPath (Join-Path $sdk 'Microsoft.Web.WebView2.Core.dll') -PathType Leaf) -and
           (Test-Path -LiteralPath (Join-Path $sdk 'Microsoft.Web.WebView2.Wpf.dll') -PathType Leaf) -and
           (Test-Path -LiteralPath (Join-Path $sdk 'WebView2Loader.dll') -PathType Leaf)
}

function Import-HcWebView2 {
    if('Microsoft.Web.WebView2.Wpf.WebView2' -as [type]){return $true}
    $sdk=Join-Path $script:BaseDir 'WebView2'
    $core=Join-Path $sdk 'Microsoft.Web.WebView2.Core.dll'
    $wpf=Join-Path $sdk 'Microsoft.Web.WebView2.Wpf.dll'
    $loader=Join-Path $sdk 'WebView2Loader.dll'
    if(-not (Test-Path -LiteralPath $core) -or -not (Test-Path -LiteralPath $wpf) -or -not (Test-Path -LiteralPath $loader)){return $false}
    try{
        if(-not (($env:PATH -split ';') -contains $sdk)){$env:PATH=$sdk+';'+$env:PATH}
        Add-Type -Path $core -ErrorAction Stop
        Add-Type -Path $wpf -ErrorAction Stop
        return $true
    }catch{
        Write-Log "Native browser SDK load failed: $($_.Exception.Message)" 'ERROR'
        return $false
    }
}

function New-HcBrowserButton {
    param([string]$Id,[string]$Text,[double]$Width=86)
    $button=New-Object System.Windows.Controls.Button
    $button.Tag=$Id;$button.Content=$Text;$button.Width=$Width;$button.Height=44;$button.Margin='0,0,8,0'
    $button.FontSize=14;$button.FontWeight='SemiBold';$button.Foreground='White';$button.Background='#C4162234'
    $button.BorderBrush='#465B76';$button.BorderThickness='1';$button.Cursor='Hand'
    $button.Template=[Windows.Markup.XamlReader]::Parse('<ControlTemplate xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" TargetType="Button"><Border Background="{TemplateBinding Background}" BorderBrush="{TemplateBinding BorderBrush}" BorderThickness="{TemplateBinding BorderThickness}" CornerRadius="11"><ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/></Border></ControlTemplate>')
    $button.Add_Click({param($sender,$eventArgs)try{Invoke-HcBrowserToolbarAction ([string]$sender.Tag)}catch{Write-Log "Browser toolbar action failed: $($_.Exception.Message)" 'WARN'}})
    $button.Add_MouseEnter({
        param($sender,$eventArgs)
        if(-not(Test-HcMouseHoverAllowed)){return}
        for($i=0;$i -lt $script:HcBrowserToolbarItems.Count;$i++){
            if($script:HcBrowserToolbarItems[$i].Control -eq $sender){$script:HcBrowserToolbarIndex=$i;$script:HcBrowserFocusArea='Toolbar';Update-HcBrowserToolbarVisuals;break}
        }
    })
    return $button
}

function Add-HcBrowserToolbarItem {
    param($Control,[string]$Action)
    $script:HcBrowserToolbarItems+=,[pscustomobject]@{Control=$Control;Action=$Action}
    if($Control -is [System.Windows.Controls.Button]){$script:HcBrowserToolbarButtons+=$Control}
}

function Initialize-HuymaierWebBrowser {
    param([switch]$Force)
    if($null -eq $script:Window){return}

    # Provider-auth polling remains lightweight and available at startup while
    # WebView2 assembly/control construction stays deferred until browser use.
    if(-not $script:HcBrowserBridgeInitialized){
        New-Item -ItemType Directory -Force -Path $script:HcBrowserAuthResultDir|Out-Null
        Remove-HcStaleBrowserAuthRequest -Startup
        $script:HcBrowserBridgeInitialized=$true
    }
    if($null -eq $script:HcBrowserAuthTimer){
        $timer=New-Object System.Windows.Threading.DispatcherTimer
        $timer.Interval=[TimeSpan]::FromMilliseconds(250)
        $timer.Add_Tick({try{Poll-HcBrowserAuthRequest}catch{Write-Log "Browser auth bridge: $($_.Exception.Message)" 'WARN'}})
        $timer.Start();$script:HcBrowserAuthTimer=$timer
    }
    if(-not $Force -or $null -ne $script:HcBrowserOverlay){return}

    $root=$script:Window.Content
    if($null -eq $root -or -not ($root -is [System.Windows.Controls.Grid])){return}

    $overlay=New-Object System.Windows.Controls.Grid
    $overlay.Visibility='Collapsed';$overlay.Background='#FF060A12'
    $overlay.RowDefinitions.Add((New-Object System.Windows.Controls.RowDefinition -Property @{Height='76'}))
    $overlay.RowDefinitions.Add((New-Object System.Windows.Controls.RowDefinition -Property @{Height='*'}))
    $overlay.RowDefinitions.Add((New-Object System.Windows.Controls.RowDefinition -Property @{Height='58'}))
    [System.Windows.Controls.Panel]::SetZIndex($overlay,1050)

    $toolbarBorder=New-Object System.Windows.Controls.Border
    $toolbarBorder.Background='#FF0B111C';$toolbarBorder.BorderBrush='#30435D';$toolbarBorder.BorderThickness='0,0,0,1';$toolbarBorder.Padding='18,12'
    [System.Windows.Controls.Grid]::SetRow($toolbarBorder,0);$overlay.Children.Add($toolbarBorder)|Out-Null

    $toolbar=New-Object System.Windows.Controls.Grid
    foreach($width in @('Auto','Auto','Auto','Auto','*','Auto')){$toolbar.ColumnDefinitions.Add((New-Object System.Windows.Controls.ColumnDefinition -Property @{Width=$width}))}
    $toolbarBorder.Child=$toolbar
    $script:HcBrowserToolbarItems=@();$script:HcBrowserToolbarButtons=@()

    $defs=@(@('Back','BACK',82),@('Forward','NEXT',82),@('Reload','RELOAD',92),@('Home','HOME',82))
    for($i=0;$i -lt $defs.Count;$i++){
        $def=$defs[$i];$button=New-HcBrowserButton $def[0] $def[1] ([double]$def[2]);[System.Windows.Controls.Grid]::SetColumn($button,$i);$toolbar.Children.Add($button)|Out-Null;Add-HcBrowserToolbarItem $button ([string]$def[0])
    }

    $address=New-Object System.Windows.Controls.Border
    $address.Margin='10,0,10,0';$address.Padding='16,8';$address.Background='#FF111B29';$address.BorderBrush='#3C526D';$address.BorderThickness='1';$address.CornerRadius=11;$address.Cursor='Hand'
    [System.Windows.Controls.Grid]::SetColumn($address,4);$toolbar.Children.Add($address)|Out-Null
    $addressText=New-Object System.Windows.Controls.TextBlock
    $addressText.Text='Search or enter address';$addressText.Foreground='#D8E2EF';$addressText.FontSize=15;$addressText.TextTrimming='CharacterEllipsis';$addressText.VerticalAlignment='Center';$address.Child=$addressText
    $address.Add_MouseLeftButtonUp({Show-HcBrowserAddressKeyboard})
    $address.Add_MouseEnter({if(Test-HcMouseHoverAllowed){$script:HcBrowserToolbarIndex=4;$script:HcBrowserFocusArea='Toolbar';Update-HcBrowserToolbarVisuals}})
    Add-HcBrowserToolbarItem $address 'Address'

    $close=New-HcBrowserButton 'Close' 'CLOSE' 82;[System.Windows.Controls.Grid]::SetColumn($close,5);$toolbar.Children.Add($close)|Out-Null;Add-HcBrowserToolbarItem $close 'Close'

    $browserHost=New-Object System.Windows.Controls.Grid;$browserHost.Background='#FF11151C';$browserHost.ClipToBounds=$true;[System.Windows.Controls.Grid]::SetRow($browserHost,1);$overlay.Children.Add($browserHost)|Out-Null
    $fallback=New-Object System.Windows.Controls.StackPanel;$fallback.HorizontalAlignment='Center';$fallback.VerticalAlignment='Center';$fallback.MaxWidth=780
    $fallbackTitle=New-Object System.Windows.Controls.TextBlock;$fallbackTitle.Text='Native browser is preparing';$fallbackTitle.FontSize=30;$fallbackTitle.FontWeight='Bold';$fallbackTitle.Foreground='White';$fallbackTitle.TextAlignment='Center';$fallback.Children.Add($fallbackTitle)|Out-Null
    $fallbackText=New-Object System.Windows.Controls.TextBlock;$fallbackText.Text='WebView2 could not be initialized. Re-run the installer while online, then restart Huymaier Console.';$fallbackText.Margin='0,14,0,0';$fallbackText.FontSize=17;$fallbackText.Foreground='#AEBBD0';$fallbackText.TextWrapping='Wrap';$fallbackText.TextAlignment='Center';$fallback.Children.Add($fallbackText)|Out-Null
    $browserHost.Children.Add($fallback)|Out-Null

    $footer=New-Object System.Windows.Controls.Border;$footer.Background='#FF0A101A';$footer.BorderBrush='#30435D';$footer.BorderThickness='0,1,0,0';$footer.Padding='18,11';[System.Windows.Controls.Grid]::SetRow($footer,2);$overlay.Children.Add($footer)|Out-Null
    $footerText=New-Object System.Windows.Controls.TextBlock;$footerText.Foreground='#D4DEEB';$footerText.FontSize=15;$footerText.FontWeight='SemiBold';$footerText.HorizontalAlignment='Center';$footer.Child=$footerText

    $root.Children.Add($overlay)|Out-Null
    $script:HcBrowserOverlay=$overlay;$script:HcBrowserHost=$browserHost;$script:HcBrowserFallback=$fallback
    $script:HcBrowserAddressBorder=$address;$script:HcBrowserAddressText=$addressText;$script:HcBrowserFooterText=$footerText

    if(Import-HcWebView2){
        try{
            $web=New-Object Microsoft.Web.WebView2.Wpf.WebView2
            $web.HorizontalAlignment='Stretch';$web.VerticalAlignment='Stretch'
            $creation=New-Object Microsoft.Web.WebView2.Wpf.CoreWebView2CreationProperties
            $creation.UserDataFolder=Join-Path $script:DataDir 'WebBrowser\UserData';$web.CreationProperties=$creation
            $web.Add_CoreWebView2InitializationCompleted({param($sender,$eventArgs)Initialize-HcBrowserCore $sender $eventArgs})
            $browserHost.Children.Add($web)|Out-Null;$script:HcBrowserWebView=$web;$web.Source=[uri]'about:blank'
        }catch{
            $fallbackTitle.Text='Native browser unavailable';$fallbackText.Text=$_.Exception.Message
            Write-Log "Native browser construction failed: $($_.Exception.Message)" 'ERROR'
        }
    }else{
        $fallbackTitle.Text='Native browser components missing'
        $fallbackText.Text='Re-run the Huymaier Console installer while connected to the internet. It installs the official Microsoft WebView2 components.'
    }
    Update-HcBrowserToolbarVisuals
}

function Initialize-HcBrowserCore {
    param($Sender,$EventArgs)
    if(-not $EventArgs.IsSuccess){$script:HcBrowserFallback.Visibility='Visible';Write-Log "WebView2 initialization failed: $($EventArgs.InitializationException.Message)" 'ERROR';return}
    try{
        $core=$Sender.CoreWebView2
        $core.Settings.AreDefaultContextMenusEnabled=$false;$core.Settings.AreDevToolsEnabled=$false;$core.Settings.IsStatusBarEnabled=$false
        $core.Settings.AreBrowserAcceleratorKeysEnabled=$false;$core.Settings.IsZoomControlEnabled=$false
        try{$core.Settings.IsPasswordAutosaveEnabled=$true}catch{};try{$core.Settings.IsGeneralAutofillEnabled=$true}catch{}
        try{$core.Settings.UserAgent=$core.Settings.UserAgent+' HuymaierConsole/'+$script:AppVersion}catch{}
        $core.Add_NewWindowRequested({param($s,$e)try{$e.Handled=$true;if($e.Uri){$script:HcBrowserWebView.Source=[uri]$e.Uri}}catch{}})
        $core.Add_DocumentTitleChanged({try{Update-HcBrowserAddress}catch{}});$core.Add_HistoryChanged({try{Update-HcBrowserToolbarVisuals}catch{}})
        $Sender.Add_NavigationStarting({param($s,$e)try{$script:HcBrowserAddressText.Text=[string]$e.Uri}catch{}})
        $Sender.Add_NavigationCompleted({param($s,$e)try{Update-HcBrowserAddress;Install-HcBrowserControllerScript;Test-HcBrowserAuthenticationCompletion}catch{Write-Log "Native browser navigation handler: $($_.Exception.Message)" 'WARN'}})
        $script:HcBrowserReady=$true;$script:HcBrowserFallback.Visibility='Collapsed'
        try{$ready=[pscustomobject]@{Pid=$PID;Version=$script:AppVersion;Updated=(Get-Date).ToString('o')};$tmp="$script:HcBrowserReadyPath.tmp";$ready|ConvertTo-Json -Compress|Set-Content -LiteralPath $tmp -Encoding UTF8;Move-Item -LiteralPath $tmp -Destination $script:HcBrowserReadyPath -Force}catch{}
        Write-Log 'Native WebView2 controller browser initialized.'
    }catch{Write-Log "Native browser core setup failed: $($_.Exception.Message)" 'ERROR'}
}

function Update-HcBrowserAddress {
    if($null -eq $script:HcBrowserWebView -or $null -eq $script:HcBrowserAddressText){return}
    try{$url=[string]$script:HcBrowserWebView.Source.AbsoluteUri;if($url -eq 'about:blank'){$url='Search or enter address'};$script:HcBrowserAddressText.Text=$url}catch{}
}

function Get-HcBrowserRequestFromDisk {
    if(-not $script:HcBrowserAuthRequestPath -or -not (Test-Path -LiteralPath $script:HcBrowserAuthRequestPath -PathType Leaf)){return $null}
    try{return Get-Content -Raw -LiteralPath $script:HcBrowserAuthRequestPath|ConvertFrom-Json}catch{return $null}
}
function Test-HcBrowserRequestOwnerAlive {param($Request);if($null -eq $Request){return $false};$workerProcessId=0;try{$workerProcessId=[int]$Request.WorkerPid}catch{};if($workerProcessId -le 0){return $false};try{Get-Process -Id $workerProcessId -ErrorAction Stop|Out-Null;return $true}catch{return $false}}
function Test-HcBrowserRequestExpired {param($Request);if($null -eq $Request){return $true};$createdAt=[datetime]::MinValue;try{$createdAt=[datetime]::Parse([string]$Request.Created,[Globalization.CultureInfo]::InvariantCulture,[Globalization.DateTimeStyles]::RoundtripKind)}catch{return $true};$timeoutSeconds=480;try{$timeoutSeconds=[math]::Max(30,[int]$Request.TimeoutSec)}catch{};return (Get-Date) -gt $createdAt.AddSeconds($timeoutSeconds+30)}

function Remove-HcStaleBrowserAuthRequest {
    param([switch]$Startup)
    $request=Get-HcBrowserRequestFromDisk;if($null -eq $request){return}
    $legacyRequest=$null -eq $request.PSObject.Properties['WorkerPid'];$stale=(Test-HcBrowserRequestExpired $request) -or (-not (Test-HcBrowserRequestOwnerAlive $request));if($Startup -and $legacyRequest){$stale=$true};if(-not $stale){return}
    $requestId=[string]$request.Id;try{Remove-Item -LiteralPath $script:HcBrowserAuthRequestPath -Force -ErrorAction SilentlyContinue}catch{}
    if($requestId){try{Remove-Item -LiteralPath (Get-HcBrowserAuthResultPath $requestId) -Force -ErrorAction SilentlyContinue}catch{}}
    if([string]$script:HcBrowserAuthRequestId -eq $requestId){$script:HcBrowserAuthRequest=$null;$script:HcBrowserAuthRequestId='';$script:HcBrowserCompletionProbeBusy=$false}
    Write-Log "Removed a stale native-browser authorization request${requestId}." 'WARN'
}

function Write-HcBrowserAuthResult {
    param($Request,[string]$Value='',[string]$Error='')
    if($null -eq $Request){return};$requestId=[string]$Request.Id;if(-not $requestId){return}
    $result=[pscustomobject]@{Id=$requestId;Provider=[string]$Request.Provider;Value=$Value;Error=$Error;Completed=(Get-Date).ToString('o')};$path=Get-HcBrowserAuthResultPath $requestId;$tmp="$path.tmp"
    try{$result|ConvertTo-Json -Depth 6|Set-Content -LiteralPath $tmp -Encoding UTF8;Move-Item -LiteralPath $tmp -Destination $path -Force}catch{Write-Log "Unable to write browser authorization result: $($_.Exception.Message)" 'WARN'}
}

function Cancel-HcBrowserAuthentication {
    param([string]$Reason='Sign-in cancelled by user.')
    $request=$script:HcBrowserAuthRequest;if($null -eq $request){$request=Get-HcBrowserRequestFromDisk}
    if($null -ne $request){$requestId=[string]$request.Id;Write-HcBrowserAuthResult -Request $request -Error $Reason;try{Remove-Item -LiteralPath $script:HcBrowserAuthRequestPath -Force -ErrorAction SilentlyContinue}catch{};$script:HcBrowserSuppressedRequestId=$requestId;$script:HcBrowserAuthRequest=$null;$script:HcBrowserAuthRequestId='';$script:HcBrowserCompletionProbeBusy=$false;Write-Log "Native browser authorization cancelled for $([string]$request.Provider)." 'INFO'}
    try{if($null -ne $script:HcBrowserWebView){$script:HcBrowserWebView.Source=[uri]'about:blank'}}catch{};Close-HuymaierBrowser
}

function Set-HcBrowserFocusArea {
    param([ValidateSet('Toolbar','Web')][string]$Area)
    $script:HcBrowserFocusArea=$Area
    if($Area -eq 'Toolbar'){
        if($script:HcBrowserToolbarIndex -lt 0 -or $script:HcBrowserToolbarIndex -ge $script:HcBrowserToolbarItems.Count){$script:HcBrowserToolbarIndex=4}
    }else{try{if($null -ne $script:HcBrowserWebView){$script:HcBrowserWebView.Focus()|Out-Null}}catch{}}
    Update-HcBrowserToolbarVisuals
}

function Update-HcBrowserToolbarVisuals {
    if($null -eq $script:HcBrowserToolbarItems){return}
    for($i=0;$i -lt $script:HcBrowserToolbarItems.Count;$i++){
        $control=$script:HcBrowserToolbarItems[$i].Control;$active=$script:HcBrowserActive -and $script:HcBrowserFocusArea -eq 'Toolbar' -and $i -eq $script:HcBrowserToolbarIndex
        try{$control.BorderBrush=$(if($active){'#FFF0CC58'}else{'#465B76'});$control.BorderThickness=$(if($active){'3'}else{'1'});$control.Background=$(if($active){'#FF25344A'}else{'#C4162234'})}catch{}
    }
    if($null -ne $script:HcBrowserFooterText){
        $script:HcBrowserFooterText.Text=$(if($script:HcBrowserFocusArea -eq 'Toolbar'){'TOP BAR   ←/→ Move    A Select    X Type    ↓ Web    Y Web    B Back    GUIDE Main Menu'}else{'WEB   D-PAD Navigate    A Select    X Type    Y Top Bar    B Back    LB/RB History    GUIDE Main Menu'})
    }
}

function ConvertTo-HcBrowserDestination {
    param([string]$Text)
    $value=([string]$Text).Trim();if([string]::IsNullOrWhiteSpace($value)){return 'https://www.google.com'}
    if($value -match '^[a-zA-Z][a-zA-Z0-9+.-]*://'){return $value}
    if($value -match '^(localhost|[^\s/]+\.[^\s/]+)(/.*)?$'){return 'https://'+$value}
    return 'https://www.google.com/search?q='+[uri]::EscapeDataString($value)
}

function Open-HuymaierBrowser {
    param([string]$Url='https://www.google.com',[string]$Title='Web')
    Initialize-HuymaierWebBrowser -Force;if($null -eq $script:HcBrowserOverlay){return}
    $Url=ConvertTo-HcBrowserDestination $Url
    $script:HcBrowserActive=$true;$script:HcBrowserToolbarIndex=4;$script:HcBrowserOverlay.Visibility='Visible';Set-HcBrowserFocusArea 'Toolbar'
    try{if($Title){$script:HcBrowserFooterText.ToolTip=$Title}}catch{};try{Stop-PlatformBackgroundAnimations}catch{}
    try{if($null -ne $script:HcBrowserWebView){$script:HcBrowserWebView.Visibility='Visible';$script:HcBrowserWebView.Source=[uri]$Url}}catch{Set-ConsoleNotice "Unable to open the native browser: $($_.Exception.Message)" 'ERROR'}
    Update-HcBrowserToolbarVisuals;Update-Footer
}
function Close-HuymaierBrowser {if(-not $script:HcBrowserActive){return};$script:HcBrowserActive=$false;$script:HcBrowserOverlay.Visibility='Collapsed';$script:HcBrowserFocusArea='Web';try{if($null -ne $script:HcBrowserWebView){$script:HcBrowserWebView.Visibility='Visible'}}catch{};Update-HcBrowserToolbarVisuals;Update-Footer}

function Invoke-HcBrowserToolbarAction {
    param([string]$Action)
    if($Action -eq 'Address'){Show-HcBrowserAddressKeyboard;return}
    if($Action -eq 'Close'){if($null -ne $script:HcBrowserAuthRequest -or (Test-Path -LiteralPath $script:HcBrowserAuthRequestPath -PathType Leaf)){Cancel-HcBrowserAuthentication}else{Close-HuymaierBrowser};return}
    if($null -eq $script:HcBrowserWebView){return}
    switch($Action){
        'Back' {try{if($script:HcBrowserWebView.CanGoBack){$script:HcBrowserWebView.GoBack()}elseif($null -ne $script:HcBrowserAuthRequest -or (Test-Path -LiteralPath $script:HcBrowserAuthRequestPath -PathType Leaf)){Cancel-HcBrowserAuthentication}else{Close-HuymaierBrowser}}catch{Write-Log "Browser back action failed: $($_.Exception.Message)" 'WARN'}}
        'Forward' {try{if($script:HcBrowserWebView.CanGoForward){$script:HcBrowserWebView.GoForward()}}catch{}}
        'Reload' {try{$script:HcBrowserWebView.Reload()}catch{}}
        'Home' {Open-HuymaierBrowser 'https://www.google.com' 'Web'}
    }
}

function Show-HcBrowserAddressKeyboard {
    if(-not $script:HcBrowserActive){return};$current='';try{$current=[string]$script:HcBrowserWebView.Source.AbsoluteUri}catch{};if($current -eq 'about:blank'){$current=''}
    try{$script:HcBrowserWebView.Visibility='Collapsed'}catch{}
    Show-NativeKeyboard -Title 'Search or enter address' -InitialText $current -Mode 'BrowserAddress' -Context $null
}

function Invoke-HcBrowserScriptAsync {
    param([string]$Script,[scriptblock]$Completed=$null)
    if(-not $script:HcBrowserReady -or $null -eq $script:HcBrowserWebView -or $null -eq $script:HcBrowserWebView.CoreWebView2){return}
    try{$operation=$script:HcBrowserWebView.ExecuteScriptAsync($Script);if($null -eq $Completed){return};$callback=$Completed;$timer=New-Object System.Windows.Threading.DispatcherTimer;$timer.Interval=[TimeSpan]::FromMilliseconds(35);$tick={if($null -eq $operation -or -not $operation.IsCompleted){return};$timer.Stop();try{& $callback ([string]$operation.Result)}catch{Write-Log "Browser script callback: $($_.Exception.Message)" 'WARN'}}.GetNewClosure();$timer.Add_Tick($tick);$timer.Start()}catch{Write-Log "Browser script execution failed: $($_.Exception.Message)" 'WARN'}
}

function Install-HcBrowserControllerScript {
    $scriptText=@'
(()=>{if(window.__hcControllerInstalled)return;window.__hcControllerInstalled=true;
const style=document.createElement('style');style.id='hc-controller-style';style.textContent=`.hc-controller-focus{outline:4px solid #f0cc58!important;outline-offset:3px!important;box-shadow:0 0 0 5px rgba(0,0,0,.65),0 0 22px rgba(240,204,88,.7)!important}`;document.documentElement.appendChild(style);
const editable=e=>!!e&&(['input','textarea','select'].includes((e.tagName||'').toLowerCase())||e.isContentEditable);
window.__hcElements=()=>Array.from(document.querySelectorAll('a[href],button,input,textarea,select,[contenteditable="true"],[role="button"],[role="link"],[tabindex]')).filter(e=>{const r=e.getBoundingClientRect(),s=getComputedStyle(e);return r.width>4&&r.height>4&&s.visibility!=='hidden'&&s.display!=='none'&&!e.disabled});
window.__hcCurrent=()=>document.querySelector('.hc-controller-focus');
window.__hcSet=e=>{document.querySelectorAll('.hc-controller-focus').forEach(x=>x.classList.remove('hc-controller-focus'));if(e){e.classList.add('hc-controller-focus');try{e.focus({preventScroll:true})}catch{e.focus()}e.scrollIntoView({block:'center',inline:'nearest',behavior:'smooth'});}return !!e};
document.addEventListener('focusin',e=>{if(window.__hcElements().includes(e.target))window.__hcSet(e.target)},true);
window.__hcMove=d=>{const els=window.__hcElements();if(!els.length){window.scrollBy({top:d==='Down'?innerHeight*.72:d==='Up'?-innerHeight*.72:0,left:d==='Right'?innerWidth*.72:d==='Left'?-innerWidth*.72:0,behavior:'smooth'});return false;}let cur=window.__hcCurrent();if(!cur||!els.includes(cur)){const active=document.activeElement;if(active&&els.includes(active))cur=active;else return window.__hcSet(els[0]);}const a=cur.getBoundingClientRect(),ax=a.left+a.width/2,ay=a.top+a.height/2;let best=null,score=1e18;for(const e of els){if(e===cur)continue;const r=e.getBoundingClientRect(),x=r.left+r.width/2,y=r.top+r.height/2,dx=x-ax,dy=y-ay;if((d==='Left'&&dx>=-4)||(d==='Right'&&dx<=4)||(d==='Up'&&dy>=-4)||(d==='Down'&&dy<=4))continue;const main=(d==='Left'||d==='Right')?Math.abs(dx):Math.abs(dy),cross=(d==='Left'||d==='Right')?Math.abs(dy):Math.abs(dx),s=main+cross*2.15;if(s<score){score=s;best=e;}}if(best)return window.__hcSet(best);window.scrollBy({top:d==='Down'?innerHeight*.72:d==='Up'?-innerHeight*.72:0,left:d==='Right'?innerWidth*.72:d==='Left'?-innerWidth*.72:0,behavior:'smooth'});return false};
window.__hcActivate=()=>{let e=window.__hcCurrent()||document.activeElement;if(!e)return {editable:false};if(editable(e)){window.__hcSet(e);return {editable:true,value:e.value||e.innerText||'',inputType:e.type||'text'};}e.click();return {editable:false};};
window.__hcInput=()=>{let e=window.__hcCurrent()||document.activeElement;if(!e||!editable(e))return {editable:false};window.__hcSet(e);return {editable:true,value:e.value||e.innerText||'',inputType:e.type||'text'};};
window.__hcSetValue=v=>{let e=window.__hcCurrent()||document.activeElement;if(!e||!editable(e))return false;if(e.isContentEditable)e.innerText=v;else e.value=v;e.dispatchEvent(new Event('input',{bubbles:true}));e.dispatchEvent(new Event('change',{bubbles:true}));e.focus();return true};
})();
'@
    Invoke-HcBrowserScriptAsync $scriptText
}

function ConvertFrom-HcBrowserJsonString {param([string]$Json);if([string]::IsNullOrWhiteSpace($Json)){return ''};try{return [string]($Json|ConvertFrom-Json)}catch{return $Json.Trim('"')}}

function Open-HcBrowserEditableKeyboard {
    param([bool]$AddressFallback=$false)
    $fallbackToAddress=[bool]$AddressFallback;$js=$(if($fallbackToAddress){'JSON.stringify(window.__hcInput?window.__hcInput():{editable:false})'}else{'JSON.stringify(window.__hcActivate?window.__hcActivate():{editable:false})'})
    $completed={param($raw);try{$json=ConvertFrom-HcBrowserJsonString $raw;$info=$null;try{$info=$json|ConvertFrom-Json}catch{};if($null -ne $info -and [bool]$info.editable){try{$script:HcBrowserWebView.Visibility='Collapsed'}catch{};$secure=([string]$info.inputType -eq 'password');Show-NativeKeyboard -Title $(if($secure){'Enter password'}else{'Enter text'}) -InitialText $(if($secure){''}else{[string]$info.value}) -Mode $(if($secure){'BrowserInputSecure'}else{'BrowserInput'}) -Context $null}elseif($fallbackToAddress){Show-HcBrowserAddressKeyboard}}catch{Write-Log "Browser text-entry callback failed: $($_.Exception.Message)" 'WARN';if($fallbackToAddress){try{Show-HcBrowserAddressKeyboard}catch{}}}}.GetNewClosure()
    Invoke-HcBrowserScriptAsync $js $completed
}
function Set-HcBrowserInputValue {param([string]$Value);$encoded=ConvertTo-Json -InputObject $Value -Compress;try{$script:HcBrowserWebView.Visibility='Visible'}catch{};Invoke-HcBrowserScriptAsync "window.__hcSetValue?window.__hcSetValue($encoded):false"}
function Navigate-HcBrowser {param([string]$Direction);$safe=$Direction -replace "'",'';Invoke-HcBrowserScriptAsync "window.__hcMove?window.__hcMove('$safe'):false"}

function Invoke-HcBrowserControllerType {
    if($script:HcBrowserFocusArea -eq 'Toolbar'){if($script:HcBrowserToolbarIndex -eq 4){Show-HcBrowserAddressKeyboard}else{Show-HcBrowserAddressKeyboard};return}
    Open-HcBrowserEditableKeyboard $true
}

function Handle-HcBrowserController {
    param([int]$Mask,[string]$Direction)
    if(-not $script:HcBrowserActive){return $false};if((Get-Command Test-HcMainMenuVisible -ErrorAction SilentlyContinue) -and (Test-HcMainMenuVisible)){return $false}
    $now=Get-Date
    if($Direction){
        if($Direction -ne $script:LastDirection -or $now -ge $script:NextDirectionAt){
            if($script:HcBrowserFocusArea -eq 'Toolbar'){
                switch($Direction){
                    'Left' {$script:HcBrowserToolbarIndex=($script:HcBrowserToolbarIndex-1+$script:HcBrowserToolbarItems.Count)%$script:HcBrowserToolbarItems.Count}
                    'Right'{$script:HcBrowserToolbarIndex=($script:HcBrowserToolbarIndex+1)%$script:HcBrowserToolbarItems.Count}
                    'Down' {Set-HcBrowserFocusArea 'Web'}
                    'Up'   {}
                }
                Update-HcBrowserToolbarVisuals
            }else{Navigate-HcBrowser $Direction}
            $script:LastDirection=$Direction;$script:NextDirectionAt=$now.AddMilliseconds(190)
        }
    }else{$script:LastDirection='';$script:NextDirectionAt=[datetime]::MinValue}

    if(Is-NewButtonPress $Mask 4){if($script:HcBrowserFocusArea -eq 'Toolbar'){if($script:HcBrowserToolbarItems.Count -gt 0){Invoke-HcBrowserToolbarAction ([string]$script:HcBrowserToolbarItems[$script:HcBrowserToolbarIndex].Action)}}else{Open-HcBrowserEditableKeyboard}}
    if(Is-NewButtonPress $Mask 8){Invoke-HcBrowserToolbarAction 'Back'}
    if(Is-NewButtonPress $Mask 16){Invoke-HcBrowserControllerType}
    if(Is-NewButtonPress $Mask 32){if($script:HcBrowserFocusArea -eq 'Toolbar'){Set-HcBrowserFocusArea 'Web'}else{$script:HcBrowserToolbarIndex=4;Set-HcBrowserFocusArea 'Toolbar'}}
    if(Is-NewButtonPress $Mask 1024){Invoke-HcBrowserToolbarAction 'Back'}
    if(Is-NewButtonPress $Mask 2048){Invoke-HcBrowserToolbarAction 'Forward'}
    if(Is-NewButtonPress $Mask 1){$script:HcBrowserToolbarIndex=4;Set-HcBrowserFocusArea 'Toolbar'}
    if(Is-NewButtonPress $Mask 2){if(Get-Command Show-HcMainMenu -ErrorAction SilentlyContinue){Show-HcMainMenu}}
    $script:LastGamepadMask=$Mask;return $true
}

function Handle-HcBrowserKey {
    param($Key)
    if(-not $script:HcBrowserActive){return $false};if((Get-Command Test-HcMainMenuVisible -ErrorAction SilentlyContinue) -and (Test-HcMainMenuVisible)){return $false}
    switch([string]$Key){
        'Left'{if($script:HcBrowserFocusArea -eq 'Toolbar'){$script:HcBrowserToolbarIndex=($script:HcBrowserToolbarIndex-1+$script:HcBrowserToolbarItems.Count)%$script:HcBrowserToolbarItems.Count;Update-HcBrowserToolbarVisuals}else{Navigate-HcBrowser 'Left'}}
        'Right'{if($script:HcBrowserFocusArea -eq 'Toolbar'){$script:HcBrowserToolbarIndex=($script:HcBrowserToolbarIndex+1)%$script:HcBrowserToolbarItems.Count;Update-HcBrowserToolbarVisuals}else{Navigate-HcBrowser 'Right'}}
        'Up'{if($script:HcBrowserFocusArea -eq 'Web'){Navigate-HcBrowser 'Up'}}
        'Down'{if($script:HcBrowserFocusArea -eq 'Toolbar'){Set-HcBrowserFocusArea 'Web'}else{Navigate-HcBrowser 'Down'}}
        'Enter'{if($script:HcBrowserFocusArea -eq 'Toolbar'){Invoke-HcBrowserToolbarAction ([string]$script:HcBrowserToolbarItems[$script:HcBrowserToolbarIndex].Action)}else{Open-HcBrowserEditableKeyboard}}
        'Space'{Open-HcBrowserEditableKeyboard}'X'{Invoke-HcBrowserControllerType}
        'Escape'{Invoke-HcBrowserToolbarAction 'Back'}'Back'{Invoke-HcBrowserToolbarAction 'Back'}
        'F6'{Show-HcBrowserAddressKeyboard}'F5'{Invoke-HcBrowserToolbarAction 'Reload'}
        'F1'{if(Get-Command Show-HcMainMenu -ErrorAction SilentlyContinue){Show-HcMainMenu}}
        default{return $false}
    };return $true
}

function Get-HcBrowserAuthResultPath {param([string]$Id);return Join-Path $script:HcBrowserAuthResultDir ("result-"+$Id+'.json')}
function Poll-HcBrowserAuthRequest {
    if(-not (Test-Path -LiteralPath $script:HcBrowserAuthRequestPath -PathType Leaf)){if($null -ne $script:HcBrowserAuthRequest){$script:HcBrowserAuthRequest=$null;$script:HcBrowserAuthRequestId='';$script:HcBrowserCompletionProbeBusy=$false};return}
    $request=Get-HcBrowserRequestFromDisk;if($null -eq $request){return};if((Test-HcBrowserRequestExpired $request) -or (-not (Test-HcBrowserRequestOwnerAlive $request))){Remove-HcStaleBrowserAuthRequest;if($script:HcBrowserActive){Close-HuymaierBrowser};return}
    $requestId=[string]$request.Id;if(-not $requestId -or $requestId -eq [string]$script:HcBrowserSuppressedRequestId -or $requestId -eq $script:HcBrowserAuthRequestId){return}
    $script:HcBrowserAuthRequestId=$requestId;$script:HcBrowserAuthRequest=$request;$script:HcBrowserCompletionProbeBusy=$false;$title=[string]$request.Title;if(-not $title){$title='Account sign-in'};Open-HuymaierBrowser ([string]$request.Url) $title;Write-Log "Native browser opened for $([string]$request.Provider) authentication."
}
function Complete-HcBrowserAuthentication {param([string]$Value,[string]$Error='');if($null -eq $script:HcBrowserAuthRequest){return};Write-HcBrowserAuthResult -Request $script:HcBrowserAuthRequest -Value $Value -Error $Error;try{Remove-Item -LiteralPath $script:HcBrowserAuthRequestPath -Force -ErrorAction SilentlyContinue}catch{};$script:HcBrowserAuthRequest=$null;$script:HcBrowserAuthRequestId='';$script:HcBrowserCompletionProbeBusy=$false;Close-HuymaierBrowser}
function Test-HcBrowserAuthenticationCompletion {
    if($null -eq $script:HcBrowserAuthRequest -or $null -eq $script:HcBrowserWebView){return};$type=[string]$script:HcBrowserAuthRequest.Completion;$url='';try{$url=[string]$script:HcBrowserWebView.Source.AbsoluteUri}catch{}
    if($type -eq 'Callback'){$prefix=[string]$script:HcBrowserAuthRequest.CallbackPrefix;if($prefix -and $url.StartsWith($prefix,[StringComparison]::OrdinalIgnoreCase)){Complete-HcBrowserAuthentication 'callback';return}}
    if($type -eq 'UrlCode' -and $url -match '[?&]code=([^&#]+)'){Complete-HcBrowserAuthentication ([uri]::UnescapeDataString([string]$matches[1]));return}
    if($type -eq 'AmazonAuthorizationCode' -and $url -match '[?&]openid\.oa2\.authorization_code=([^&#]+)'){Complete-HcBrowserAuthentication ([uri]::UnescapeDataString([string]$matches[1]));return}
    if($type -eq 'EpicAuthorizationCode' -and -not $script:HcBrowserCompletionProbeBusy){$script:HcBrowserCompletionProbeBusy=$true;Invoke-HcBrowserScriptAsync '(document.body&&document.body.innerText)||""' {param($raw);try{$text=ConvertFrom-HcBrowserJsonString $raw;$code='';try{$obj=$text|ConvertFrom-Json;$code=[string]$obj.authorizationCode}catch{if($text -match '"authorizationCode"\s*:\s*"([^"]+)"'){$code=[string]$matches[1]}};if($code){Complete-HcBrowserAuthentication $code}}finally{$script:HcBrowserCompletionProbeBusy=$false}}}
}

function Stop-HuymaierWebBrowser {
    try{if($null -ne $script:HcBrowserAuthTimer){$script:HcBrowserAuthTimer.Stop()}}catch{}
    try{if($null -ne $script:HcBrowserAuthRequest -or (Test-Path -LiteralPath $script:HcBrowserAuthRequestPath -PathType Leaf)){$request=$script:HcBrowserAuthRequest;if($null -eq $request){$request=Get-HcBrowserRequestFromDisk};if($null -ne $request){Write-HcBrowserAuthResult -Request $request -Error 'Huymaier Console closed before sign-in completed.'};Remove-Item -LiteralPath $script:HcBrowserAuthRequestPath -Force -ErrorAction SilentlyContinue}}catch{}
    try{if($script:HcBrowserReadyPath -and (Test-Path -LiteralPath $script:HcBrowserReadyPath -PathType Leaf)){Remove-Item -LiteralPath $script:HcBrowserReadyPath -Force -ErrorAction SilentlyContinue}}catch{}
    try{if($null -ne $script:HcBrowserWebView){$script:HcBrowserWebView.Dispose()}}catch{};$script:HcBrowserReady=$false
}
