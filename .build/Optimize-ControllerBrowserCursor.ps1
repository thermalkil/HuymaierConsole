param(
    [Parameter(Mandatory=$true)][string]$BrowserPath
)

Set-StrictMode -Version 2.0
$ErrorActionPreference='Stop'

if(-not(Test-Path -LiteralPath $BrowserPath -PathType Leaf)){throw "Browser source is missing: $BrowserPath"}
$text=Get-Content -Raw -LiteralPath $BrowserPath -Encoding UTF8
if($text -match 'HUYMAIER_BROWSER_VIRTUAL_CURSOR_V1'){return}

$override=@'

# HUYMAIER_BROWSER_VIRTUAL_CURSOR_V1
# Websites do not expose a consistent keyboard-focus graph.  Use a visible
# console-style pointer over the page instead: directional/left-stick input
# moves it, A/Cross clicks, and X/Square requests text entry at the pointer.
function Install-HcBrowserVirtualCursorScript {
    $scriptText=@'
(()=>{
if(window.__hcVirtualCursorInstalled){if(window.__hcCursorShow)window.__hcCursorShow();return;}
window.__hcVirtualCursorInstalled=true;
const editable=e=>!!e&&(['input','textarea','select'].includes((e.tagName||'').toLowerCase())||e.isContentEditable);
const style=document.createElement('style');
style.id='hc-virtual-cursor-style';
style.textContent='#hc-virtual-cursor{position:fixed;left:50%;top:50%;width:30px;height:30px;margin:-15px 0 0 -15px;border:3px solid #f0cc58;border-radius:50%;background:rgba(12,20,32,.26);box-shadow:0 0 0 2px rgba(0,0,0,.72),0 0 18px rgba(240,204,88,.95);z-index:2147483647;pointer-events:none;transform:translate3d(0,0,0);transition:none!important}#hc-virtual-cursor:after{content:"";position:absolute;left:11px;top:11px;width:5px;height:5px;border-radius:50%;background:#fff3a6;box-shadow:0 0 5px #fff}';
(document.head||document.documentElement).appendChild(style);
const c=document.createElement('div');c.id='hc-virtual-cursor';(document.body||document.documentElement).appendChild(c);
window.__hcCursor={x:Math.round(innerWidth*.5),y:Math.round(innerHeight*.5)};
window.__hcCursorClamp=()=>{window.__hcCursor.x=Math.max(4,Math.min(innerWidth-5,window.__hcCursor.x));window.__hcCursor.y=Math.max(4,Math.min(innerHeight-5,window.__hcCursor.y));};
window.__hcCursorRender=()=>{window.__hcCursorClamp();const n=document.getElementById('hc-virtual-cursor');if(n){n.style.left=window.__hcCursor.x+'px';n.style.top=window.__hcCursor.y+'px';n.style.display='block';}};
window.__hcCursorShow=()=>window.__hcCursorRender();
window.__hcCursorHide=()=>{const n=document.getElementById('hc-virtual-cursor');if(n)n.style.display='none';};
window.__hcCursorMove=(dx,dy)=>{window.__hcCursor.x+=dx;window.__hcCursor.y+=dy;window.__hcCursorRender();return true;};
window.__hcCursorElement=()=>{const n=document.getElementById('hc-virtual-cursor');if(n)n.style.display='none';const e=document.elementFromPoint(window.__hcCursor.x,window.__hcCursor.y);if(n)n.style.display='block';return e;};
window.__hcCursorDescribe=e=>{if(!e)return {editable:false};const isEdit=editable(e);return {editable:isEdit,value:isEdit?(e.value||e.innerText||''):'',inputType:(e.type||'text'),tag:(e.tagName||'').toLowerCase()};};
window.__hcCursorClick=()=>{let e=window.__hcCursorElement();if(!e)return {editable:false};try{e.focus({preventScroll:true})}catch(_){try{e.focus()}catch(__){}}const info=window.__hcCursorDescribe(e);if(info.editable)return info;try{e.click()}catch(_){}return info;};
window.__hcCursorInput=()=>{let e=window.__hcCursorElement();if(!editable(e))e=document.activeElement;if(!editable(e))return {editable:false};try{e.focus({preventScroll:true})}catch(_){try{e.focus()}catch(__){}}return window.__hcCursorDescribe(e);};
window.__hcCursorSetValue=v=>{let e=window.__hcCursorElement();if(!editable(e))e=document.activeElement;if(!editable(e))return false;if(e.isContentEditable)e.innerText=v;else e.value=v;e.dispatchEvent(new Event('input',{bubbles:true}));e.dispatchEvent(new Event('change',{bubbles:true}));try{e.focus()}catch(_){}return true;};
window.__hcCursorScroll=(dx,dy)=>{window.scrollBy({left:dx,top:dy,behavior:'auto'});window.__hcCursorRender();return true;};
window.addEventListener('resize',window.__hcCursorRender,{passive:true});
window.__hcCursorRender();
})();
'@
    Invoke-HcBrowserScriptAsync $scriptText
}

