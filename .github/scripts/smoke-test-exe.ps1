# Starts the native exe, waits until its first window is open, and closes it.
# The app has no route without a window, so this is the one check that a
# missing registration in the native-image metadata does not stop the start.
# The database is put under a temporary folder, so the home folder of the
# runner is not touched. With an empty database the app opens the folder
# dialog over the main window; closing it leaves the main window.
param(
  [Parameter(Mandatory = $true)][string]$Exe,
  [int]$StartTimeoutSeconds = 60
)

$ErrorActionPreference = 'Stop'

# Process.CloseMainWindow() is of no use here: while the modal dialog is open,
# the main window is disabled and ignores WM_CLOSE. So the visible windows of
# the process are listed, and WM_CLOSE goes to every enabled one.
Add-Type -TypeDefinition @'
using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;
public static class SmokeWindows {
  delegate bool EnumProc(IntPtr hwnd, IntPtr lParam);
  [DllImport("user32.dll")] static extern bool EnumWindows(EnumProc proc, IntPtr lParam);
  [DllImport("user32.dll")] static extern uint GetWindowThreadProcessId(IntPtr hwnd, out uint pid);
  [DllImport("user32.dll")] static extern bool IsWindowVisible(IntPtr hwnd);
  [DllImport("user32.dll")] static extern bool IsWindowEnabled(IntPtr hwnd);
  [DllImport("user32.dll")] static extern bool PostMessage(IntPtr hwnd, uint msg, IntPtr wParam, IntPtr lParam);
  const uint WM_CLOSE = 0x0010;
  public static List<IntPtr> VisibleWindowsOf(uint pid) {
    var result = new List<IntPtr>();
    EnumWindows((hwnd, lParam) => {
      uint owner;
      GetWindowThreadProcessId(hwnd, out owner);
      if (owner == pid && IsWindowVisible(hwnd)) { result.Add(hwnd); }
      return true;
    }, IntPtr.Zero);
    return result;
  }
  public static int CloseEnabledWindowsOf(uint pid) {
    int closed = 0;
    foreach (var hwnd in VisibleWindowsOf(pid)) {
      if (IsWindowEnabled(hwnd)) { PostMessage(hwnd, WM_CLOSE, IntPtr.Zero, IntPtr.Zero); closed++; }
    }
    return closed;
  }
}
'@

$work = Join-Path ([System.IO.Path]::GetTempPath()) "english-drill-player-smoke-$PID"
New-Item -ItemType Directory -Force $work | Out-Null

$p = Start-Process -FilePath $Exe -PassThru -ArgumentList @("-Dedp.drill.db=$work/drill.db")
$pid32 = [uint32]$p.Id

$deadline = (Get-Date).AddSeconds($StartTimeoutSeconds)
while ((Get-Date) -lt $deadline) {
  if ($p.HasExited) {
    Write-Output "::error::The exe exited with code $($p.ExitCode) before it opened a window."
    exit 1
  }
  if ([SmokeWindows]::VisibleWindowsOf($pid32).Count -gt 0) { break }
  Start-Sleep -Seconds 1
}
if ([SmokeWindows]::VisibleWindowsOf($pid32).Count -eq 0) {
  $p.Kill()
  Write-Output "::error::The exe opened no window within $StartTimeoutSeconds seconds."
  exit 1
}
Write-Output 'The exe opened a window.'

# The folder dialog is modal and comes first, then the main window.
for ($i = 0; $i -lt 5 -and -not $p.HasExited; $i++) {
  $null = [SmokeWindows]::CloseEnabledWindowsOf($pid32)
  Start-Sleep -Seconds 3
}
if (-not $p.HasExited) {
  $p.Kill()
  Write-Output '::error::The exe did not exit after its windows were closed.'
  exit 1
}
if ($p.ExitCode -ne 0) {
  Write-Output "::error::The exe exited with code $($p.ExitCode)."
  exit 1
}
Write-Output 'The exe exited with code 0.'
