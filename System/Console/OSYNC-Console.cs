// OSYNC-Console.exe - opens the OSYNC admin console (System\Scripts\Console-Server.ps1 + System\Console\index.html)
// as its own window on the MASTER: starts the console server hidden when it is not running yet, waits until it answers,
// opens http://127.0.0.1:<ConsolePort> in an Edge app window (own profile, no tabs / address bar) and stops the server
// again when that window is closed (a server that was already running - e.g. task OSYNC-Console - is left alone).
// Refuses to run on a client PC (Settings MasterPC) and while the folder still runs the old layout (before step B).
//   OSYNC-Console.exe [--root <OSYNC folder>]      default: the folder two levels above this exe (or this exe's folder)
// Build (no tools to install, .NET Framework csc that comes with Windows):
//   C:\Windows\Microsoft.NET\Framework64\v4.0.30319\csc.exe /nologo /target:winexe /optimize /codepage:65001
//     /win32icon:console.ico /r:System.Management.dll /r:System.Windows.Forms.dll /out:OSYNC-Console.exe OSYNC-Console.cs
using System;
using System.Diagnostics;
using System.IO;
using System.Management;
using System.Net;
using System.Text;
using System.Threading;
using System.Windows.Forms;

static class OsyncConsole
{
    const string Title = "OSYNC Console";

    static void Msg(string text, MessageBoxIcon icon)
    {
        MessageBox.Show(text, Title, MessageBoxButtons.OK, icon);
    }

    static string Setting(string file, string key)
    {
        try
        {
            foreach (string line in File.ReadAllLines(file, Encoding.UTF8))
            {
                string l = line.Trim();
                if (l.StartsWith(key + "=", StringComparison.OrdinalIgnoreCase)) return l.Substring(key.Length + 1).Trim();
            }
        }
        catch { }
        return "";
    }

    // the console listens on 127.0.0.1:<port>. Only a TCP connect is tried: the server answers one request at a time
    // and /api/status takes a few seconds, so polling it with HTTP would queue requests and never get an answer in time
    // (a connect that sends nothing is closed by the server at once).
    static bool Alive(int port)
    {
        try
        {
            using (System.Net.Sockets.TcpClient c = new System.Net.Sockets.TcpClient())
            {
                IAsyncResult ar = c.BeginConnect(IPAddress.Loopback, port, null, null);
                if (!ar.AsyncWaitHandle.WaitOne(1000)) return false;
                c.EndConnect(ar);
                return true;
            }
        }
        catch { return false; }
    }