function Show-HcBrowserVirtualCursor {
    if(-not $script:HcBrowserActive){return}
    Install-HcBrowserVirtualCursorScript
    Invoke-HcBrowserScriptAsync 'window.__hcCursorShow?window.__hcCursorShow():false'
}

function Hide-HcBrowserVirtualCursor {
    if(-not $script:HcBrowserReady){return}
    Invoke-HcBrowserScriptAsync 'window.__hcCursorHide?window.__hcCursorHide():false'
}

function Move-HcBrowserVirtualCursor {
    param([string]$Direction)
    Install-HcBrowserVirtualCursorScript
    $step=44
    switch($Direction){
        'Left'  {Invoke-HcBrowserScriptAsync "window.__hcCursorMove?window.__hcCursorMove(-$step,0):false"}
        'Right' {Invoke-HcBrowserScriptAsync "window.__hcCursorMove?window.__hcCursorMove($step,0):false"}
        'Up'    {Invoke-HcBrowserScriptAsync "window.__hcCursorMove?window.__hcCursorMove(0,-$step):false"}
        'Down'  {Invoke-HcBrowserScriptAsync "window.__hcCursorMove?window.__hcCursorMove(0,$step):false"}
    }
}

function Open-HcBrowserCursorKeyboard {
    param([bool]$ClickFirst=$false,[bool]$AddressFallback=$true)
    Install-HcBrowserVirtualCursorScript
    $js=if($ClickFirst){'JSON.stringify(window.__hcCursorClick?window.__hcCursorClick():{editable:false})'}else{'JSON.stringify(window.__hcCursorInput?window.__hcCursorInput():{editable:false})'}
    $fallback=[bool]$AddressFallback
    $completed={
        param($raw)
        try{
            $json=ConvertFrom-HcBrowserJsonString $raw
            $info=$null
            try{$info=$json|ConvertFrom-Json}catch{}
            if($null -ne $info -and [bool]$info.editable){
                try{$script:HcBrowserWebView.Visibility='Collapsed'}catch{}
                $secure=[string]$info.inputType -eq 'password'
                $title=if($secure){'Enter password'}else{'Enter text'}
                $initial=if($secure){''}else{[string]$info.value}
                $mode=if($secure){'BrowserInputSecure'}else{'BrowserInput'}
                Show-NativeKeyboard -Title $title -InitialText $initial -Mode $mode -Context $null
            }elseif($fallback){
                Show-HcBrowserAddressKeyboard
            }
        }catch{
            Write-Log "Browser cursor text-entry callback failed: $($_.Exception.Message)" 'WARN'
            if($fallback){try{Show-HcBrowserAddressKeyboard}catch{}}
        }
    }.GetNewClosure()
    Invoke-HcBrowserScriptAsync $js $completed
}

function Set-HcBrowserInputValue {
    param([string]$Value)
    $encoded=ConvertTo-Json -InputObject $Value -Compress
    try{$script:HcBrowserWebView.Visibility='Visible'}catch{}
    Install-HcBrowserVirtualCursorScript
    Invoke-HcBrowserScriptAsync "window.__hcCursorSetValue?window.__hcCursorSetValue($encoded):(window.__hcSetValue?window.__hcSetValue($encoded):false)"
}

