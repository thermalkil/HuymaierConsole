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

# PowerShell named mutexes: construct unowned with the unambiguous two-argument
# constructor, then acquire non-blocking. Abandoned mutex means this process may
# safely take ownership. This avoids the problematic New-Object three-argument
# constructor with an out/ref createdNew parameter under Windows PowerShell 5.1.
path='HuymaierInstallerCore.ps1'
t=read(path)
old="""$created=$false
$script:InstallerMutex=New-Object System.Threading.Mutex($true,'Local\\HuymaierConsole.Installer',[ref]$created)
$script:OwnsInstallerMutex=$created
if(-not $script:OwnsInstallerMutex){throw 'Another Huymaier Console installer/update transaction is already running.'}
"""
new="""$script:InstallerMutex=New-Object System.Threading.Mutex -ArgumentList $false,'Local\\HuymaierConsole.Installer'
try{
    $script:OwnsInstallerMutex=[bool]$script:InstallerMutex.WaitOne(0,$false)
}catch [System.Threading.AbandonedMutexException]{
    $script:OwnsInstallerMutex=$true
}
if(-not $script:OwnsInstallerMutex){throw 'Another Huymaier Console installer/update transaction is already running.'}
"""
t=replace_once(t,old,new,'installer mutex')
write(path,t,bom=True)

path='HuymaierSelfUpdater.ps1'
t=read(path)
old="""    $created=$false
    $mutex=New-Object System.Threading.Mutex($true,'Local\\HuymaierConsole.Updater',[ref]$created)
    $ownsMutex=$created
    if(-not $ownsMutex){throw 'Another Huymaier Console update is already running.'}
"""
new="""    $mutex=New-Object System.Threading.Mutex -ArgumentList $false,'Local\\HuymaierConsole.Updater'
    try{
        $ownsMutex=[bool]$mutex.WaitOne(0,$false)
    }catch [System.Threading.AbandonedMutexException]{
        $ownsMutex=$true
    }
    if(-not $ownsMutex){throw 'Another Huymaier Console update is already running.'}
"""
t=replace_once(t,old,new,'updater mutex')
write(path,t,bom=True)

# Remove the final stale runtime-facing 0.26.0 version report from the native
# bridge object now that v0.26.1 has an explicit build stamp.
path='Native/HuymaierConsole.NativeApp.cs'
t=read(path)
old='public string Version { get { return "0.26.0"; } }'
new='public string Version { get { return "0.26.1"; } }'
t=replace_once(t,old,new,'native bridge version')
write(path,t)

# The Xbox 360 shell has no local Guide command handler. Its physical Guide/Home
# button is globally reserved for Huymaier Quick Access, so do not advertise an
# Xbox-local Guide action in the footer.
path='Native/HuymaierConsole.ConsolePlatforms.cs'
t=read(path)
old='A  Select     X  Fallback emulator     B  Back     GUIDE  Xbox Guide     LB / RB  Tab'
new='A  Select     X  Fallback emulator     B  Back     GUIDE  Quick Access     LB / RB  Tab'
t=replace_once(t,old,new,'Xbox 360 Guide footer')
write(path,t)

print('v0.26.1 mutex and Guide cleanup completed')
