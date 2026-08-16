using System;
using System.Globalization;
using System.IO;

namespace HuymaierConsole.Modeling
{
    // HUYMAIER_GPU_SHELF_COMPILER_PROGRAM_V1
    public static class GpuShelfAssetCompilerProgram
    {
        private static string Arg(string[] args, string key, string fallback)
        {
            for (int i = 0; i + 1 < args.Length; i++)
                if (String.Equals(args[i], key, StringComparison.OrdinalIgnoreCase)) return args[i + 1];
            return fallback;
        }

        [STAThread]
        public static int Main(string[] args)
        {
            try
            {
                string model = Arg(args, "--model", "");
                string cache = Arg(args, "--cache", "");
                int size = Int32.Parse(Arg(args, "--size", GpuShelfAssetCompiler.DefaultShelfTextureSize.ToString(CultureInfo.InvariantCulture)), CultureInfo.InvariantCulture);
                if (String.IsNullOrWhiteSpace(model) || !File.Exists(model)) throw new FileNotFoundException("Shelf GLB was not found.", model);
                if (String.IsNullOrWhiteSpace(cache)) throw new ArgumentException("--cache is required.");
                GpuShelfAssetCompiler.EnsureCompiled(model, cache, size);
                return GpuShelfAssetCompiler.IsCacheCurrent(model, cache, size) ? 0 : 3;
            }
            catch (Exception ex)
            {
                try { Console.Error.WriteLine(ex.ToString()); } catch { }
                return 1;
            }
        }
    }
}