function Navigate-HcBrowser {
    param([string]$Direction)
    Move-HcBrowserVirtualCursor $Direction
}

function Invoke-HcBrowserControllerType {
    if($script:HcBrowserFocusArea -eq 'Toolbar'){
        Show-HcBrowserAddressKeyboard
        return
    }
    Open-HcBrowserCursorKeyboard $false $true
}

function Set-HcBrowserFocusArea {
    param([ValidateSet('Toolbar','Web')][string]$Area)
    $script:HcBrowserFocusArea=$Area
    if($Area -eq 'Toolbar'){
        if($script:HcBrowserToolbarIndex -lt 0 -or $script:HcBrowserToolbarIndex -ge $script:HcBrowserToolbarItems.Count){$script:HcBrowserToolbarIndex=4}
        Hide-HcBrowserVirtualCursor
    }else{
        try{if($null -ne $script:HcBrowserWebView){$script:HcBrowserWebView.Focus()|Out-Null}}catch{}
        Show-HcBrowserVirtualCursor
    }
    Update-HcBrowserToolbarVisuals
}

function Update-HcBrowserToolbarVisuals {
    if($null -eq $script:HcBrowserToolbarItems){return}
    for($i=0;$i -lt $script:HcBrowserToolbarItems.Count;$i++){
        $control=$script:HcBrowserToolbarItems[$i].Control
        $active=$script:HcBrowserActive -and $script:HcBrowserFocusArea -eq 'Toolbar' -and $i -eq $script:HcBrowserToolbarIndex
        try{
            if($active){$control.BorderBrush='#FFF0CC58';$control.BorderThickness='3';$control.Background='#FF25344A'}
            else{$control.BorderBrush='#465B76';$control.BorderThickness='1';$control.Background='#C4162234'}
        }catch{}
    }
    if($null -ne $script:HcBrowserFooterText){
        if($script:HcBrowserFocusArea -eq 'Toolbar'){$script:HcBrowserFooterText.Text='TOP BAR   Left/Right Move    A Select    X Type    Down Web    Y Web    B Back    GUIDE Main Menu'}
        else{$script:HcBrowserFooterText.Text='WEB CURSOR   D-PAD / LEFT STICK Move    A Click / Type    X Keyboard    Y Top Bar    B Back    LB/RB History    GUIDE Main Menu'}
    }
}

