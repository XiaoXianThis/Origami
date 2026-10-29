# End-to-end drag test for the Windows app.
#
# Creates three throwaway windows, drives the tab bar, and checks the resulting
# groups. Real mouse input is used when the test can take the foreground; when an
# elevated window owns it, synthetic input is blocked by UIPI, so the same steps
# are posted as window messages instead. Either way the app's handlers and its
# drop resolution run for real.
#
# The test writes %APPDATA%\Origami\settings.ini and restores it afterwards.
#
#   powershell -NoProfile -ExecutionPolicy Bypass -File tests\drag-ui.ps1
#   powershell -NoProfile -ExecutionPolicy Bypass -File tests\drag-ui.ps1 -HideMode minimize
#
param(
    [ValidateSet('offscreen', 'minimize')]
    [string]$HideMode = 'offscreen',
    [string]$Exe = ''
)

$ErrorActionPreference = 'Stop'

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

Add-Type -TypeDefinition @"
using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;
using System.Text;

public static class Native {
    public delegate bool EnumProc(IntPtr h, IntPtr l);
    [DllImport("user32.dll")] public static extern bool EnumWindows(EnumProc cb, IntPtr l);
    [DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern int GetClassName(IntPtr h, StringBuilder s, int n);
    [DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern int GetWindowText(IntPtr h, StringBuilder s, int n);
    [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
    [DllImport("dwmapi.dll", PreserveSig = true)] public static extern int DwmGetWindowAttribute(IntPtr h, int attribute, out RECT value, int size);
    [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h);
    [DllImport("user32.dll")] public static extern bool IsIconic(IntPtr h);
    [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
    [DllImport("user32.dll")] public static extern bool SetCursorPos(int x, int y);
    [DllImport("user32.dll")] public static extern bool SetProcessDpiAwarenessContext(IntPtr value);
    [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
    [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
    [DllImport("kernel32.dll")] public static extern uint GetCurrentThreadId();
    [DllImport("user32.dll")] public static extern bool AttachThreadInput(uint attach, uint attachTo, bool doAttach);
    [DllImport("user32.dll")] public static extern IntPtr WindowFromPoint(POINT p);
    [DllImport("user32.dll")] public static extern bool ScreenToClient(IntPtr h, ref POINT p);
    [DllImport("user32.dll")] public static extern int GetSystemMetrics(int index);
    [DllImport("user32.dll")] public static extern bool PostMessage(IntPtr h, uint msg, IntPtr w, IntPtr l);
    [DllImport("user32.dll")] public static extern void mouse_event(uint flags, uint dx, uint dy, uint data, UIntPtr extra);

    public struct RECT { public int Left, Top, Right, Bottom; }
    public struct POINT { public int X, Y; }

    public class Info {
        public IntPtr Hwnd;
        public int Left, Top, Width, Height;
        public bool Visible;
        public override string ToString() {
            return string.Format("hwnd=0x{0:X} pos=({1},{2}) size={3}x{4} visible={5}",
                Hwnd.ToInt64(), Left, Top, Width, Height, Visible);
        }
    }

    static List<Info> WindowsOf(string className) {
        var list = new List<Info>();
        EnumWindows(delegate(IntPtr h, IntPtr l) {
            var sb = new StringBuilder(256);
            GetClassName(h, sb, 256);
            if (sb.ToString() == className) {
                RECT r; GetWindowRect(h, out r);
                list.Add(new Info { Hwnd = h, Left = r.Left, Top = r.Top, Width = r.Right - r.Left,
                                    Height = r.Bottom - r.Top, Visible = IsWindowVisible(h) });
            }
            return true;
        }, IntPtr.Zero);
        return list;
    }

    public static List<Info> Overlays() { return WindowsOf("OrigamiWin.Overlay"); }
    public static List<Info> DragVisuals() { return WindowsOf("OrigamiWin.DragVisual"); }

    public static RECT Rect(IntPtr h) { RECT r; GetWindowRect(h, out r); return r; }

    // Visible bounds, excluding the invisible resize border: what the user sees,
    // and what the app copies when it matches a window frame.
    public static RECT VisibleRect(IntPtr h) {
        RECT r;
        if (DwmGetWindowAttribute(h, 9, out r, Marshal.SizeOf(typeof(RECT))) != 0) { GetWindowRect(h, out r); }
        return r;
    }

    public static bool Iconic(IntPtr h) { return IsIconic(h); }

    public static bool CloseApp() {
        var windows = WindowsOf("OrigamiWin.Message");
        if (windows.Count == 0) { return false; }
        PostMessage(windows[0].Hwnd, 0x0010, IntPtr.Zero, IntPtr.Zero);
        return true;
    }

    public static bool ForceForeground(IntPtr h) {
        IntPtr fg = GetForegroundWindow();
        uint pid;
        uint fgThread = fg == IntPtr.Zero ? 0u : GetWindowThreadProcessId(fg, out pid);
        uint self = GetCurrentThreadId();
        bool attached = fgThread != 0 && fgThread != self && AttachThreadInput(self, fgThread, true);
        SetForegroundWindow(h);
        if (attached) AttachThreadInput(self, fgThread, false);
        return GetForegroundWindow() == h;
    }

    static IntPtr MakeLParam(int x, int y) {
        return (IntPtr)((y << 16) | (x & 0xFFFF));
    }

    static IntPtr ClientPoint(IntPtr hwnd, int screenX, int screenY) {
        POINT p = new POINT { X = screenX, Y = screenY };
        ScreenToClient(hwnd, ref p);
        return MakeLParam(p.X, p.Y);
    }

    public static void PostClick(IntPtr hwnd, int screenX, int screenY) {
        IntPtr lp = ClientPoint(hwnd, screenX, screenY);
        PostMessage(hwnd, 0x0201, (IntPtr)1, lp);   // WM_LBUTTONDOWN, MK_LBUTTON
        PostMessage(hwnd, 0x0202, IntPtr.Zero, lp); // WM_LBUTTONUP
    }

    public static void PostDrag(IntPtr hwnd, int fromX, int fromY, int toX, int toY) {
        PostMessage(hwnd, 0x0201, (IntPtr)1, ClientPoint(hwnd, fromX, fromY));
        for (int i = 1; i <= 8; i++) {
            int x = fromX + (toX - fromX) * i / 8;
            int y = fromY + (toY - fromY) * i / 8;
            PostMessage(hwnd, 0x0200, (IntPtr)1, ClientPoint(hwnd, x, y)); // WM_MOUSEMOVE
            System.Threading.Thread.Sleep(30);
        }
        PostMessage(hwnd, 0x0202, IntPtr.Zero, ClientPoint(hwnd, toX, toY));
    }

    public static void MouseDown(int x, int y) {
        SetCursorPos(x, y);
        System.Threading.Thread.Sleep(100);
        mouse_event(0x0002, 0, 0, 0, UIntPtr.Zero);
    }

    public static void MouseMove(int x, int y) {
        SetCursorPos(x, y);
        System.Threading.Thread.Sleep(30);
    }

    public static void MouseUp() { mouse_event(0x0004, 0, 0, 0, UIntPtr.Zero); }

    public static void Click(int x, int y) {
        MouseDown(x, y);
        System.Threading.Thread.Sleep(60);
        MouseUp();
    }

    public static string Describe(IntPtr h) {
        var c = new StringBuilder(256); GetClassName(h, c, 256);
        var t = new StringBuilder(256); GetWindowText(h, t, 256);
        return string.Format("0x{0:X} {1} '{2}'", h.ToInt64(), c, t);
    }
}
"@

# Physical pixels everywhere: without this the process sees virtualized
# coordinates and every synthetic click lands somewhere else.
[Native]::SetProcessDpiAwarenessContext([IntPtr](-4)) | Out-Null

$failures = 0
$useInjection = $false

function Assert([string]$Name, [bool]$Condition) {
    if ($Condition) {
        Write-Output ("PASS  " + $Name)
    } else {
        Write-Output ("FAIL  " + $Name)
        $script:failures++
    }
}

function FramesClose($A, $B, [int]$Tolerance = 2) {
    return ([Math]::Abs($A.Left - $B.Left) -le $Tolerance) -and
           ([Math]::Abs($A.Top - $B.Top) -le $Tolerance) -and
           ([Math]::Abs(($A.Right - $A.Left) - ($B.Right - $B.Left)) -le $Tolerance) -and
           ([Math]::Abs(($A.Bottom - $A.Top) - ($B.Bottom - $B.Top)) -le $Tolerance)
}

function Describe($R) {
    return ("({0},{1}) {2}x{3}" -f $R.Left, $R.Top, ($R.Right - $R.Left), ($R.Bottom - $R.Top))
}

function Pump([int]$Milliseconds) {
    $end = (Get-Date).AddMilliseconds($Milliseconds)
    while ((Get-Date) -lt $end) {
        [System.Windows.Forms.Application]::DoEvents()
        Start-Sleep -Milliseconds 10
    }
}

function LogCount([string]$Pattern) {
    if (-not (Test-Path $logPath)) { return 0 }
    return (Get-Content $logPath | Select-String -Pattern $Pattern).Count
}

function Find-OverlayFor([System.Drawing.Rectangle]$Bounds, $Overlays) {
    foreach ($o in $Overlays) {
        if (-not $o.Visible) { continue }
        $verticalGap = $Bounds.Top - $o.Top
        $horizontalOverlap = [Math]::Min($Bounds.Right, $o.Left + $o.Width) - [Math]::Max($Bounds.Left, $o.Left)
        if ($verticalGap -ge 0 -and $verticalGap -le 70 -and $horizontalOverlap -gt 20) {
            return $o
        }
    }
    return $null
}

function BarAt($Overlays, [int]$MinWidth, [int]$MaxWidth) {
    return $Overlays | Where-Object { $_.Visible -and $_.Width -ge $MinWidth -and $_.Width -le $MaxWidth } | Select-Object -First 1
}

# Content hash of a bar's own pixels, independent of where it sits on screen.
# Used to prove that a click actually repainted the bar.
function Get-BarHash($Bar) {
    $bmp = New-Object System.Drawing.Bitmap $Bar.Width, $Bar.Height
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.CopyFromScreen($Bar.Left, $Bar.Top, 0, 0, (New-Object System.Drawing.Size($Bar.Width, $Bar.Height)))
    $g.Dispose()
    $hash = 17
    for ($y = 2; $y -lt $Bar.Height; $y += 4) {
        for ($x = 2; $x -lt $Bar.Width; $x += 4) {
            $hash = (($hash * 31) + $bmp.GetPixel($x, $y).ToArgb()) % 2147483647
        }
    }
    $bmp.Dispose()
    return $hash
}

function Invoke-Click($Overlay) {
    $x = $Overlay.Left + 20
    $y = $Overlay.Top + [int]($Overlay.Height / 2)
    if ($useInjection) {
        [Native]::Click($x, $y)
    } else {
        [Native]::PostClick($Overlay.Hwnd, $x, $y)
    }
}

function Invoke-Drag($Overlay, [int]$ToX, [int]$ToY) {
    $fromX = $Overlay.Left + 20
    $fromY = $Overlay.Top + [int]($Overlay.Height / 2)
    if ($useInjection) {
        [Native]::MouseDown($fromX, $fromY)
        [Native]::MouseMove(($fromX + 120), ($fromY + 80))
        Pump 120
        [Native]::MouseMove(($ToX * 3 + $fromX) / 4, ($ToY * 3 + $fromY) / 4)
        Pump 120
        [Native]::MouseMove($ToX, $ToY)
    } else {
        [Native]::PostDrag($Overlay.Hwnd, $fromX, $fromY, $ToX, $ToY)
    }
}

function End-Drag {
    if ($useInjection) {
        [Native]::MouseUp()
    }
}

function New-TestWindow([string]$Title, [System.Drawing.Rectangle]$Bounds) {
    $form = New-Object System.Windows.Forms.Form
    $form.Text = $Title
    $form.StartPosition = 'Manual'
    $form.Bounds = $Bounds
    $form.TopMost = $true
    $form.Show()
    return $form
}

if (-not $Exe) {
    $candidates = @(
        (Join-Path $PSScriptRoot '..\build\bin\origami.exe'),
        (Join-Path $PSScriptRoot '..\..\..\build\win\origami.exe')
    ) | Where-Object { Test-Path $_ } | Sort-Object { (Get-Item $_).LastWriteTime } -Descending
    $Exe = $candidates | Select-Object -First 1
}
if (-not $Exe -or -not (Test-Path $Exe)) {
    throw 'origami.exe not found; build the app first or pass -Exe'
}
Write-Output ("exe: {0}" -f (Resolve-Path $Exe))

$iniDir = Join-Path $env:APPDATA 'Origami'
New-Item -ItemType Directory -Force $iniDir | Out-Null
$iniPath = Join-Path $iniDir 'settings.ini'
$logPath = Join-Path $env:TEMP 'origami-ui-test.log'
Remove-Item $logPath -ErrorAction SilentlyContinue
$env:ORIGAMI_WIN_LOG = $logPath
$iniBackup = if (Test-Path $iniPath) { Get-Content $iniPath -Raw } else { $null }
$modeValue = if ($HideMode -eq 'minimize') { '0' } else { '1' }
Set-Content -Path $iniPath -Value "[general]`nhide_mode=$modeValue`nenabled=1`nrestore_on_exit=1`nmatch_window_frame=1" -Encoding ascii

$app = $null
$forms = @()
try {
    Get-Process origami -ErrorAction SilentlyContinue | Stop-Process -Force
    Start-Sleep -Milliseconds 400

    $forms += New-TestWindow 'Origami Test A' (New-Object System.Drawing.Rectangle(200, 220, 620, 380))
    $forms += New-TestWindow 'Origami Test B' (New-Object System.Drawing.Rectangle(1000, 250, 500, 300))
    $forms += New-TestWindow 'Origami Test C' (New-Object System.Drawing.Rectangle(220, 760, 700, 420))
    Pump 700

    $app = Start-Process -FilePath $Exe -PassThru
    Pump 2500

    $useInjection = [Native]::ForceForeground($forms[1].Handle)
    Pump 200

    $rectA = [Native]::Rect($forms[0].Handle)
    $rectB = [Native]::Rect($forms[1].Handle)
    $rectC = [Native]::Rect($forms[2].Handle)
    $overlays = [Native]::Overlays()
    $overlayA = Find-OverlayFor ([System.Drawing.Rectangle]::new($rectA.Left, $rectA.Top, ($rectA.Right-$rectA.Left), ($rectA.Bottom-$rectA.Top))) $overlays
    $overlayB = Find-OverlayFor ([System.Drawing.Rectangle]::new($rectB.Left, $rectB.Top, ($rectB.Right-$rectB.Left), ($rectB.Bottom-$rectB.Top))) $overlays
    $overlayC = Find-OverlayFor ([System.Drawing.Rectangle]::new($rectC.Left, $rectC.Top, ($rectC.Right-$rectC.Left), ($rectC.Bottom-$rectC.Top))) $overlays
    Assert 'a bar for each test window' ([bool]($overlayA -and $overlayB -and $overlayC))
    if (-not ($overlayA -and $overlayB -and $overlayC)) {
        $overlays | ForEach-Object { Write-Output ("  " + $_) }
        throw 'overlays missing'
    }
    Write-Output ("bars: A={0} B={1} C={2}" -f $overlayA, $overlayB, $overlayC)

    # 1. clicking a tab runs the switch path. Real input is tried first; if the OS
    #    swallows it (an elevated window owns the foreground), post the messages
    #    instead and keep using that for the rest of the run.
    $switches = LogCount 'switch group='
    $downs = LogCount 'down group='
    $clickX = $overlayA.Left + 20
    $clickY = $overlayA.Top + [int]($overlayA.Height / 2)
    [Native]::Click($clickX, $clickY)
    Pump 500
    $useInjection = (LogCount 'down group=') -gt $downs
    if (-not $useInjection) {
        [Native]::PostClick($overlayA.Hwnd, $clickX, $clickY)
        Pump 600
    }
    Write-Output ("hide mode: {0}   input: {1}" -f $HideMode, $(if ($useInjection) { 'real mouse' } else { 'posted messages' }))
    Assert 'click on a tab switches groups' ((LogCount 'switch group=') -gt $switches)
    if ($useInjection) {
        Assert 'click on a tab activates its window' ([Native]::GetForegroundWindow() -eq $forms[0].Handle)
    }

    # 2. drag A onto B's body
    $visualsBefore = ([Native]::DragVisuals() | Measure-Object).Count
    $merges = LogCount 'drop: merged'
    $slotFrame = [Native]::VisibleRect($forms[1].Handle)
    Invoke-Drag $overlayA ($rectB.Left + 200) ($rectB.Top + 150)
    Pump 400
    if ($useInjection) {
        $visualsDuring = ([Native]::DragVisuals()).Count
        Assert 'ghost and drop frame appear while dragging' ($visualsDuring -ge 2)
    }
    End-Drag
    Pump 1200

    $bar2 = BarAt ([Native]::Overlays()) 200 350
    Assert 'dropping on a window body merges the two windows' ([bool]$bar2 -and (LogCount 'drop: merged') -gt $merges)
    Assert 'the merged window takes over the target frame' (FramesClose ([Native]::VisibleRect($forms[0].Handle)) $slotFrame)
    Assert 'the merged window is hidden' ([Native]::Iconic($forms[1].Handle) -or [Native]::Rect($forms[1].Handle).Left -le -1000)
    if (-not $bar2) { throw 'merge failed' }

    # 2b. releasing a drag back on the group's own bar must cancel, not detach
    $merges = LogCount 'drop: merged'
    $detaches = LogCount 'drop: detached'
    Invoke-Drag $bar2 ($bar2.Left + 30) ($bar2.Top + 12)
    End-Drag
    Pump 900
    $stillTwo = BarAt ([Native]::Overlays()) 200 350
    Assert 'dropping back on its own bar does not split the group' ([bool]$stillTwo -and
        (LogCount 'drop: detached') -eq $detaches -and (LogCount 'drop: merged') -eq $merges)
    if (-not $stillTwo) { throw 'group split unexpectedly' }

    # 3. drag C onto the two-tab bar
    $merges = LogCount 'drop: merged'
    Invoke-Drag $overlayC ($bar2.Left + 40) ($bar2.Top + [int]($bar2.Height / 2))
    End-Drag
    Pump 1200
    $bar3 = BarAt ([Native]::Overlays()) 350 700
    Assert 'dropping on another bar makes a three-window group' ([bool]$bar3 -and (LogCount 'drop: merged') -gt $merges)
    if (-not $bar3) { throw 'second merge failed' }

    # 4. switching inside the three-window group, and each target takes over the
    #    frame of the window it replaces
    $slotFrame = [Native]::VisibleRect($forms[2].Handle)
    $switches = LogCount 'switch group='
    $hashBefore = Get-BarHash $bar3
    Invoke-Click $bar3
    Pump 800
    Assert 'the first tab switches to the first window' ((LogCount 'switch group=') -gt $switches)
    $bar3After = BarAt ([Native]::Overlays()) 350 700
    Assert 'the active highlight repaints after a click' ([bool]$bar3After -and (Get-BarHash $bar3After) -ne $hashBefore)
    Assert 'the first tab takes over the previous frame' (FramesClose ([Native]::VisibleRect($forms[1].Handle)) $slotFrame)
    if ($useInjection) {
        Assert 'the first tab activates that window' ([Native]::GetForegroundWindow() -eq $forms[1].Handle)
    }

    $bar3 = BarAt ([Native]::Overlays()) 350 700
    $middleTab = New-Object PSObject -Property @{ Hwnd = $bar3.Hwnd; Left = ($bar3.Left + [int]($bar3.Width / 2) - 20); Top = $bar3.Top; Width = 150; Height = $bar3.Height; Visible = $true }
    $slotFrame = [Native]::VisibleRect($forms[1].Handle)
    $switches = LogCount 'switch group='
    Invoke-Click $middleTab
    Pump 800
    Assert 'the middle tab switches to the second window' ((LogCount 'switch group=') -gt $switches)
    Assert 'the middle tab takes over the previous frame' (FramesClose ([Native]::VisibleRect($forms[0].Handle)) $slotFrame)

    $bar3 = BarAt ([Native]::Overlays()) 350 700
    $lastTab = New-Object PSObject -Property @{ Hwnd = $bar3.Hwnd; Left = ($bar3.Left + $bar3.Width - 40); Top = $bar3.Top; Width = 150; Height = $bar3.Height; Visible = $true }
    $switches = LogCount 'switch group='
    Invoke-Click $lastTab
    Pump 800
    Assert 'the last tab switches to the last window' ((LogCount 'switch group=') -gt $switches)
    if ($useInjection) {
        Assert 'the last tab activates that window' ([Native]::GetForegroundWindow() -eq $forms[2].Handle)
    }

    # 5. quitting restores every hidden window
    Assert 'the app closes through its message window' ([Native]::CloseApp())
    Pump 1500
    $restored = $true
    foreach ($form in $forms) {
        $rect = [Native]::Rect($form.Handle)
        if ($rect.Left -le -1000 -or $rect.Top -le -1000 -or [Native]::Iconic($form.Handle)) {
            $restored = $false
        }
    }
    Assert 'all windows are back on screen after quitting' $restored
} finally {
    if ($app -and -not $app.HasExited) { Stop-Process -Id $app.Id -Force -ErrorAction SilentlyContinue }
    foreach ($form in $forms) {
        if ($form) { $form.Close(); $form.Dispose() }
    }
    if ($null -ne $iniBackup) {
        Set-Content -Path $iniPath -Value $iniBackup -NoNewline
    } else {
        Remove-Item -Path $iniPath -ErrorAction SilentlyContinue
    }
}

if ($failures -gt 0) {
    if (Test-Path $logPath) {
        Write-Output '--- app log (tail) ---'
        Get-Content $logPath | Select-Object -Last 40
    }
    Write-Output ("{0} check(s) failed" -f $failures)
    exit 1
}
Write-Output 'all checks passed'