    static string FindEdge()
    {
        string[] c = {
            Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ProgramFilesX86), @"Microsoft\Edge\Application\msedge.exe"),
            Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ProgramFiles), @"Microsoft\Edge\Application\msedge.exe"),
            Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), @"Microsoft\Edge\Application\msedge.exe") };
        foreach (string p in c) if (File.Exists(p)) return p;
        return null;
    }

    // any Edge process still using the console's own browser profile = the console window is open
    static bool ProfileOpen(string profile)
    {
        try
        {
            using (ManagementObjectSearcher s = new ManagementObjectSearcher("SELECT CommandLine FROM Win32_Process WHERE Name='msedge.exe'"))
                foreach (ManagementObject o in s.Get())
                {
                    string cl = Convert.ToString(o["CommandLine"]);
                    if (cl.IndexOf(profile, StringComparison.OrdinalIgnoreCase) >= 0) return true;
                }
        }
        catch { }
        return false;
    }

    [STAThread]
    static int Main(string[] args)
    {
        string root = null;
        for (int i = 0; i < args.Length - 1; i++) if (args[i] == "--root") root = args[i + 1].TrimEnd('\\');
        if (root == null)
        {
            string here = AppDomain.CurrentDomain.BaseDirectory.TrimEnd('\\');
            DirectoryInfo up = Directory.GetParent(here); DirectoryInfo up2 = up == null ? null : up.Parent;
            if (File.Exists(Path.Combine(here, @"System\Scripts\Console-Server.ps1"))) root = here;
            else if (up2 != null && File.Exists(Path.Combine(up2.FullName, @"System\Scripts\Console-Server.ps1"))) root = up2.FullName;
        }
        if (root == null || !File.Exists(Path.Combine(root, @"System\Scripts\Console-Server.ps1")))
        {
            Msg("ไม่เจอโฟลเดอร์ OSYNC (System\\Scripts\\Console-Server.ps1)\nวาง OSYNC-Console.exe ไว้ใน <OSYNC>\\System\\Console", MessageBoxIcon.Error);
            return 1;
        }
        string settings = Path.Combine(root, @"Settings\settings.txt");

        string master = Setting(settings, "MasterPC");
        if (master.Length > 0 && !master.Equals(Environment.MachineName, StringComparison.OrdinalIgnoreCase))
        {
            Msg("คอนโซลใช้ได้เฉพาะเครื่องแม่ (" + master + ")\nเครื่องนี้คือ " + Environment.MachineName, MessageBoxIcon.Warning);
            return 2;
        }
        if (Directory.Exists(Path.Combine(root, "GAMELUNCHER")) && !Directory.Exists(Path.Combine(root, "Launchers"))
            && string.IsNullOrEmpty(Environment.GetEnvironmentVariable("OSYNC_LAUNCHERS")))
        {
            Msg("โฟลเดอร์ " + root + " ยังใช้โครงเดิม (GAMELUNCHER, GCafe)\n\nคอนโซลจะใช้ได้หลังย้ายระบบ:\nOSYNC.bat > 7 > 17 ตอนร้านปิดและเครื่องลูกปิดหมด", MessageBoxIcon.Information);
            return 2;
        }

        int port;
        if (!int.TryParse(Setting(settings, "ConsolePort"), out port) || port < 1 || port > 65535) port = 4666;
        string url = "http://127.0.0.1:" + port + "/";   // 18 Nov 2026: "localhost" tried IPv6 (::1) first = 2 s wait on EVERY request (the server listens on 127.0.0.1)

        Process server = null;
        if (!Alive(port))
        {
            ProcessStartInfo psi = new ProcessStartInfo(Path.Combine(Environment.SystemDirectory, @"WindowsPowerShell\v1.0\powershell.exe"),
                "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File \"" + Path.Combine(root, @"System\Scripts\Console-Server.ps1") + "\" -Port " + port);
            psi.UseShellExecute = false; psi.CreateNoWindow = true; psi.WorkingDirectory = root;
            psi.EnvironmentVariables.Remove("PSModulePath");   // PowerShell 7's module path breaks Windows PowerShell 5.1
            server = Process.Start(psi);
            Stopwatch sw = Stopwatch.StartNew();
            while (!Alive(port))
            {
                if (server.HasExited) { Msg("ตัวเซิร์ฟเวอร์คอนโซลปิดตัวเอง (exit " + server.ExitCode + ")\nลองรัน System\\Scripts\\Console-Server.ps1 เองเพื่อดูข้อความ", MessageBoxIcon.Error); return 3; }
                if (sw.Elapsed.TotalSeconds > 40) { try { server.Kill(); } catch { } Msg("คอนโซลไม่ตอบภายใน 40 วินาที (พอร์ต " + port + ")", MessageBoxIcon.Error); return 3; }
                Thread.Sleep(300);
            }
        }

        string edge = FindEdge();
        if (edge == null) { Process.Start(url); return 0; }   // no Edge: default browser, server keeps running
        string profile = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), @"OSYNC\ConsoleBrowser");
        Directory.CreateDirectory(profile);
        ProcessStartInfo e = new ProcessStartInfo(edge, "--app=" + url + " --user-data-dir=\"" + profile + "\" --no-first-run --no-default-browser-check --window-size=1320,900");
        e.UseShellExecute = false;
        Process.Start(e);

        if (server != null)
        {
            // started here: stop it when the console window is closed
            Thread.Sleep(4000);
            while (ProfileOpen(profile)) Thread.Sleep(2000);
            try { if (!server.HasExited) server.Kill(); } catch { }
        }
        return 0;
    }
}
