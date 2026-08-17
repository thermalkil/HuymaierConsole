using System;
using System.Collections.Generic;
using System.Globalization;
using System.IO;
using System.Windows.Media;
using System.Windows.Media.Imaging;

namespace HuymaierConsole.Modeling
{
    // HUYMAIER_GPU_SHELF_ASSET_CACHE_V4
    // Converts authored glTF 2.0 GLBs into a compact GPU cache while retaining
    // every material feature used by the Huymaier model packs: base color,
    // emissive, metallic/roughness, normal and occlusion maps, multiple UV sets,
    // KHR_texture_transform, alpha modes, double-sided/unlit, specular,
    // clearcoat and emissive-strength metadata.
    public static class GpuShelfAssetCompiler
    {
        public const int CacheVersion = 4;
        public const int DefaultShelfTextureSize = 512;

        private sealed class TextureBinding
        {
            public int ImageIndex = -1;
            public int TexCoord = 0;
            public int WrapS = 10497;
            public int WrapT = 10497;
            public double OffsetX = 0.0;
            public double OffsetY = 0.0;
            public double ScaleX = 1.0;
            public double ScaleY = 1.0;
            public double Rotation = 0.0;
        }

        // 24 floats / 96 bytes. UVs are already transformed per material map; COLOR_0 is linear RGBA:
        // uv0=base, uv1=emissive, uv2=metallic-roughness, uv3=normal, uv4=occlusion.
        private struct Vertex
        {
            public float Px, Py, Pz;
            public float Nx, Ny, Nz;
            public float Tx, Ty, Tz, Tw;
            public float U0, V0;
            public float U1, V1;
            public float U2, V2;
            public float U3, V3;
            public float U4, V4;
            public float Cr, Cg, Cb, Ca;
        }

        private sealed class DrawBatch
        {
            public int FirstIndex;
            public int IndexCount;
            public int BaseImage = -1;
            public int EmissiveImage = -1;
            public int MetallicRoughnessImage = -1;
            public int NormalImage = -1;
            public int OcclusionImage = -1;
            public float Br = 1, Bg = 1, Bb = 1, Ba = 1;
            public float Er, Eg, Eb, EmissiveStrength = 1;
            public float Metallic = 1, Roughness = 1, Specular = 1, Clearcoat;
            public float NormalScale = 1, OcclusionStrength = 1;
            public int BaseWrapS = 10497, BaseWrapT = 10497;
            public int EmissiveWrapS = 10497, EmissiveWrapT = 10497;
            public int MetallicRoughnessWrapS = 10497, MetallicRoughnessWrapT = 10497;
            public int NormalWrapS = 10497, NormalWrapT = 10497;
            public int OcclusionWrapS = 10497, OcclusionWrapT = 10497;
            public int AlphaMode;
            public float AlphaCutoff = 0.5f;
            public int Flags;
        }

        private sealed class ImageData
        {
            public int Width;
            public int Height;
            public byte[] Bgra;
        }

        private static int ComponentSize(int componentType)
        {
            switch (componentType)
            {
                case 5120: case 5121: return 1;
                case 5122: case 5123: return 2;
                case 5125: case 5126: return 4;
                default: throw new NotSupportedException("Unsupported glTF component type " + componentType);
            }
        }

        private static int TypeComponents(string type)
        {
            switch (type)
            {
                case "SCALAR": return 1;
                case "VEC2": return 2;
                case "VEC3": return 3;
                case "VEC4": return 4;
                case "MAT2": return 4;
                case "MAT3": return 9;
                case "MAT4": return 16;
                default: return 1;
            }
        }

        private static double ReadComponent(byte[] data, int offset, int componentType, bool normalized)
        {
            switch (componentType)
            {
                case 5120: { sbyte v = unchecked((sbyte)data[offset]); return normalized ? Math.Max(-1.0, v / 127.0) : v; }
                case 5121: { byte v = data[offset]; return normalized ? v / 255.0 : v; }
                case 5122: { short v = BitConverter.ToInt16(data, offset); return normalized ? Math.Max(-1.0, v / 32767.0) : v; }
                case 5123: { ushort v = BitConverter.ToUInt16(data, offset); return normalized ? v / 65535.0 : v; }
                case 5125: { uint v = BitConverter.ToUInt32(data, offset); return normalized ? v / 4294967295.0 : v; }
                case 5126: return BitConverter.ToSingle(data, offset);
                default: return 0.0;
            }
        }

