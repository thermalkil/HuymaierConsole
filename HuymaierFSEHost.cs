using System;
using System.Diagnostics;
using System.IO;
using System.Threading;

internal static class HuymaierFSEHost
{
    private const string FseEnvironmentVariable = "HUYMAIER_FSE_HOST";
    private const string UpdateHandoffFileName = "HuymaierConsoleFseUpdate.lock";

    private static bool WaitForUpdateHandoffToStart(string handoffPath)
    {
        if (File.Exists(handoffPath)) return true;
        DateTime deadline = DateTime.UtcNow.AddSeconds(2);
        while (DateTime.UtcNow < deadline)
        {
            Thread.Sleep(100);
            if (File.Exists(handoffPath)) return true;
        }
        return false;
    }

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

                    // The updater is a child of Huymaier Console, so there is a tiny
                    // scheduling window between Console exiting and the updater writing
                    // its handoff file. Give that child two seconds to arm the gate.
                    // When armed, keep this FSE home process alive until installation
                    // finishes, then launch the newly installed Console ourselves.
                    if (WaitForUpdateHandoffToStart(handoffPath))
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
