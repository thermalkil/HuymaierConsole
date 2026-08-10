from pathlib import Path


def read(path):
    return Path(path).read_text(encoding='utf-8-sig')


def write(path, text, bom=False):
    Path(path).write_text(text, encoding='utf-8-sig' if bom else 'utf-8', newline='\n')


def replace_once(text, old, new, label):
    count = text.count(old)
    if count != 1:
        raise SystemExit(f'{label}: expected exactly one match, found {count}')
    return text.replace(old, new, 1)

# ---------------------------------------------------------------------------
# Sony Raw HID: expose a Guide-only edge consumer that clears ONLY the PS/Home
# pending bit. It must not consume D-pad, face buttons, shoulders, or directions.
# ---------------------------------------------------------------------------
p = 'HuymaierNativeInput.cs'
t = read(p)
anchor = '''        public static int CopyNavigationSnapshots(HidNavigationSnapshot[] destination)\n        {\n'''
insert = '''        public static bool ConsumeGuideEdge()\n        {\n            lock (Sync)\n            {\n                DateTime now = DateTime.UtcNow;\n                foreach (var pair in Snapshots)\n                {\n                    HidControllerSnapshot value = pair.Value;\n                    if (value == null || (now - value.LastSeenUtc).TotalSeconds > 3) continue;\n                    if ((value.PendingMask & 2) == 0) continue;\n                    value.PendingMask &= ~2;\n                    return true;\n                }\n                return false;\n            }\n        }\n\n'''
if 'public static bool ConsumeGuideEdge()' not in t:
    t = replace_once(t, anchor, insert + anchor, 'raw HID Guide-only consumer')
write(p, t)

# ---------------------------------------------------------------------------
# XInput sampler: consume only the latched 0x0400 Guide compatibility edge.
# All other pending buttons/directions remain intact for their owning router.
# NativeConsoleNavigation exposes one public Guide-only arbiter used by the
# hidden external Game Bar watcher.
# ---------------------------------------------------------------------------
p = 'Native/HuymaierConsole.NativeApp.cs'
t = read(p)

x_anchor = '''        internal static int CopyNavigationSnapshots(XInputNavigationSnapshot[] destination)\n        {\n'''
x_insert = '''        internal static bool ConsumeGuideEdge()\n        {\n            EnsureStarted();\n            lock (Sync)\n            {\n                for (int index = 0; index < Samples.Length; index++)\n                {\n                    Sample sample = Samples[index];\n                    if (!sample.Connected || (sample.PendingButtons & 4) == 0) continue;\n                    sample.PendingButtons &= ~4;\n                    return true;\n                }\n                return false;\n            }\n        }\n\n'''
if 'internal static bool ConsumeGuideEdge()' not in t:
    t = replace_once(t, x_anchor, x_insert + x_anchor, 'XInput Guide-only consumer')

nav_anchor = '''        public static void NotifyDeviceChange()\n        {\n'''
nav_insert = '''        public static bool ConsumeGuideOnly()\n        {\n            lock (Sync)\n            {\n                DateTime now = DateTime.UtcNow;\n                if (now < deviceChangeQuietUntilUtc) return false;\n\n                // Primary low-level system-button backend.\n                if (HuymaierSystemButtonBridge.ConsumeGuidePress()) return true;\n\n                // Compatibility fallbacks are deliberately Guide-only. They do\n                // not call router.Poll() and therefore cannot clear or steal any\n                // D-pad/A/B/shoulder/direction edge from the foreground owner.\n                if (XInputBridge.ConsumeGuideEdge()) return true;\n                try\n                {\n                    if (HuymaierConsole.Native.RawHidController.ConsumeGuideEdge()) return true;\n                }\n                catch { }\n                return false;\n            }\n        }\n\n'''
if 'public static bool ConsumeGuideOnly()' not in t:
    t = replace_once(t, nav_anchor, nav_insert + nav_anchor, 'native Guide-only arbiter')