        private static double[][] ReadAccessor(GlbDocument doc, int accessorIndex)
        {
            if (accessorIndex < 0 || accessorIndex >= doc.Accessors.Count) return new double[0][];
            Dictionary<string, object> accessor = doc.Accessors[accessorIndex];
            int viewIndex = JsonUtil.Int(accessor, "bufferView", -1);
            if (viewIndex < 0 || viewIndex >= doc.BufferViews.Count) return new double[0][];
            Dictionary<string, object> view = doc.BufferViews[viewIndex];
            int count = JsonUtil.Int(accessor, "count", 0);
            int componentType = JsonUtil.Int(accessor, "componentType", 5126);
            string type = Convert.ToString(JsonUtil.Get(accessor, "type"), CultureInfo.InvariantCulture) ?? "SCALAR";
            int comps = TypeComponents(type);
            int size = ComponentSize(componentType);
            int stride = JsonUtil.Int(view, "byteStride", comps * size);
            int start = JsonUtil.Int(view, "byteOffset", 0) + JsonUtil.Int(accessor, "byteOffset", 0);
            bool normalized = JsonUtil.Bool(accessor, "normalized", false);
            double[][] result = new double[count][];
            for (int i = 0; i < count; i++)
            {
                int baseOffset = start + i * stride;
                if (baseOffset < 0 || baseOffset + comps * size > doc.Binary.Length) throw new InvalidDataException("GLB accessor exceeds BIN data.");
                double[] row = new double[comps];
                for (int c = 0; c < comps; c++) row[c] = ReadComponent(doc.Binary, baseOffset + c * size, componentType, normalized);
                result[i] = row;
            }
            return result;
        }

        private static int[] ReadIndices(GlbDocument doc, int accessorIndex, int fallbackCount)
        {
            if (accessorIndex < 0)
            {
                int[] sequential = new int[fallbackCount];
                for (int i = 0; i < fallbackCount; i++) sequential[i] = i;
                return sequential;
            }
            double[][] values = ReadAccessor(doc, accessorIndex);
            int[] result = new int[values.Length];
            for (int i = 0; i < values.Length; i++) result[i] = (int)values[i][0];
            return result;
        }

        private static double[] Identity()
        {
            return new double[] { 1,0,0,0, 0,1,0,0, 0,0,1,0, 0,0,0,1 };
        }

        private static double[] Multiply(double[] a, double[] b)
        {
            double[] r = new double[16];
            for (int c = 0; c < 4; c++)
                for (int row = 0; row < 4; row++)
                    r[c * 4 + row] =
                        a[0 * 4 + row] * b[c * 4 + 0] +
                        a[1 * 4 + row] * b[c * 4 + 1] +
                        a[2 * 4 + row] * b[c * 4 + 2] +
                        a[3 * 4 + row] * b[c * 4 + 3];
            return r;
        }

        private static double[] NodeMatrix(Dictionary<string, object> node)
        {
            object[] matrix = JsonUtil.Arr(JsonUtil.Get(node, "matrix"));
            if (matrix.Length == 16)
            {
                double[] values = new double[16];
                for (int i = 0; i < 16; i++) values[i] = Convert.ToDouble(matrix[i], CultureInfo.InvariantCulture);
                return values;
            }
            double sx = 1, sy = 1, sz = 1;
            object[] s = JsonUtil.Arr(JsonUtil.Get(node, "scale"));
            if (s.Length >= 3) { sx = Convert.ToDouble(s[0], CultureInfo.InvariantCulture); sy = Convert.ToDouble(s[1], CultureInfo.InvariantCulture); sz = Convert.ToDouble(s[2], CultureInfo.InvariantCulture); }
            double qx = 0, qy = 0, qz = 0, qw = 1;
            object[] q = JsonUtil.Arr(JsonUtil.Get(node, "rotation"));
            if (q.Length >= 4) { qx = Convert.ToDouble(q[0], CultureInfo.InvariantCulture); qy = Convert.ToDouble(q[1], CultureInfo.InvariantCulture); qz = Convert.ToDouble(q[2], CultureInfo.InvariantCulture); qw = Convert.ToDouble(q[3], CultureInfo.InvariantCulture); }
            double tx = 0, ty = 0, tz = 0;
            object[] t = JsonUtil.Arr(JsonUtil.Get(node, "translation"));
            if (t.Length >= 3) { tx = Convert.ToDouble(t[0], CultureInfo.InvariantCulture); ty = Convert.ToDouble(t[1], CultureInfo.InvariantCulture); tz = Convert.ToDouble(t[2], CultureInfo.InvariantCulture); }
            double xx = qx * qx, yy = qy * qy, zz = qz * qz;
            double xy = qx * qy, xz = qx * qz, yz = qy * qz;
            double wx = qw * qx, wy = qw * qy, wz = qw * qz;
            double[] m = Identity();
            m[0] = (1 - 2 * (yy + zz)) * sx; m[1] = (2 * (xy + wz)) * sx; m[2] = (2 * (xz - wy)) * sx;
            m[4] = (2 * (xy - wz)) * sy; m[5] = (1 - 2 * (xx + zz)) * sy; m[6] = (2 * (yz + wx)) * sy;
            m[8] = (2 * (xz + wy)) * sz; m[9] = (2 * (yz - wx)) * sz; m[10] = (1 - 2 * (xx + yy)) * sz;
            m[12] = tx; m[13] = ty; m[14] = tz;
            return m;
        }

        private static void TransformPoint(double[] m, double x, double y, double z, out double ox, out double oy, out double oz)
        {
            ox = m[0] * x + m[4] * y + m[8] * z + m[12];
            oy = m[1] * x + m[5] * y + m[9] * z + m[13];
            oz = m[2] * x + m[6] * y + m[10] * z + m[14];
        }

