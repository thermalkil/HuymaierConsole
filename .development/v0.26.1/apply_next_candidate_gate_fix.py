from pathlib import Path

p=Path('.build/Test-HuymaierCandidate.ps1')
t=p.read_text(encoding='utf-8-sig')
old='''    # RC8 runtime ownership invariants: hidden Game Bar cannot steal general\n    # navigation; Win32 foreground ownership decides internal vs external Guide;\n    # Xbox storefront selection cannot be intercepted by the Original Xbox ID.\n    $visibleIndex=$gameBar.IndexOf('$visible=[HuymaierConsole.NativeApp.HuymaierGameBarHost]::IsVisible')\n    $pollIndex=$gameBar.IndexOf('[HuymaierConsole.NativeApp.NativeConsoleNavigation]::Poll()')\n    if($visibleIndex -lt 0 -or $pollIndex -lt 0 -or $pollIndex -lt $visibleIndex){throw 'Game Bar can poll shared navigation before visible-overlay ownership is established.'}\n'''
new='''    # Runtime ownership invariant: the hidden watcher must never call the shared\n    # normal-navigation poller directly. Once the overlay is visibly active, the\n    # Game-Bar-owned modal bypass is the only permitted D-pad/A/B/etc. poll path.\n    $visibleIndex=$gameBar.IndexOf('$visible=[HuymaierConsole.NativeApp.HuymaierGameBarHost]::IsVisible')\n    $safePollIndex=$gameBar.IndexOf('[HuymaierConsole.NativeApp.HuymaierGameBarHost]::PollNavigation()')\n    if($gameBar -match [regex]::Escape('[HuymaierConsole.NativeApp.NativeConsoleNavigation]::Poll()')){throw 'Game Bar module directly polls shared normal navigation instead of using modal ownership.'}\n    if($visibleIndex -lt 0 -or $safePollIndex -lt 0 -or $safePollIndex -lt $visibleIndex){throw 'Game Bar modal navigation polling is not confined to the visible-overlay path.'}\n'''
if t.count(old)!=1:
    raise SystemExit(f'expected one stale RC8 ownership gate, found {t.count(old)}')
t=t.replace(old,new,1)
p.write_text(t,encoding='utf-8-sig',newline='\n')
print('Updated candidate Game Bar ownership gate for modal-safe PollNavigation architecture.')