write(p, t)

# ---------------------------------------------------------------------------
# Game Bar watcher: reflection now calls NativeConsoleNavigation.ConsumeGuideOnly
# instead of directly consuming GameInput alone. RawGameController remains as a
# final non-destructive fallback for controller families not covered natively.
# ---------------------------------------------------------------------------
p = 'HuymaierGameBar.ps1'
t = read(p)
old_init = '''function Initialize-HcSystemGuideReflection {\n    if($null -ne $script:HcSystemGuideMethod){return}\n    try{\n        $nativeVariable=Get-Variable -Name HuymaierNativeBridge -ErrorAction SilentlyContinue\n        if($null -eq $nativeVariable -or $null -eq $nativeVariable.Value){return}\n        $assembly=$nativeVariable.Value.GetType().Assembly\n        $type=$assembly.GetType('HuymaierConsole.NativeApp.HuymaierSystemButtonBridge',$false)\n        if($null -eq $type){return}\n        $flags=[Reflection.BindingFlags]::Static -bor [Reflection.BindingFlags]::NonPublic\n        $method=$type.GetMethod('ConsumeGuidePress',$flags)\n        if($null -ne $method){$script:HcSystemGuideType=$type;$script:HcSystemGuideMethod=$method}\n    }catch{}\n}\n'''
new_init = '''function Initialize-HcSystemGuideReflection {\n    if($null -ne $script:HcSystemGuideMethod){return}\n    try{\n        $nativeVariable=Get-Variable -Name HuymaierNativeBridge -ErrorAction SilentlyContinue\n        if($null -eq $nativeVariable -or $null -eq $nativeVariable.Value){return}\n        $assembly=$nativeVariable.Value.GetType().Assembly\n        $type=$assembly.GetType('HuymaierConsole.NativeApp.NativeConsoleNavigation',$false)\n        if($null -eq $type){return}\n        $flags=[Reflection.BindingFlags]::Static -bor [Reflection.BindingFlags]::Public\n        $method=$type.GetMethod('ConsumeGuideOnly',$flags)\n        if($null -ne $method){$script:HcSystemGuideType=$type;$script:HcSystemGuideMethod=$method}\n    }catch{}\n}\n'''
t = replace_once(t, old_init, new_init, 'Game Bar Guide-only reflection')

old_func = '''function Get-HcGameInputGuideEdge {\n    try{\n        Initialize-HcSystemGuideReflection\n        if($null -eq $script:HcSystemGuideMethod){return $false}\n        return [bool]$script:HcSystemGuideMethod.Invoke($null,$null)\n    }catch{return $false}\n}\n'''
new_func = '''function Get-HcSystemGuideEdge {\n    try{\n        Initialize-HcSystemGuideReflection\n        if($null -eq $script:HcSystemGuideMethod){return $false}\n        return [bool]$script:HcSystemGuideMethod.Invoke($null,$null)\n    }catch{return $false}\n}\n'''
t = replace_once(t, old_func, new_func, 'Game Bar Guide edge function rename')
t = t.replace('$gameInputGuideEdge=Get-HcGameInputGuideEdge', '$nativeGuideEdge=Get-HcSystemGuideEdge')
t = t.replace('$guideEdge=$gameInputGuideEdge -or $rawGuideEdge', '$guideEdge=$nativeGuideEdge -or $rawGuideEdge')
write(p, t, bom=True)

# Keep the shell comment aligned with the actual ownership architecture.
p = 'HuymaierConsole.ps1'
t = read(p)
old_comment = '''        # Do not reset the native router here. While an external game/app or the\n        # Huymaier Game Bar owns focus, the external Guide watcher uses this same\n        # router for A/B/D-pad/shoulder input. Resetting it from the background\n        # Console timer would erase every navigation edge before the overlay sees it.\n'''
new_comment = '''        # Do not reset the native router here. While an external game/app owns\n        # focus, the hidden watcher consumes only a dedicated Guide/Home edge.\n        # Once the Huymaier Game Bar is visible, it becomes the owner of normal\n        # A/B/D-pad/shoulder navigation until the overlay closes.\n'''
if old_comment in t:
    t = replace_once(t, old_comment, new_comment, 'shell ownership comment')