        private static void Normalize(ref double x, ref double y, ref double z)
        {
            double len = Math.Sqrt(x * x + y * y + z * z);
            if (len > 0.0000001) { x /= len; y /= len; z /= len; }
        }

        private static double Determinant3x3(double[] m)
        {
            return m[0] * (m[5] * m[10] - m[9] * m[6])
                 - m[4] * (m[1] * m[10] - m[9] * m[2])
                 + m[8] * (m[1] * m[6] - m[5] * m[2]);
        }

        private static void TransformNormal(double[] m, double x, double y, double z, out double ox, out double oy, out double oz)
        {
            double a00=m[0],a01=m[4],a02=m[8],a10=m[1],a11=m[5],a12=m[9],a20=m[2],a21=m[6],a22=m[10];
            double det=a00*(a11*a22-a12*a21)-a01*(a10*a22-a12*a20)+a02*(a10*a21-a11*a20);
            if (Math.Abs(det) < 0.0000000001)
            {
                ox=a00*x+a01*y+a02*z; oy=a10*x+a11*y+a12*z; oz=a20*x+a21*y+a22*z;
                Normalize(ref ox, ref oy, ref oz); return;
            }
            double inv00=(a11*a22-a12*a21)/det, inv01=(a02*a21-a01*a22)/det, inv02=(a01*a12-a02*a11)/det;
            double inv10=(a12*a20-a10*a22)/det, inv11=(a00*a22-a02*a20)/det, inv12=(a02*a10-a00*a12)/det;
            double inv20=(a10*a21-a11*a20)/det, inv21=(a01*a20-a00*a21)/det, inv22=(a00*a11-a01*a10)/det;
            ox=inv00*x+inv10*y+inv20*z; oy=inv01*x+inv11*y+inv21*z; oz=inv02*x+inv12*y+inv22*z;
            Normalize(ref ox, ref oy, ref oz);
        }

        private static void TransformDirection(double[] m, double x, double y, double z, out double ox, out double oy, out double oz)
        {
            ox=m[0]*x+m[4]*y+m[8]*z; oy=m[1]*x+m[5]*y+m[9]*z; oz=m[2]*x+m[6]*y+m[10]*z;
            Normalize(ref ox, ref oy, ref oz);
        }

        private static void FallbackTangent(double nx, double ny, double nz, out double tx, out double ty, out double tz)
        {
            if (Math.Abs(ny) < 0.90) { tx=nz; ty=0; tz=-nx; }
            else { tx=0; ty=-nz; tz=ny; }
            Normalize(ref tx, ref ty, ref tz);
            if (Math.Abs(tx)+Math.Abs(ty)+Math.Abs(tz) < 0.00001) { tx=1;ty=0;tz=0; }
        }

        // HUYMAIER_V0305_ADAPTIVE_WINDING_V1
        private static bool ShouldFlipWinding(List<Vertex> vertices, int baseVertex, int[] ix, bool fallbackMirrored)
        {
            if (vertices == null || ix == null || ix.Length < 3) return fallbackMirrored;
            int triangleCount = ix.Length / 3;
            int step = Math.Max(1, triangleCount / 64);
            int positive = 0, negative = 0, sampled = 0;
            for (int tri = 0; tri < triangleCount && sampled < 64; tri += step)
            {
                int offset = tri * 3;
                int ia = ix[offset], ib = ix[offset + 1], ic = ix[offset + 2];
                if (ia < 0 || ib < 0 || ic < 0 ||
                    baseVertex + ia >= vertices.Count || baseVertex + ib >= vertices.Count || baseVertex + ic >= vertices.Count) continue;
                Vertex a = vertices[baseVertex + ia], b = vertices[baseVertex + ib], c = vertices[baseVertex + ic];
                double ux = b.Px - a.Px, uy = b.Py - a.Py, uz = b.Pz - a.Pz;
                double vx = c.Px - a.Px, vy = c.Py - a.Py, vz = c.Pz - a.Pz;
                double gx = uy * vz - uz * vy, gy = uz * vx - ux * vz, gz = ux * vy - uy * vx;
                double nx = a.Nx + b.Nx + c.Nx, ny = a.Ny + b.Ny + c.Ny, nz = a.Nz + b.Nz + c.Nz;
                double gl2 = gx * gx + gy * gy + gz * gz, nl2 = nx * nx + ny * ny + nz * nz;
                if (gl2 < 1e-18 || nl2 < 1e-18) continue;
                double agreement = (gx * nx + gy * ny + gz * nz) / Math.Sqrt(gl2 * nl2);
                if (agreement > 0.05) positive++;
                else if (agreement < -0.05) negative++;
                sampled++;
            }
            if (positive + negative > 0 && positive != negative) return negative > positive;
            return fallbackMirrored;
        }
        private static double ArrDouble(object[] a, int i, double fallback)
        {
            if (a == null || i < 0 || i >= a.Length) return fallback;
            try { return Convert.ToDouble(a[i], CultureInfo.InvariantCulture); } catch { return fallback; }
        }

