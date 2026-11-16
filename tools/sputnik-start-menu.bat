@echo off
rem Sputnik in the Start menu: finds Sputnik.exe and adds a shortcut if there is none.
powershell -NoProfile -ExecutionPolicy Bypass -Command "$t = Get-Content -LiteralPath '%~f0' -Encoding UTF8 -Raw; & ([ScriptBlock]::Create($t.Substring($t.IndexOf('#PS' + 'START'))))"
pause
exit /b
#PSSTART
[Console]::OutputEncoding = [Text.Encoding]::UTF8
$exe = Join-Path $env:ProgramFiles 'Sputnik\Sputnik.exe'
if (-not (Test-Path $exe)) {
  $dir = Get-ItemProperty 'HKCU:\Software\*\Sputnik' -Name InstallDir -ErrorAction SilentlyContinue | Select-Object -First 1 -ExpandProperty InstallDir
  if ($dir) { $exe = Join-Path $dir 'Sputnik.exe' }
}
if (-not (Test-Path $exe)) { Write-Host 'Не нашёл установленный Спутник (Sputnik.exe). Сначала установи его из .msi.'; return }
Write-Host "Спутник установлен: $exe"
$menu = 'Microsoft\Windows\Start Menu\Programs'
$sh = New-Object -ComObject WScript.Shell
$have = @(Join-Path $env:APPDATA $menu; Join-Path $env:ProgramData $menu) |
  ForEach-Object { Get-ChildItem -LiteralPath $_ -Filter *.lnk -Recurse -ErrorAction SilentlyContinue } |
  Where-Object { $sh.CreateShortcut($_.FullName).TargetPath -ieq $exe }
if ($have) {
  Write-Host 'Ярлык в «Пуске» уже есть:'
  $have | ForEach-Object { Write-Host ('  ' + $_.FullName) }
  Write-Host 'В «Пуске» он называется так же, как файл (без .lnk) — ищи по этому слову.'
  return
}
$env:SP_LNK = Join-Path (Join-Path $env:APPDATA $menu) 'Спутник.lnk'
$env:SP_EXE = $exe
$env:SP_ID = 'com.siponik.sputnik'
$ErrorActionPreference = 'Stop'
$s = (New-Object -ComObject WScript.Shell).CreateShortcut($env:SP_LNK)
$s.TargetPath = $env:SP_EXE
$s.WorkingDirectory = Split-Path -Parent $env:SP_EXE
$s.IconLocation = "$env:SP_EXE,0"
$s.Description = 'Спутник'
$s.Save()
Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
using System.Runtime.InteropServices.ComTypes;
[ComImport, Guid("00021401-0000-0000-C000-000000000046")] class SpShellLink {}
[StructLayout(LayoutKind.Sequential, Pack = 4)] public struct SpKey { public Guid fmtid; public uint pid; }
[StructLayout(LayoutKind.Explicit, Size = 24)] public struct SpVar { [FieldOffset(0)] public ushort vt; [FieldOffset(8)] public IntPtr p; }
[ComImport, Guid("886D8EEB-8CF2-4446-8D02-CDBA1DBDCF99"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
interface SpStore {
  void GetCount(out uint c);
  void GetAt(uint i, out SpKey k);
  void GetValue(ref SpKey k, out SpVar v);
  void SetValue(ref SpKey k, ref SpVar v);
  void Commit();
}
public static class SpLnk {
  public static void SetId(string path, string id) {
    var link = new SpShellLink();
    ((IPersistFile)link).Load(path, 2);
    var key = new SpKey { fmtid = new Guid("9F4C2855-9F79-4B39-A8D0-E1D42DE1D5F3"), pid = 5 };
    var v = new SpVar { vt = 31, p = Marshal.StringToCoTaskMemUni(id) };
    try { ((SpStore)link).SetValue(ref key, ref v); ((SpStore)link).Commit(); ((IPersistFile)link).Save(path, true); }
    finally { Marshal.FreeCoTaskMem(v.p); }
  }
}
'@
[SpLnk]::SetId($env:SP_LNK, $env:SP_ID)
Write-Host 'Готово: «Спутник» теперь есть в меню «Пуск». Открой «Пуск», набери «Спутник», правый клик — «Закрепить на начальном экране».'
