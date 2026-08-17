using System;
using System.Collections.Generic;
using System.Drawing;
using System.Drawing.Imaging;
using System.IO;
using System.IO.Compression;
using System.Runtime.InteropServices;
using System.Text;
using System.Web.Script.Serialization;

namespace Huymaier.EmulatorPlatforms
{
    public sealed class P3TImportResult
    {
        public string Name { get; set; }
        public string Source { get; set; }
        public string OutputDirectory { get; set; }
        public List<string> Backgrounds { get; set; }
        public Dictionary<string, string> Icons { get; set; }
        public Dictionary<string, string> Sounds { get; set; }
        public List<string> Warnings { get; set; }
        public bool HasDynamicAssets { get; set; }

        public P3TImportResult()
        {
            Backgrounds = new List<string>();
            Icons = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase);
            Sounds = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase);
            Warnings = new List<string>();
        }
    }

    internal sealed class P3TAttribute
    {
        public uint Type, Handle, V2, V3;
        public string Name, Value;
    }

    internal sealed class P3TElement
    {
        public string Tag;
        public uint Offset;
        public uint ParentOffset;
        public Dictionary<string, P3TAttribute> Attributes = new Dictionary<string, P3TAttribute>(StringComparer.OrdinalIgnoreCase);
    }

    public static class P3TImporter
    {
        private static uint U32BE(BinaryReader br)
        {
            byte[] b = br.ReadBytes(4);
            if (b.Length != 4) throw new EndOfStreamException();
            return ((uint)b[0] << 24) | ((uint)b[1] << 16) | ((uint)b[2] << 8) | b[3];
        }

        private static string ReadCString(BinaryReader br, long offset)
        {
            long pos = br.BaseStream.Position;
            br.BaseStream.Position = offset;
            var bytes = new List<byte>();
            byte b;
            while (br.BaseStream.Position < br.BaseStream.Length && (b = br.ReadByte()) != 0) bytes.Add(b);
            br.BaseStream.Position = pos;
            return Encoding.UTF8.GetString(bytes.ToArray());
        }

        private static byte[] InflateZlib(byte[] input)
        {
            if (input == null || input.Length < 7) throw new InvalidDataException("Compressed theme resource is too small.");
            using (var source = new MemoryStream(input, 2, input.Length - 6))
            using (var deflate = new DeflateStream(source, CompressionMode.Decompress))
            using (var output = new MemoryStream())
            {
                deflate.CopyTo(output);
                return output.ToArray();
            }
        }

        private static void SaveGimAsPng(byte[] gim, string output)
        {
            if (gim.Length < 128 || gim[0] != 0x2e || gim[1] != 0x47 || gim[2] != 0x49 || gim[3] != 0x4d)
                throw new InvalidDataException("Theme icon is not a supported GIM resource.");
            int width = (gim[72] << 8) | gim[73];
            int height = (gim[74] << 8) | gim[75];
            if (width <= 0 || height <= 0 || width > 4096 || height > 4096) throw new InvalidDataException("Invalid GIM dimensions.");
            int expected = checked(width * height * 4);
            if (gim.Length < 128 + expected) throw new InvalidDataException("Truncated GIM pixel data.");

            using (var bmp = new Bitmap(width, height, PixelFormat.Format32bppArgb))
            {
                var rect = new Rectangle(0, 0, width, height);
                var data = bmp.LockBits(rect, ImageLockMode.WriteOnly, PixelFormat.Format32bppArgb);
                try
                {
                    byte[] bgra = new byte[expected];
                    int src = 128;
                    for (int i = 0; i < expected; i += 4)
                    {
                        bgra[i + 0] = gim[src + i + 2];
                        bgra[i + 1] = gim[src + i + 1];
                        bgra[i + 2] = gim[src + i + 0];
                        bgra[i + 3] = gim[src + i + 3];
                    }
                    Marshal.Copy(bgra, 0, data.Scan0, bgra.Length);
                }
                finally { bmp.UnlockBits(data); }
                bmp.Save(output, ImageFormat.Png);
            }
        }

        public static bool ConvertGimFile(string source, string output)
        {
            try
            {
                SaveGimAsPng(File.ReadAllBytes(source), output);
                return File.Exists(output);
            }
            catch { return false; }
        }

        public static bool ConvertVagFile(string source, string output)
        {
            try
            {
                ConvertVagToWav(File.ReadAllBytes(source), output);
                return File.Exists(output);
            }
            catch { return false; }
        }

        private static short Clamp16(int value)
        {
            if (value > 32767) return 32767;
            if (value < -32768) return -32768;
            return (short)value;
        }

        private static void ConvertVagToWav(byte[] vag, string output)
        {
            int start = 0;
            if (vag.Length >= 0x30 && vag[0] == (byte)'V' && vag[1] == (byte)'A' && vag[2] == (byte)'G') start = 0x30;
            int sampleRate = 48000;
            if (start == 0x30)
            {
                sampleRate = (int)(((uint)vag[0x10] << 24) | ((uint)vag[0x11] << 16) | ((uint)vag[0x12] << 8) | vag[0x13]);
                if (sampleRate < 8000 || sampleRate > 192000) sampleRate = 48000;
            }
            int[,] f = new int[,] { {0,0}, {60,0}, {115,-52}, {98,-55}, {122,-60} };
            int s1 = 0, s2 = 0;
            var samples = new List<short>();
            for (int p = start; p + 16 <= vag.Length; p += 16)
            {
                int predict = (vag[p] >> 4) & 0x0F;
                int shift = vag[p] & 0x0F;
                int flags = vag[p + 1];
                if (predict > 4) predict = 0;
                for (int i = 0; i < 28; i++)
                {
                    int packed = vag[p + 2 + (i >> 1)];
                    int nibble = ((i & 1) == 0) ? (packed & 0x0F) : ((packed >> 4) & 0x0F);
                    if (nibble >= 8) nibble -= 16;
                    int sample = (nibble << 12);
                    sample >>= shift;
                    sample += ((s1 * f[predict,0]) + (s2 * f[predict,1]) + 32) >> 6;
                    short clamped = Clamp16(sample);
                    samples.Add(clamped);
                    s2 = s1; s1 = clamped;
                }
                if (flags == 7) break;
            }
            using (var fs = File.Create(output))
            using (var bw = new BinaryWriter(fs))
            {
                int dataBytes = samples.Count * 2;
                bw.Write(Encoding.ASCII.GetBytes("RIFF")); bw.Write(36 + dataBytes);
                bw.Write(Encoding.ASCII.GetBytes("WAVEfmt ")); bw.Write(16); bw.Write((short)1); bw.Write((short)1);
                bw.Write(sampleRate); bw.Write(sampleRate * 2); bw.Write((short)2); bw.Write((short)16);
                bw.Write(Encoding.ASCII.GetBytes("data")); bw.Write(dataBytes);
                foreach (short s in samples) bw.Write(s);
            }
        }

        private static string SafeName(string value)
        {
            if (String.IsNullOrWhiteSpace(value)) return "resource";
            foreach (char c in Path.GetInvalidFileNameChars()) value = value.Replace(c, '_');
            return value.Trim();
        }

        public static string Import(string source, string destination)
        {
            if (!File.Exists(source)) throw new FileNotFoundException("P3T theme not found.", source);
            Directory.CreateDirectory(destination);
            var result = new P3TImportResult { Name = Path.GetFileNameWithoutExtension(source), Source = source, OutputDirectory = destination };

            using (var fs = File.OpenRead(source))
            using (var br = new BinaryReader(fs))
            {
                string magic = Encoding.ASCII.GetString(br.ReadBytes(4));
                if (magic != "P3TF") throw new InvalidDataException("The selected file is not a P3T theme.");
                uint version = U32BE(br);
                uint treeOffset = U32BE(br), treeSize = U32BE(br);
                uint idOffset = U32BE(br), idSize = U32BE(br);
                uint stringOffset = U32BE(br), stringSize = U32BE(br);
                uint intOffset = U32BE(br), intSize = U32BE(br);
                uint floatOffset = U32BE(br), floatSize = U32BE(br);
                uint fileOffset = U32BE(br), fileSize = U32BE(br);
                br.ReadBytes(8);
                if ((long)fileOffset + fileSize > fs.Length) throw new InvalidDataException("P3T file table extends beyond the file.");

                fs.Position = treeOffset;
                long treeEnd = (long)treeOffset + treeSize;
                var elements = new List<P3TElement>();
                while (fs.Position + 28 <= treeEnd)
                {
                    long elementPos = fs.Position;
                    uint tagString = U32BE(br);
                    uint attrCount = U32BE(br);
                    uint parent = U32BE(br);
                    U32BE(br); U32BE(br); U32BE(br); U32BE(br);
                    var element = new P3TElement {
                        Tag = ReadCString(br, (long)stringOffset + tagString),
                        Offset = (uint)(elementPos - treeOffset),
                        ParentOffset = parent
                    };
                    for (uint i = 0; i < attrCount; i++)
                    {
                        var a = new P3TAttribute { Handle = U32BE(br), Type = U32BE(br), V2 = U32BE(br), V3 = U32BE(br) };
                        a.Name = ReadCString(br, (long)stringOffset + a.Handle);
                        if (a.Type == 1) a.Value = a.V2.ToString();
                        else if (a.Type == 3)
                        {
                            long old = fs.Position; fs.Position = (long)stringOffset + a.V2;
                            a.Value = Encoding.UTF8.GetString(br.ReadBytes((int)a.V3)).TrimEnd('\0'); fs.Position = old;
                        }
                        else if (a.Type == 7)
                        {
                            long old = fs.Position; fs.Position = (long)idOffset + a.V2;
                            U32BE(br); a.Value = ReadCString(br, fs.Position); fs.Position = old;
                        }
                        element.Attributes[a.Name] = a;
                    }
                    elements.Add(element);
                }

                int bgIndex = 0, iconIndex = 0, soundIndex = 0, dynamicIndex = 0;
                foreach (var e in elements)
                {
                    string id = e.Attributes.ContainsKey("id") ? e.Attributes["id"].Value : e.Tag;
                    foreach (var pair in e.Attributes)
                    {
                        var a = pair.Value;
                        if (a.Type != 6 || a.V3 == 0) continue;
                        long resourcePos = (long)fileOffset + a.V2;
                        if (resourcePos < 0 || resourcePos + a.V3 > fs.Length) { result.Warnings.Add("Skipped invalid resource " + id); continue; }
                        long old = fs.Position; fs.Position = resourcePos; byte[] data = br.ReadBytes((int)a.V3); fs.Position = old;
                        try
                        {
                            if (e.Tag.Equals("bgimage", StringComparison.OrdinalIgnoreCase))
                            {
                                if (e.Attributes.ContainsKey("anim"))
                                {
                                    string outFile = Path.Combine(destination, "dynamic_" + (++dynamicIndex) + ".raf");
                                    File.WriteAllBytes(outFile, data); result.HasDynamicAssets = true;
                                    result.Warnings.Add("Dynamic RAF content was preserved but is not rendered in this build.");
                                }
                                else
                                {
                                    string outFile = Path.Combine(destination, "background_" + (++bgIndex) + ".jpg");
                                    File.WriteAllBytes(outFile, data); result.Backgrounds.Add(outFile);
                                }
                            }
                            else if (e.Tag.Equals("se", StringComparison.OrdinalIgnoreCase))
                            {
                                string key = SafeName(id + "_" + a.Name);
                                string vag = Path.Combine(destination, "sound_" + (++soundIndex) + "_" + key + ".vag");
                                string wav = Path.ChangeExtension(vag, ".wav");
                                File.WriteAllBytes(vag, data); ConvertVagToWav(data, wav); result.Sounds[key] = wav;
                            }
                            else
                            {
                                byte[] gim = InflateZlib(data);
                                string key = SafeName(id);
                                string outFile = Path.Combine(destination, "icon_" + (++iconIndex) + "_" + key + ".png");
                                SaveGimAsPng(gim, outFile); result.Icons[key] = outFile;
                            }
                        }
                        catch (Exception ex) { result.Warnings.Add("Could not convert " + id + ": " + ex.Message); }
                    }
                }
            }
            var serializer = new JavaScriptSerializer();
            string json = serializer.Serialize(result);
            File.WriteAllText(Path.Combine(destination, "theme-manifest.json"), json, Encoding.UTF8);
            return json;
        }
    }
}