        private static TextureBinding ParseTexture(GlbDocument doc, Dictionary<string, object> info)
        {
            TextureBinding b = new TextureBinding();
            if (info == null || info.Count == 0) return b;
            int textureIndex = JsonUtil.Int(info, "index", -1);
            b.TexCoord = JsonUtil.Int(info, "texCoord", 0);
            Dictionary<string, object> ext = JsonUtil.Obj(JsonUtil.Get(info, "extensions"));
            Dictionary<string, object> tr = JsonUtil.Obj(JsonUtil.Get(ext, "KHR_texture_transform"));
            if (tr.Count > 0)
            {
                b.TexCoord = JsonUtil.Int(tr, "texCoord", b.TexCoord);
                object[] o = JsonUtil.Arr(JsonUtil.Get(tr, "offset"));
                object[] s = JsonUtil.Arr(JsonUtil.Get(tr, "scale"));
                b.OffsetX = ArrDouble(o, 0, 0); b.OffsetY = ArrDouble(o, 1, 0);
                b.ScaleX = ArrDouble(s, 0, 1); b.ScaleY = ArrDouble(s, 1, 1);
                b.Rotation = JsonUtil.Double(tr, "rotation", 0);
            }
            if (textureIndex >= 0 && textureIndex < doc.Textures.Count)
            {
                Dictionary<string, object> texture = doc.Textures[textureIndex];
                b.ImageIndex = JsonUtil.Int(texture, "source", -1);
                int sampler = JsonUtil.Int(texture, "sampler", -1);
                if (sampler >= 0 && sampler < doc.Samplers.Count)
                {
                    b.WrapS = JsonUtil.Int(doc.Samplers[sampler], "wrapS", 10497);
                    b.WrapT = JsonUtil.Int(doc.Samplers[sampler], "wrapT", 10497);
                }
            }
            return b;
        }

        private static TextureBinding BaseTexture(GlbDocument doc, Dictionary<string, object> material)
        {
            Dictionary<string, object> pbr = JsonUtil.Obj(JsonUtil.Get(material, "pbrMetallicRoughness"));
            Dictionary<string, object> info = JsonUtil.Obj(JsonUtil.Get(pbr, "baseColorTexture"));
            if (info.Count > 0) return ParseTexture(doc, info);
            Dictionary<string, object> ext = JsonUtil.Obj(JsonUtil.Get(material, "extensions"));
            Dictionary<string, object> sg = JsonUtil.Obj(JsonUtil.Get(ext, "KHR_materials_pbrSpecularGlossiness"));
            return ParseTexture(doc, JsonUtil.Obj(JsonUtil.Get(sg, "diffuseTexture")));
        }

        private static TextureBinding EmissiveTexture(GlbDocument doc, Dictionary<string, object> material) { return ParseTexture(doc, JsonUtil.Obj(JsonUtil.Get(material, "emissiveTexture"))); }
        private static TextureBinding MetallicRoughnessTexture(GlbDocument doc, Dictionary<string, object> material)
        {
            Dictionary<string, object> pbr=JsonUtil.Obj(JsonUtil.Get(material,"pbrMetallicRoughness"));
            return ParseTexture(doc,JsonUtil.Obj(JsonUtil.Get(pbr,"metallicRoughnessTexture")));
        }
        private static TextureBinding NormalTexture(GlbDocument doc, Dictionary<string, object> material) { return ParseTexture(doc, JsonUtil.Obj(JsonUtil.Get(material, "normalTexture"))); }
        private static TextureBinding OcclusionTexture(GlbDocument doc, Dictionary<string, object> material) { return ParseTexture(doc, JsonUtil.Obj(JsonUtil.Get(material, "occlusionTexture"))); }

        // HC3D v3 stores authored/transformed glTF UVs directly. No hidden V
        // inversion is carried in the cache or shader anymore.
        private static void TransformUv(TextureBinding b, double u, double v, out float ou, out float ov)
        {
            if (b == null) { ou = (float)u; ov = (float)v; return; }
            double su = u * b.ScaleX, sv = v * b.ScaleY;
            if (Math.Abs(b.Rotation) > 0.0000001)
            {
                double c = Math.Cos(b.Rotation), s = Math.Sin(b.Rotation);
                double ru = c * su - s * sv, rv = s * su + c * sv;
                su = ru; sv = rv;
            }
            su += b.OffsetX; sv += b.OffsetY;
            ou = (float)su; ov = (float)sv;
        }