write(p, t, bom=True)

# ---------------------------------------------------------------------------
# Public installer wrapper: interactive success must never read $LASTEXITCODE.
# The core exits nonzero itself on transactional failure; normal return = success.
# ---------------------------------------------------------------------------
p = 'Install-HuymaierConsole.ps1'
t = read(p)
if 'exit $LASTEXITCODE' in t:
    t = t.replace('exit $LASTEXITCODE', 'exit 0', 1)
if 'Never depend on $LASTEXITCODE here' not in t:
    old = '& $core -PackageRoot $PSScriptRoot -SilentUpdate:$SilentUpdate\nexit 0\n'
    new = '''# HuymaierInstallerCore.ps1 exits 1 itself on a transactional failure. A\n# successful core invocation returns normally, so the public wrapper owns the\n# successful process exit code explicitly. Never depend on $LASTEXITCODE here:\n# PowerShell scripts do not guarantee that automatic variable is initialized.\n& $core -PackageRoot $PSScriptRoot -SilentUpdate:$SilentUpdate\nexit 0\n'''
    t = replace_once(t, old, new, 'installer wrapper success contract')
write(p, t)

# ---------------------------------------------------------------------------
# Candidate gates: ensure hidden overlay uses the Guide-only arbiter and the
# public wrapper can never regress to $LASTEXITCODE. Existing failure injection
# already invokes the public wrapper for all install/repair negative cases.
# ---------------------------------------------------------------------------
p = '.build/Test-HuymaierCandidate.ps1'
t = read(p)
anchor = '''    if($restore -notmatch [regex]::Escape('foreach($backup in @($rawBackup))')){throw 'Legacy Xbox Game Bar backup-array migration is missing.'}\n'''
insert = anchor + r'''

    # RC9: external Guide fallback must be strictly Guide-only, and the public
    # installer wrapper must own success without relying on $LASTEXITCODE.
    foreach($required in @('ConsumeGuideOnly','Get-HcSystemGuideEdge')){if($gameBar -notmatch [regex]::Escape($required)){throw "Guide-only external Game Bar wake path is missing: $required"}}
    $nativeApp=Get-Content -Raw -LiteralPath (Join-Path $StageRoot 'Native\\HuymaierConsole.NativeApp.cs') -Encoding UTF8
    foreach($required in @('public static bool ConsumeGuideOnly()','XInputBridge.ConsumeGuideEdge()','RawHidController.ConsumeGuideEdge()')){if($nativeApp -notmatch [regex]::Escape($required)){throw "Native Guide-only fallback invariant is missing: $required"}}
    $nativeInput=Get-Content -Raw -LiteralPath (Join-Path $StageRoot 'HuymaierNativeInput.cs') -Encoding UTF8
    if($nativeInput -notmatch [regex]::Escape('value.PendingMask &= ~2')){throw 'PlayStation Guide-only fallback does not preserve non-Guide pending input.'}
    $wrapper=Get-Content -Raw -LiteralPath (Join-Path $StageRoot 'Install-HuymaierConsole.ps1') -Encoding UTF8
    if($wrapper -match [regex]::Escape('$LASTEXITCODE')){throw 'Public installer wrapper still references $LASTEXITCODE.'}
    if($wrapper -notmatch [regex]::Escape('exit 0')){throw 'Public installer wrapper has no explicit success exit code.'}
'''
if 'RC9: external Guide fallback' not in t:
    t = replace_once(t, anchor, insert, 'candidate RC9 invariants')
write(p, t, bom=True)

print('RC9 Guide-only background wake path and installer wrapper fix applied.')
