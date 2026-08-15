param(
    [Parameter(Mandatory=$true)][string]$NativeInputPath
)

Set-StrictMode -Version 2.0
$ErrorActionPreference='Stop'
if(-not(Test-Path -LiteralPath $NativeInputPath -PathType Leaf)){throw "Sony pointer transform input missing: $NativeInputPath"}

$text=Get-Content -Raw -LiteralPath $NativeInputPath -Encoding UTF8
if($text -match 'HUYMAIER_SONY_POINTER_SHARED_STATE_V1'){return}

$usingNeedle="using System.Collections.Generic;`r`nusing System.Runtime.InteropServices;"
if(-not $text.Contains($usingNeedle)){
    $usingNeedle="using System.Collections.Generic;`nusing System.Runtime.InteropServices;"
}
if(-not $text.Contains($usingNeedle)){throw 'Sony pointer transform could not find NativeInput using block.'}
$lineBreak=if($usingNeedle.Contains("`r`n")){"`r`n"}else{"`n"}
$text=$text.Replace($usingNeedle,"using System.Collections.Generic;${lineBreak}using System.IO.MemoryMappedFiles;${lineBreak}using System.Runtime.InteropServices;")

$fieldNeedle='        private const ushort SONY_VENDOR_ID = 0x054C;'
if(-not $text.Contains($fieldNeedle)){throw 'Sony pointer transform could not find RawHidController Sony vendor field.'}
$fieldBlock=@'
        private const ushort SONY_VENDOR_ID = 0x054C;

        // HUYMAIER_SONY_POINTER_SHARED_STATE_V1
        // Publish the proven WM_INPUT Sony controller state for pointer-only
        // consumers. Normal shell navigation remains in this process and is
        // still suppressed whenever Huymaier is not foregrounded.
        private const string POINTER_MAP_NAME = "Local\\HuymaierConsole.PointerStateV1";
        private const int POINTER_MAP_SIZE = 64;
        private const int POINTER_MAP_MAGIC = 0x31504348; // HCP1
        private static readonly object PointerSync = new object();
        private static MemoryMappedFile pointerMap;
        private static MemoryMappedViewAccessor pointerView;
        private static int pointerSequence;
        [DllImport("kernel32.dll")] private static extern ulong GetTickCount64();
'@
$text=$text.Replace($fieldNeedle,$fieldBlock)

$axisNeedle=@'
            byte lx = report[stateBase + 0];
            byte ly = report[stateBase + 1];
            byte buttons1 = report[stateBase + 7];
'@
if(-not $text.Contains($axisNeedle)){throw 'Sony pointer transform could not find Sony axis parse block.'}
$axisBlock=@'
            byte lx = report[stateBase + 0];
            byte ly = report[stateBase + 1];
            byte rx = report[stateBase + 2];
            byte ry = report[stateBase + 3];
            byte buttons1 = report[stateBase + 7];
'@
$text=$text.Replace($axisNeedle,$axisBlock)

$tailNeedle=@'
                };
            }
        }

        private static string GetSonyModelName(int productId)
'@
if(-not $text.Contains($tailNeedle)){throw 'Sony pointer transform could not find ParseSonyReport tail.'}
$tailBlock=@'
                };
            }

            // Keep the pointer publication outside the navigation-state lock so
            // slow map creation can never stall controller edge consumption.
            PublishPointerState(productId, lx, ly, rx, ry, buttons1, buttons2);
        }

        private static float NormalizePointerAxis(byte raw, bool invert)
        {
            float value = invert ? (128.0f - raw) / 127.0f : (raw - 128.0f) / 127.0f;
            if (value < -1.0f) return -1.0f;
            if (value > 1.0f) return 1.0f;
            return value;
        }

        private static uint BuildPointerButtons(byte buttons1, byte buttons2)
        {
            uint pointerButtons = 0;
            // PlayStation -> generic pointer contract used by the streaming host:
            // Cross click, Circle back, Square keyboard, Triangle auxiliary,
            // L1/R1 large scroll, Options/Menu, Share/View.
            if ((buttons1 & 0x20) != 0) pointerButtons |= 0x0001;
            if ((buttons1 & 0x40) != 0) pointerButtons |= 0x0002;
            if ((buttons1 & 0x10) != 0) pointerButtons |= 0x0004;
            if ((buttons1 & 0x80) != 0) pointerButtons |= 0x0008;
            if ((buttons2 & 0x01) != 0) pointerButtons |= 0x0010;
            if ((buttons2 & 0x02) != 0) pointerButtons |= 0x0020;
            if ((buttons2 & 0x20) != 0) pointerButtons |= 0x0040;
            if ((buttons2 & 0x10) != 0) pointerButtons |= 0x0080;
            return pointerButtons;
        }

        private static void EnsurePointerMap()
        {
            if (pointerMap != null && pointerView != null) return;
            pointerMap = MemoryMappedFile.CreateOrOpen(POINTER_MAP_NAME, POINTER_MAP_SIZE, MemoryMappedFileAccess.ReadWrite);
            pointerView = pointerMap.CreateViewAccessor(0, POINTER_MAP_SIZE, MemoryMappedFileAccess.ReadWrite);
            pointerView.Write(0, POINTER_MAP_MAGIC);
            pointerView.Write(4, 1);
            pointerView.Write(8, 0);
        }

        private static void PublishPointerState(int productId, byte lx, byte ly, byte rx, byte ry, byte buttons1, byte buttons2)
        {
            try
            {
                lock (PointerSync)
                {
                    EnsurePointerMap();
                    int odd = pointerSequence + 1;
                    if ((odd & 1) == 0) odd++;
                    pointerView.Write(8, odd);
                    System.Threading.Thread.MemoryBarrier();
                    pointerView.Write(0, POINTER_MAP_MAGIC);
                    pointerView.Write(4, 1);
                    pointerView.Write(12, productId);
                    pointerView.Write(16, GetTickCount64());
                    pointerView.Write(24, NormalizePointerAxis(lx, false));
                    pointerView.Write(28, NormalizePointerAxis(ly, true));
                    pointerView.Write(32, NormalizePointerAxis(rx, false));
                    pointerView.Write(36, NormalizePointerAxis(ry, true));
                    pointerView.Write(40, BuildPointerButtons(buttons1, buttons2));
                    System.Threading.Thread.MemoryBarrier();
                    pointerSequence = odd + 1;
                    pointerView.Write(8, pointerSequence);
                    pointerView.Flush();
                }
            }
            catch
            {
                // Pointer publication is supplemental. Never let it destabilize
                // the already-proven Raw HID navigation path.
            }
        }

        private static string GetSonyModelName(int productId)
'@
$text=$text.Replace($tailNeedle,$tailBlock)

Set-Content -LiteralPath $NativeInputPath -Value $text -Encoding UTF8
