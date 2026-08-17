using System;
using System.Diagnostics;
using System.IO;
using System.Threading;

internal static class HuymaierFSEHost
{
    private const string FseEnvironmentVariable = "HUYMAIER_FSE_HOST";
    private const string UpdateHandoffFileName = "HuymaierConsoleFseUpdate.lock";

    private static void WaitForUpdateHandoff(string handoffPath)
    {
        while (File.Exists(handoffPath))
        {
            try
            {
                DateTime written = File.GetLastWriteTimeUtc(handoffPath);
                if (written != DateTime.MinValue && DateTime.UtcNow - written > TimeSpan.FromMinutes(30))
                {
                    File.Delete(handoffPath);
                    break;
                }
            }
            catch { }
            Thread.Sleep(250);
        }
    }

    [STAThread]
    private static int Main(string[] args)
    {
        try
        {
            string localAppData = Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData);
            string installDir = Path.Combine(localAppData, "Huymaier Console");
            string executable = Path.Combine(installDir, "HuymaierConsole.exe");
            string handoffPath = Path.Combine(localAppData, UpdateHandoffFileName);

            while (true)
            {
                WaitForUpdateHandoff(handoffPath);
                if (!File.Exists(executable)) return 2;

                ProcessStartInfo startInfo = new ProcessStartInfo();
                startInfo.FileName = executable;
                startInfo.WorkingDirectory = installDir;
                startInfo.UseShellExecute = false;
                startInfo.CreateNoWindow = true;
                startInfo.WindowStyle = ProcessWindowStyle.Hidden;
                startInfo.EnvironmentVariables[FseEnvironmentVariable] = "1";

                using (Process process = Process.Start(startInfo))
                {
                    if (process == null) return 3;
                    process.WaitForExit();
                    int exitCode = process.ExitCode;

                    // A self-update intentionally closes Huymaier Console. Keep the
                    // Windows FSE home host alive while the external updater replaces
                    // the runtime, then launch the newly installed executable from
                    // this same host instead of letting Xbox/FSE mode immediately
                    // relaunch the old runtime and race the installer.
                    if (File.Exists(handoffPath))
                    {
                        WaitForUpdateHandoff(handoffPath);
                        continue;
                    }
                    return exitCode;
                }
            }
        }
        catch { return 1; }
    }
}
