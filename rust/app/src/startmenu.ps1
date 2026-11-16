# Ярлык Спутника в меню «Пуск» (для текущего пользователя) с AppUserModelID — по нему Windows
# связывает ярлык с окном и уведомлениями. Пути и id — из SP_LNK, SP_EXE, SP_ID (app/src/startmenu.rs).
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
