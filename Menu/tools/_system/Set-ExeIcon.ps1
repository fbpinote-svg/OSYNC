# Set-ExeIcon.ps1 - replace the main icon of an .exe with an .ico file (like rcedit --set-icon).
#   Set-ExeIcon.ps1 -Exe <file.exe> -Ico <file.ico>      -List  shows the icon groups only
param([Parameter(Mandatory = $true)][string]$Exe, [string]$Ico, [switch]$List)
$ErrorActionPreference = 'Stop'
if (-not ('ExeIcon' -as [type])) {
Add-Type -TypeDefinition @'
using System; using System.IO; using System.Collections.Generic; using System.Runtime.InteropServices;
public static class ExeIcon {
  const uint LOAD_LIBRARY_AS_DATAFILE = 0x2;
  static readonly IntPtr RT_ICON = (IntPtr)3, RT_GROUP_ICON = (IntPtr)14;
  delegate bool EnumNameProc(IntPtr h, IntPtr type, IntPtr name, IntPtr p);
  delegate bool EnumLangProc(IntPtr h, IntPtr type, IntPtr name, ushort lang, IntPtr p);
  [DllImport("kernel32", SetLastError = true, CharSet = CharSet.Unicode)] static extern IntPtr LoadLibraryEx(string f, IntPtr r, uint flags);
  [DllImport("kernel32")] static extern bool FreeLibrary(IntPtr h);
  [DllImport("kernel32", CharSet = CharSet.Unicode)] static extern bool EnumResourceNames(IntPtr h, IntPtr type, EnumNameProc cb, IntPtr p);
  [DllImport("kernel32", CharSet = CharSet.Unicode)] static extern bool EnumResourceLanguages(IntPtr h, IntPtr type, IntPtr name, EnumLangProc cb, IntPtr p);
  [DllImport("kernel32")] static extern IntPtr FindResourceEx(IntPtr h, IntPtr type, IntPtr name, ushort lang);
  [DllImport("kernel32")] static extern IntPtr LoadResource(IntPtr h, IntPtr res);
  [DllImport("kernel32")] static extern IntPtr LockResource(IntPtr res);
  [DllImport("kernel32")] static extern uint SizeofResource(IntPtr h, IntPtr res);
  [DllImport("kernel32", SetLastError = true, CharSet = CharSet.Unicode)] static extern IntPtr BeginUpdateResource(string f, bool del);
  [DllImport("kernel32", SetLastError = true)] static extern bool UpdateResource(IntPtr h, IntPtr type, IntPtr name, ushort lang, byte[] data, uint size);
  [DllImport("kernel32", SetLastError = true)] static extern bool EndUpdateResource(IntPtr h, bool discard);
  [DllImport("kernel32", SetLastError = true, CharSet = CharSet.Unicode)] static extern bool UpdateResource(IntPtr h, IntPtr type, string name, ushort lang, byte[] data, uint size);

  public class Group { public string Name; public IntPtr Id; public ushort Lang; public List<ushort> IconIds = new List<ushort>(); }
  static bool IsInt(IntPtr p) { return ((ulong)p.ToInt64() >> 16) == 0; }

  public static List<Group> Groups(string exe, out List<ushort> allIcons) {
    var groups = new List<Group>(); var icons = new List<ushort>();
    IntPtr h = LoadLibraryEx(exe, IntPtr.Zero, LOAD_LIBRARY_AS_DATAFILE);
    if (h == IntPtr.Zero) throw new IOException("cannot open " + exe);
    try {
      EnumResourceNames(h, RT_ICON, (m, t, n, p) => { if (IsInt(n)) icons.Add((ushort)n); return true; }, IntPtr.Zero);
      EnumResourceNames(h, RT_GROUP_ICON, (m, t, n, p) => {
        var g = new Group();
        if (IsInt(n)) { g.Id = n; g.Name = "#" + n.ToInt64(); } else { g.Name = Marshal.PtrToStringUni(n); }
        EnumResourceLanguages(m, t, n, (m2, t2, n2, lang, p2) => { g.Lang = lang; return false; }, IntPtr.Zero);
        IntPtr r = FindResourceEx(m, t, n, g.Lang);
        byte[] d = new byte[SizeofResource(m, r)]; Marshal.Copy(LockResource(LoadResource(m, r)), d, 0, d.Length);
        int count = BitConverter.ToUInt16(d, 4);
        for (int i = 0; i < count; i++) g.IconIds.Add(BitConverter.ToUInt16(d, 6 + i * 14 + 12));
        groups.Add(g); return true;
      }, IntPtr.Zero);
    } finally { FreeLibrary(h); }
    allIcons = icons; return groups;
  }

  // Replaces the first icon group (the one Explorer shows) with the images of an .ico file.
  public static string Set(string exe, string ico) {
    List<ushort> all; var groups = Groups(exe, out all);
    if (groups.Count == 0) throw new InvalidDataException("no icon group in " + exe);
    var g = groups[0];
    byte[] f = File.ReadAllBytes(ico);
    int n = BitConverter.ToUInt16(f, 4);
    var used = new HashSet<ushort>(all); foreach (var id in g.IconIds) used.Remove(id);
    var grp = new MemoryStream(); var w = new BinaryWriter(grp);
    w.Write((ushort)0); w.Write((ushort)1); w.Write((ushort)n);
    IntPtr hu = BeginUpdateResource(exe, false);
    if (hu == IntPtr.Zero) throw new IOException("BeginUpdateResource failed: " + Marshal.GetLastWin32Error());
    try {
      foreach (var id in g.IconIds) UpdateResource(hu, RT_ICON, (IntPtr)id, g.Lang, null, 0);
      ushort next = 1;
      for (int i = 0; i < n; i++) {
        int e = 6 + i * 16;
        uint size = BitConverter.ToUInt32(f, e + 8), off = BitConverter.ToUInt32(f, e + 12);
        byte[] img = new byte[size]; Array.Copy(f, off, img, 0, size);
        while (used.Contains(next)) next++;
        ushort id = next++;
        if (!UpdateResource(hu, RT_ICON, (IntPtr)id, g.Lang, img, size)) throw new IOException("UpdateResource icon failed: " + Marshal.GetLastWin32Error());
        w.Write(f, e, 12); w.Write(id);                        // GRPICONDIRENTRY = ICONDIRENTRY[0..12] + id
      }
      byte[] gd = grp.ToArray();
      bool ok = g.Name.StartsWith("#") ? UpdateResource(hu, RT_GROUP_ICON, g.Id, g.Lang, gd, (uint)gd.Length)
                                       : UpdateResource(hu, RT_GROUP_ICON, g.Name, g.Lang, gd, (uint)gd.Length);
      if (!ok) throw new IOException("UpdateResource group failed: " + Marshal.GetLastWin32Error());
    } catch { EndUpdateResource(hu, true); throw; }
    if (!EndUpdateResource(hu, false)) throw new IOException("EndUpdateResource failed: " + Marshal.GetLastWin32Error());
    return g.Name + " (" + n + " images)";
  }
}
'@
}
if ($List) {
  $all = $null; $gs = [ExeIcon]::Groups($Exe, [ref]$all)
  $gs | ForEach-Object { "group {0} lang {1}: icons {2}" -f $_.Name, $_.Lang, ($_.IconIds -join ',') }
  "all icon ids: $($all -join ',')"
  return
}
"icon set: " + [ExeIcon]::Set($Exe, $Ico)