        private static DrawBatch MaterialBatch(GlbDocument doc, int materialIndex)
        {
            DrawBatch b = new DrawBatch();
            if (materialIndex < 0 || materialIndex >= doc.Materials.Count) return b;
            Dictionary<string, object> m = doc.Materials[materialIndex];
            Dictionary<string, object> pbr = JsonUtil.Obj(JsonUtil.Get(m, "pbrMetallicRoughness"));
            Dictionary<string, object> ext = JsonUtil.Obj(JsonUtil.Get(m, "extensions"));
            Dictionary<string, object> sg = JsonUtil.Obj(JsonUtil.Get(ext, "KHR_materials_pbrSpecularGlossiness"));
            object[] f = JsonUtil.Arr(JsonUtil.Get(pbr, "baseColorFactor"));
            if (sg.Count > 0 && JsonUtil.Arr(JsonUtil.Get(sg, "diffuseFactor")).Length >= 3) f = JsonUtil.Arr(JsonUtil.Get(sg, "diffuseFactor"));
            b.Br = (float)ArrDouble(f, 0, 1); b.Bg = (float)ArrDouble(f, 1, 1); b.Bb = (float)ArrDouble(f, 2, 1); b.Ba = (float)ArrDouble(f, 3, 1);
            object[] ef = JsonUtil.Arr(JsonUtil.Get(m, "emissiveFactor"));
            b.Er = (float)ArrDouble(ef, 0, 0); b.Eg = (float)ArrDouble(ef, 1, 0); b.Eb = (float)ArrDouble(ef, 2, 0);
            Dictionary<string, object> es = JsonUtil.Obj(JsonUtil.Get(ext, "KHR_materials_emissive_strength"));
            b.EmissiveStrength = (float)Math.Max(0, JsonUtil.Double(es, "emissiveStrength", 1));
            b.Metallic = (float)Math.Max(0, Math.Min(1, JsonUtil.Double(pbr, "metallicFactor", 1)));
            b.Roughness = (float)Math.Max(0, Math.Min(1, JsonUtil.Double(pbr, "roughnessFactor", 1)));
            if (sg.Count > 0)
            {
                b.Metallic=0.0f;
                b.Roughness = 1.0f - (float)Math.Max(0, Math.Min(1, JsonUtil.Double(sg, "glossinessFactor", 1)));
            }
            Dictionary<string, object> sp = JsonUtil.Obj(JsonUtil.Get(ext, "KHR_materials_specular"));
            b.Specular = (float)Math.Max(0, Math.Min(1, JsonUtil.Double(sp, "specularFactor", 1)));
            Dictionary<string, object> cc = JsonUtil.Obj(JsonUtil.Get(ext, "KHR_materials_clearcoat"));
            b.Clearcoat = (float)Math.Max(0, Math.Min(1, JsonUtil.Double(cc, "clearcoatFactor", 0)));
            Dictionary<string, object> ntInfo=JsonUtil.Obj(JsonUtil.Get(m,"normalTexture"));
            Dictionary<string, object> ocInfo=JsonUtil.Obj(JsonUtil.Get(m,"occlusionTexture"));
            b.NormalScale=(float)Math.Max(0,JsonUtil.Double(ntInfo,"scale",1));
            b.OcclusionStrength=(float)Math.Max(0,Math.Min(1,JsonUtil.Double(ocInfo,"strength",1)));
            string alpha = Convert.ToString(JsonUtil.Get(m, "alphaMode"), CultureInfo.InvariantCulture) ?? "OPAQUE";
            b.AlphaMode = String.Equals(alpha, "BLEND", StringComparison.OrdinalIgnoreCase) ? 2 : (String.Equals(alpha, "MASK", StringComparison.OrdinalIgnoreCase) ? 1 : 0);
            b.AlphaCutoff = (float)JsonUtil.Double(m, "alphaCutoff", 0.5);
            if (JsonUtil.Bool(m, "doubleSided", false)) b.Flags |= 1;
            if (JsonUtil.Obj(JsonUtil.Get(ext, "KHR_materials_unlit")).Count > 0) b.Flags |= 2;
            TextureBinding bt=BaseTexture(doc,m), et=EmissiveTexture(doc,m), mt=MetallicRoughnessTexture(doc,m), nt=NormalTexture(doc,m), ot=OcclusionTexture(doc,m);
            b.BaseImage=bt.ImageIndex;b.BaseWrapS=bt.WrapS;b.BaseWrapT=bt.WrapT;
            b.EmissiveImage=et.ImageIndex;b.EmissiveWrapS=et.WrapS;b.EmissiveWrapT=et.WrapT;
            b.MetallicRoughnessImage=mt.ImageIndex;b.MetallicRoughnessWrapS=mt.WrapS;b.MetallicRoughnessWrapT=mt.WrapT;
            b.NormalImage=nt.ImageIndex;b.NormalWrapS=nt.WrapS;b.NormalWrapT=nt.WrapT;
            b.OcclusionImage=ot.ImageIndex;b.OcclusionWrapS=ot.WrapS;b.OcclusionWrapT=ot.WrapT;
            return b;
        }