function Handle-HcBrowserController {
    param([int]$Mask,[string]$Direction)
    if(-not $script:HcBrowserActive){return $false}
    if((Get-Command Test-HcMainMenuVisible -ErrorAction SilentlyContinue) -and (Test-HcMainMenuVisible)){return $false}
    $now=Get-Date
    if($Direction){
        if($Direction -ne $script:LastDirection -or $now -ge $script:NextDirectionAt){
            if($script:HcBrowserFocusArea -eq 'Toolbar'){
                switch($Direction){
                    'Left' {$script:HcBrowserToolbarIndex--;if($script:HcBrowserToolbarIndex -lt 0){$script:HcBrowserToolbarIndex=$script:HcBrowserToolbarItems.Count-1}}
                    'Right' {$script:HcBrowserToolbarIndex++;if($script:HcBrowserToolbarIndex -ge $script:HcBrowserToolbarItems.Count){$script:HcBrowserToolbarIndex=0}}
                    'Down' {Set-HcBrowserFocusArea 'Web'}
                }
                Update-HcBrowserToolbarVisuals
            }else{
                Move-HcBrowserVirtualCursor $Direction
            }
            $isNew=($Direction -ne $script:LastDirection)
            $script:LastDirection=$Direction
            $script:NextDirectionAt=$now.AddMilliseconds($(if($isNew){110}else{42}))
        }
    }else{$script:LastDirection='';$script:NextDirectionAt=[datetime]::MinValue}

    if(Is-NewButtonPress $Mask 4){
        if($script:HcBrowserFocusArea -eq 'Toolbar'){
            if($script:HcBrowserToolbarItems.Count -gt 0){Invoke-HcBrowserToolbarAction ([string]$script:HcBrowserToolbarItems[$script:HcBrowserToolbarIndex].Action)}
        }else{
            # A real pointer click is used first.  If the hit target is editable,
            # open Huymaier's keyboard immediately (Google and SPA search boxes).
            Open-HcBrowserCursorKeyboard $true $false
        }
    }
    if(Is-NewButtonPress $Mask 8){Invoke-HcBrowserToolbarAction 'Back'}
    if(Is-NewButtonPress $Mask 16){Invoke-HcBrowserControllerType}
    if(Is-NewButtonPress $Mask 32){if($script:HcBrowserFocusArea -eq 'Toolbar'){Set-HcBrowserFocusArea 'Web'}else{$script:HcBrowserToolbarIndex=4;Set-HcBrowserFocusArea 'Toolbar'}}
    if(Is-NewButtonPress $Mask 1024){Invoke-HcBrowserToolbarAction 'Back'}
    if(Is-NewButtonPress $Mask 2048){Invoke-HcBrowserToolbarAction 'Forward'}
    if(Is-NewButtonPress $Mask 1){$script:HcBrowserToolbarIndex=4;Set-HcBrowserFocusArea 'Toolbar'}
    if(Is-NewButtonPress $Mask 2){if(Get-Command Show-HcMainMenu -ErrorAction SilentlyContinue){Show-HcMainMenu}}
    $script:LastGamepadMask=$Mask
    return $true
}

function Handle-HcBrowserKey {
    param($Key)
    if(-not $script:HcBrowserActive){return $false}
    if((Get-Command Test-HcMainMenuVisible -ErrorAction SilentlyContinue) -and (Test-HcMainMenuVisible)){return $false}
    switch([string]$Key){
        'Left' {if($script:HcBrowserFocusArea -eq 'Toolbar'){$script:HcBrowserToolbarIndex--;if($script:HcBrowserToolbarIndex -lt 0){$script:HcBrowserToolbarIndex=$script:HcBrowserToolbarItems.Count-1};Update-HcBrowserToolbarVisuals}else{Move-HcBrowserVirtualCursor 'Left'}}
        'Right' {if($script:HcBrowserFocusArea -eq 'Toolbar'){$script:HcBrowserToolbarIndex++;if($script:HcBrowserToolbarIndex -ge $script:HcBrowserToolbarItems.Count){$script:HcBrowserToolbarIndex=0};Update-HcBrowserToolbarVisuals}else{Move-HcBrowserVirtualCursor 'Right'}}
        'Up' {if($script:HcBrowserFocusArea -eq 'Web'){Move-HcBrowserVirtualCursor 'Up'}}
        'Down' {if($script:HcBrowserFocusArea -eq 'Toolbar'){Set-HcBrowserFocusArea 'Web'}else{Move-HcBrowserVirtualCursor 'Down'}}
        'Enter' {if($script:HcBrowserFocusArea -eq 'Toolbar'){Invoke-HcBrowserToolbarAction ([string]$script:HcBrowserToolbarItems[$script:HcBrowserToolbarIndex].Action)}else{Open-HcBrowserCursorKeyboard $true $false}}
        'Space' {Open-HcBrowserCursorKeyboard $true $false}
        'X' {Invoke-HcBrowserControllerType}
        'Escape' {Invoke-HcBrowserToolbarAction 'Back'}
        'Back' {Invoke-HcBrowserToolbarAction 'Back'}
        'F6' {Show-HcBrowserAddressKeyboard}
        'F5' {Invoke-HcBrowserToolbarAction 'Reload'}
        'F1' {if(Get-Command Show-HcMainMenu -ErrorAction SilentlyContinue){Show-HcMainMenu}}
        default{return $false}
    }
    return $true
}
# END HUYMAIER_BROWSER_VIRTUAL_CURSOR_V1
'@

Set-Content -LiteralPath $BrowserPath -Value ($text+$override) -Encoding UTF8
