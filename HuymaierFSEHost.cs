using System;
using System.Diagnostics;
using System.IO;

internal static class HuymaierFSEHost
{
    [STAThread]
    private static int Main(string[] args)
    {
        try
        {
            string localAppData = Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData);
            string installDir = Path.Combine(localAppData, "Huymaier Console");
            string executable = Path.Combine(installDir, "HuymaierConsole.exe");
            if (!File.Exists(executable)) return 2;

            ProcessStartInfo startInfo = new ProcessStartInfo();
            startInfo.FileName = executable;
            startInfo.WorkingDirectory = installDir;
            startInfo.UseShellExecute = false;
            startInfo.CreateNoWindow = true;
            startInfo.WindowStyle = ProcessWindowStyle.Hidden;
            using (Process process = Process.Start(startInfo))
            {
                if (process == null) return 3;
                process.WaitForExit();
                return process.ExitCode;
            }
        }
        catch { return 1; }
    }
}