        private static ImageData DecodeImage(GlbDocument doc, int imageIndex, int maxTextureDimension)
        {
            if (imageIndex < 0 || imageIndex >= doc.Images.Count) return null;
            Dictionary<string, object> image = doc.Images[imageIndex];
            int viewIndex = JsonUtil.Int(image, "bufferView", -1);
            if (viewIndex < 0 || viewIndex >= doc.BufferViews.Count) return null;
            Dictionary<string, object> view = doc.BufferViews[viewIndex];
            int offset = JsonUtil.Int(view, "byteOffset", 0), length = JsonUtil.Int(view, "byteLength", 0);
            if (offset < 0 || length <= 0 || offset + length > doc.Binary.Length) return null;
            byte[] encoded = new byte[length]; Buffer.BlockCopy(doc.Binary, offset, encoded, 0, length);
            using (MemoryStream probe = new MemoryStream(encoded, false))
            {
                BitmapDecoder decoder = BitmapDecoder.Create(probe, BitmapCreateOptions.PreservePixelFormat, BitmapCacheOption.OnDemand);
                BitmapFrame frame = decoder.Frames[0];
                int ow = frame.PixelWidth, oh = frame.PixelHeight, max = Math.Max(ow, oh);
                double scale = max > maxTextureDimension ? maxTextureDimension / (double)max : 1.0;
                int tw = Math.Max(1, (int)Math.Round(ow * scale)); int th = Math.Max(1, (int)Math.Round(oh * scale));
                using (MemoryStream ms = new MemoryStream(encoded, false))
                {
                    BitmapImage bitmap = new BitmapImage(); bitmap.BeginInit(); bitmap.CacheOption = BitmapCacheOption.OnLoad; bitmap.CreateOptions = BitmapCreateOptions.PreservePixelFormat;
                    if (ow >= oh) bitmap.DecodePixelWidth = tw; else bitmap.DecodePixelHeight = th;
                    bitmap.StreamSource = ms; bitmap.EndInit();
                    BitmapSource source = bitmap.Format == PixelFormats.Bgra32 ? (BitmapSource)bitmap : new FormatConvertedBitmap(bitmap, PixelFormats.Bgra32, null, 0);
                    if (source.CanFreeze) source.Freeze(); int stride = source.PixelWidth * 4; byte[] pixels = new byte[stride * source.PixelHeight]; source.CopyPixels(pixels, stride, 0);
                    return new ImageData { Width = source.PixelWidth, Height = source.PixelHeight, Bgra = pixels };
                }
            }
        }

        private static double[][] UvsFor(GlbDocument doc, Dictionary<string, object> attrs, TextureBinding binding)
        {
            int set=binding==null?0:binding.TexCoord;
            int accessor=JsonUtil.Int(attrs,"TEXCOORD_"+set.ToString(CultureInfo.InvariantCulture),-1);
            if(accessor<0&&set!=0)accessor=JsonUtil.Int(attrs,"TEXCOORD_0",-1);
            return ReadAccessor(doc,accessor);
        }

