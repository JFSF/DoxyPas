# Screenshot of DoxyPasGui (docs\images\gui.png): the window is put on top and the screen area of the window is copied.
param([string]$Out = "$PSScriptRoot\..\..\docs\images\gui.png", [string]$Config = "$PSScriptRoot\..\..\docs\example\Doxyfile")
Add-Type -AssemblyName System.Drawing
Add-Type @'
using System; using System.Runtime.InteropServices;
public class W {
  public delegate bool CB(IntPtr h, IntPtr l);
  [DllImport("user32.dll")] static extern bool EnumWindows(CB cb, IntPtr l);
  [DllImport("user32.dll")] static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
  [DllImport("user32.dll")] static extern bool IsWindowVisible(IntPtr h);
  [DllImport("user32.dll", CharSet=CharSet.Unicode)] static extern int GetWindowText(IntPtr h, System.Text.StringBuilder s, int n);
  public static IntPtr Find(uint pid) { IntPtr r = IntPtr.Zero;
    EnumWindows((h, l) => { uint x; GetWindowThreadProcessId(h, out x);
      var sb = new System.Text.StringBuilder(256); GetWindowText(h, sb, 256);
      if (x == pid && IsWindowVisible(h) && sb.ToString().StartsWith("DoxyPas")) r = h; return true; }, IntPtr.Zero);
    return r; }
  [DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern IntPtr FindWindow(string c, string t);
  [StructLayout(LayoutKind.Sequential)] public struct RC { public int L, T, Right, Bottom; }
  [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RC r);
  [DllImport("user32.dll")] public static extern bool SetWindowPos(IntPtr h, IntPtr after, int x, int y, int w, int hh, uint f);
  [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
}
'@
$exe = (Resolve-Path "$PSScriptRoot\..\..\build\Win64\DoxyPasGui.exe").Path
$p = Start-Process $exe -ArgumentList ('"' + (Resolve-Path $Config).Path + '"') -PassThru
Start-Sleep -Seconds 5
$h = [W]::Find($p.Id)   # the form; MainWindowHandle is the hidden window of the application
[W]::SetWindowPos($h, [IntPtr](-1), 60, 40, 1100, 760, 0x40) | Out-Null   # HWND_TOPMOST, SWP_SHOWWINDOW
[W]::SetForegroundWindow($h) | Out-Null
Start-Sleep -Seconds 2
$r = New-Object W+RC
[W]::GetWindowRect($h, [ref]$r) | Out-Null
$bmp = New-Object System.Drawing.Bitmap ($r.Right - $r.L), ($r.Bottom - $r.T)
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.CopyFromScreen($r.L, $r.T, 0, 0, $bmp.Size)
$bmp.Save((Join-Path (Resolve-Path (Split-Path $Out)).Path (Split-Path $Out -Leaf)), [System.Drawing.Imaging.ImageFormat]::Png)
$p.Kill()
Write-Host "saved ($($bmp.Width)x$($bmp.Height))"