        private static void EmitNode(GlbDocument doc, int nodeIndex, double[] parent, HashSet<int> stack, List<Vertex> vertices, List<uint> indices, List<DrawBatch> draws, ref double minX, ref double minY, ref double minZ, ref double maxX, ref double maxY, ref double maxZ)
        {
            if (nodeIndex < 0 || nodeIndex >= doc.Nodes.Count || stack.Contains(nodeIndex)) return;
            stack.Add(nodeIndex); Dictionary<string, object> node = doc.Nodes[nodeIndex]; double[] world = Multiply(parent, NodeMatrix(node));
            int meshIndex = JsonUtil.Int(node, "mesh", -1);
            if (meshIndex >= 0 && meshIndex < doc.Meshes.Count)
            {
                object[] primitives = JsonUtil.Arr(JsonUtil.Get(doc.Meshes[meshIndex], "primitives"));
                for (int p = 0; p < primitives.Length; p++)
                {
                    Dictionary<string, object> primitive = JsonUtil.Obj(primitives[p]); if (JsonUtil.Int(primitive, "mode", 4) != 4) continue;
                    Dictionary<string, object> attrs = JsonUtil.Obj(JsonUtil.Get(primitive, "attributes")); int pa = JsonUtil.Int(attrs, "POSITION", -1); if (pa < 0) continue;
                    double[][] pos = ReadAccessor(doc, pa); double[][] normals = ReadAccessor(doc, JsonUtil.Int(attrs, "NORMAL", -1)); double[][] tangents=ReadAccessor(doc,JsonUtil.Int(attrs,"TANGENT",-1)); double[][] colors=ReadAccessor(doc,JsonUtil.Int(attrs,"COLOR_0",-1));
                    int materialIndex = JsonUtil.Int(primitive, "material", -1);
                    Dictionary<string, object> material = materialIndex >= 0 && materialIndex < doc.Materials.Count ? doc.Materials[materialIndex] : new Dictionary<string, object>();
                    TextureBinding bt=BaseTexture(doc,material),et=EmissiveTexture(doc,material),mt=MetallicRoughnessTexture(doc,material),nt=NormalTexture(doc,material),ot=OcclusionTexture(doc,material);
                    double[][] uv0=UvsFor(doc,attrs,bt),uv1=UvsFor(doc,attrs,et),uv2=UvsFor(doc,attrs,mt),uv3=UvsFor(doc,attrs,nt),uv4=UvsFor(doc,attrs,ot);
                    int baseVertex=vertices.Count; bool mirrored=Determinant3x3(world)<-0.0000000001;
                    for(int i=0;i<pos.Length;i++)
                    {
                        double x,y,z;TransformPoint(world,pos[i][0],pos[i][1],pos[i][2],out x,out y,out z);
                        double nx=0,ny=1,nz=0;if(normals.Length==pos.Length)TransformNormal(world,normals[i][0],normals[i][1],normals[i][2],out nx,out ny,out nz);
                        double tx,ty,tz,tw=1;
                        if(tangents.Length==pos.Length&&tangents[i].Length>=3){TransformDirection(world,tangents[i][0],tangents[i][1],tangents[i][2],out tx,out ty,out tz);tw=tangents[i].Length>3?tangents[i][3]:1;double dot=tx*nx+ty*ny+tz*nz;tx-=dot*nx;ty-=dot*ny;tz-=dot*nz;Normalize(ref tx,ref ty,ref tz);}else{FallbackTangent(nx,ny,nz,out tx,out ty,out tz);}
                        if(mirrored)tw=-tw;float cr=1,cg=1,cb=1,ca=1;if(colors.Length==pos.Length&&colors[i].Length>=3){cr=(float)Math.Max(0,Math.Min(1,colors[i][0]));cg=(float)Math.Max(0,Math.Min(1,colors[i][1]));cb=(float)Math.Max(0,Math.Min(1,colors[i][2]));ca=colors[i].Length>3?(float)Math.Max(0,Math.Min(1,colors[i][3])):1f;}
                        float u0=0,v0=0,u1=0,v1=0,u2=0,v2=0,u3=0,v3=0,u4=0,v4=0;
                        if(uv0.Length==pos.Length)TransformUv(bt,uv0[i][0],uv0[i][1],out u0,out v0);
                        if(uv1.Length==pos.Length)TransformUv(et,uv1[i][0],uv1[i][1],out u1,out v1);else{u1=u0;v1=v0;}
                        if(uv2.Length==pos.Length)TransformUv(mt,uv2[i][0],uv2[i][1],out u2,out v2);else{u2=u0;v2=v0;}
                        if(uv3.Length==pos.Length)TransformUv(nt,uv3[i][0],uv3[i][1],out u3,out v3);else{u3=u0;v3=v0;}
                        if(uv4.Length==pos.Length)TransformUv(ot,uv4[i][0],uv4[i][1],out u4,out v4);else{u4=u0;v4=v0;}
                        vertices.Add(new Vertex{Px=(float)x,Py=(float)y,Pz=(float)z,Nx=(float)nx,Ny=(float)ny,Nz=(float)nz,Tx=(float)tx,Ty=(float)ty,Tz=(float)tz,Tw=(float)tw,U0=u0,V0=v0,U1=u1,V1=v1,U2=u2,V2=v2,U3=u3,V3=v3,U4=u4,V4=v4,Cr=cr,Cg=cg,Cb=cb,Ca=ca});
                        minX=Math.Min(minX,x);minY=Math.Min(minY,y);minZ=Math.Min(minZ,z);maxX=Math.Max(maxX,x);maxY=Math.Max(maxY,y);maxZ=Math.Max(maxZ,z);
                    }
                    int[] ix=ReadIndices(doc,JsonUtil.Int(primitive,"indices",-1),pos.Length);DrawBatch batch=MaterialBatch(doc,materialIndex);batch.FirstIndex=indices.Count;batch.IndexCount=ix.Length;
                    bool flipWinding=ShouldFlipWinding(vertices,baseVertex,ix,mirrored);
                    if(flipWinding){for(int i=0;i+2<ix.Length;i+=3){indices.Add((uint)(baseVertex+ix[i]));indices.Add((uint)(baseVertex+ix[i+2]));indices.Add((uint)(baseVertex+ix[i+1]));}}
                    else{for(int i=0;i<ix.Length;i++)indices.Add((uint)(baseVertex+ix[i]));}
                    draws.Add(batch);
                }
            }
            object[] children=JsonUtil.Arr(JsonUtil.Get(node,"children"));for(int i=0;i<children.Length;i++)EmitNode(doc,Convert.ToInt32(children[i],CultureInfo.InvariantCulture),world,stack,vertices,indices,draws,ref minX,ref minY,ref minZ,ref maxX,ref maxY,ref maxZ);stack.Remove(nodeIndex);
        }

        public static bool IsCacheCurrent(string glbPath, string cachePath, int maxTextureDimension)
        {
            try{FileInfo source=new FileInfo(glbPath);using(BinaryReader br=new BinaryReader(File.OpenRead(cachePath))){if(new string(br.ReadChars(4))!="HC3D")return false;if(br.ReadInt32()!=CacheVersion)return false;return br.ReadInt64()==source.Length&&br.ReadInt64()==source.LastWriteTimeUtc.Ticks&&br.ReadInt32()==maxTextureDimension;}}catch{return false;}
        }

        public static void Compile(string glbPath, string cachePath, int maxTextureDimension)
        {
            if(String.IsNullOrWhiteSpace(glbPath)||!File.Exists(glbPath))throw new FileNotFoundException("GPU shelf GLB was not found.",glbPath);maxTextureDimension=Math.Max(128,Math.Min(2048,maxTextureDimension));FileInfo sourceInfo=new FileInfo(glbPath);GlbDocument doc=GlbLoader.Read(glbPath);
            List<Vertex> vertices=new List<Vertex>();List<uint> indices=new List<uint>();List<DrawBatch> draws=new List<DrawBatch>();double minX=Double.PositiveInfinity,minY=Double.PositiveInfinity,minZ=Double.PositiveInfinity,maxX=Double.NegativeInfinity,maxY=Double.NegativeInfinity,maxZ=Double.NegativeInfinity;
            int sceneIndex=JsonUtil.Int(doc.Root,"scene",0);object[] roots=doc.Scenes.Count>0&&sceneIndex>=0&&sceneIndex<doc.Scenes.Count?JsonUtil.Arr(JsonUtil.Get(doc.Scenes[sceneIndex],"nodes")):new object[0];
            if(roots.Length==0){HashSet<int> children=new HashSet<int>();for(int i=0;i<doc.Nodes.Count;i++)foreach(object c in JsonUtil.Arr(JsonUtil.Get(doc.Nodes[i],"children")))children.Add(Convert.ToInt32(c,CultureInfo.InvariantCulture));List<object> rootList=new List<object>();for(int i=0;i<doc.Nodes.Count;i++)if(!children.Contains(i))rootList.Add(i);roots=rootList.ToArray();}
            for(int i=0;i<roots.Length;i++)EmitNode(doc,Convert.ToInt32(roots[i],CultureInfo.InvariantCulture),Identity(),new HashSet<int>(),vertices,indices,draws,ref minX,ref minY,ref minZ,ref maxX,ref maxY,ref maxZ);
            if(vertices.Count==0||indices.Count==0||draws.Count==0)throw new InvalidDataException("GLB produced no GPU shelf triangle batches.");
            List<ImageData> images=new List<ImageData>();for(int i=0;i<doc.Images.Count;i++)images.Add(DecodeImage(doc,i,maxTextureDimension));
            string dir=Path.GetDirectoryName(cachePath);if(!String.IsNullOrWhiteSpace(dir))Directory.CreateDirectory(dir);string temp=cachePath+".tmp-"+Guid.NewGuid().ToString("N");
            try{using(BinaryWriter bw=new BinaryWriter(File.Create(temp))){bw.Write(new char[]{'H','C','3','D'});bw.Write(CacheVersion);bw.Write(sourceInfo.Length);bw.Write(sourceInfo.LastWriteTimeUtc.Ticks);bw.Write(maxTextureDimension);bw.Write(vertices.Count);bw.Write(indices.Count);bw.Write(draws.Count);bw.Write(images.Count);bw.Write((float)minX);bw.Write((float)minY);bw.Write((float)minZ);bw.Write((float)maxX);bw.Write((float)maxY);bw.Write((float)maxZ);
                foreach(Vertex v in vertices){bw.Write(v.Px);bw.Write(v.Py);bw.Write(v.Pz);bw.Write(v.Nx);bw.Write(v.Ny);bw.Write(v.Nz);bw.Write(v.Tx);bw.Write(v.Ty);bw.Write(v.Tz);bw.Write(v.Tw);bw.Write(v.U0);bw.Write(v.V0);bw.Write(v.U1);bw.Write(v.V1);bw.Write(v.U2);bw.Write(v.V2);bw.Write(v.U3);bw.Write(v.V3);bw.Write(v.U4);bw.Write(v.V4);bw.Write(v.Cr);bw.Write(v.Cg);bw.Write(v.Cb);bw.Write(v.Ca);}foreach(uint ix in indices)bw.Write(ix);
                foreach(DrawBatch d in draws){bw.Write(d.FirstIndex);bw.Write(d.IndexCount);bw.Write(d.BaseImage);bw.Write(d.EmissiveImage);bw.Write(d.MetallicRoughnessImage);bw.Write(d.NormalImage);bw.Write(d.OcclusionImage);bw.Write(d.Br);bw.Write(d.Bg);bw.Write(d.Bb);bw.Write(d.Ba);bw.Write(d.Er);bw.Write(d.Eg);bw.Write(d.Eb);bw.Write(d.EmissiveStrength);bw.Write(d.Metallic);bw.Write(d.Roughness);bw.Write(d.Specular);bw.Write(d.Clearcoat);bw.Write(d.NormalScale);bw.Write(d.OcclusionStrength);bw.Write(d.BaseWrapS);bw.Write(d.BaseWrapT);bw.Write(d.EmissiveWrapS);bw.Write(d.EmissiveWrapT);bw.Write(d.MetallicRoughnessWrapS);bw.Write(d.MetallicRoughnessWrapT);bw.Write(d.NormalWrapS);bw.Write(d.NormalWrapT);bw.Write(d.OcclusionWrapS);bw.Write(d.OcclusionWrapT);bw.Write(d.AlphaMode);bw.Write(d.AlphaCutoff);bw.Write(d.Flags);}foreach(ImageData image in images){if(image==null){bw.Write(0);bw.Write(0);bw.Write(0);continue;}bw.Write(image.Width);bw.Write(image.Height);bw.Write(image.Bgra.Length);bw.Write(image.Bgra);}}
                if(File.Exists(cachePath))File.Delete(cachePath);File.Move(temp,cachePath);}finally{if(File.Exists(temp))try{File.Delete(temp);}catch{}}
        }

        public static string EnsureCompiled(string glbPath, string cachePath, int maxTextureDimension){if(!IsCacheCurrent(glbPath,cachePath,maxTextureDimension))Compile(glbPath,cachePath,maxTextureDimension);return cachePath;}
    }
}









