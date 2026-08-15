using System;
using System.Collections;
using System.Collections.Generic;
using System.Globalization;
using System.IO;
using System.Text;
using System.Web.Script.Serialization;
using System.Windows;
using System.Windows.Media;
using System.Windows.Media.Imaging;
using System.Windows.Media.Media3D;

namespace HuymaierConsole.Modeling
{
    internal sealed class GlbDocument
    {
        public Dictionary<string, object> Root;
        public byte[] Binary;
        public List<Dictionary<string, object>> BufferViews;
        public List<Dictionary<string, object>> Accessors;
        public List<Dictionary<string, object>> Materials;
        public List<Dictionary<string, object>> Textures;
        public List<Dictionary<string, object>> Images;
        public List<Dictionary<string, object>> Meshes;
        public List<Dictionary<string, object>> Nodes;
        public List<Dictionary<string, object>> Scenes;
    }

    internal static class JsonUtil
    {
        public static Dictionary<string, object> Obj(object value)
        {
            Dictionary<string, object> dict = value as Dictionary<string, object>;
            return dict ?? new Dictionary<string, object>(StringComparer.OrdinalIgnoreCase);
        }
        public static object[] Arr(object value)
        {
            object[] a = value as object[];
            if (a != null) return a;
            ArrayList al = value as ArrayList;
            if (al != null) return al.ToArray();
            return new object[0];
        }
        public static object Get(Dictionary<string, object> d, string key)
        {
            if (d == null) return null;
            object value;
            return d.TryGetValue(key, out value) ? value : null;
        }
        public static int Int(Dictionary<string, object> d, string key, int fallback)
        {
            object v = Get(d, key);
            if (v == null) return fallback;
            try { return Convert.ToInt32(v, CultureInfo.InvariantCulture); } catch { return fallback; }
        }
        public static double Double(Dictionary<string, object> d, string key, double fallback)
        {
            object v = Get(d, key);
            if (v == null) return fallback;
            try { return Convert.ToDouble(v, CultureInfo.InvariantCulture); } catch { return fallback; }
        }
        public static bool Bool(Dictionary<string, object> d, string key, bool fallback)
        {
            object v = Get(d, key);
            if (v == null) return fallback;
            try { return Convert.ToBoolean(v, CultureInfo.InvariantCulture); } catch { return fallback; }
        }
        public static List<Dictionary<string, object>> ObjList(Dictionary<string, object> root, string key)
        {
            List<Dictionary<string, object>> result = new List<Dictionary<string, object>>();
            object[] values = Arr(Get(root, key));
            for (int i = 0; i < values.Length; i++) result.Add(Obj(values[i]));
            return result;
        }
    }

    internal static class GlbLoader
    {
        private static readonly Brush DefaultBrush = new SolidColorBrush(Color.FromRgb(190, 196, 206));

        public static GlbDocument Read(string path)
        {
            using (FileStream fs = File.OpenRead(path))
            using (BinaryReader br = new BinaryReader(fs))
            {
                if (Encoding.ASCII.GetString(br.ReadBytes(4)) != "glTF") throw new InvalidDataException("Not a GLB file.");
                UInt32 version = br.ReadUInt32();
                if (version != 2) throw new InvalidDataException("Only glTF 2.0 GLB files are supported.");
                UInt32 total = br.ReadUInt32();
                byte[] jsonBytes = null;
                byte[] binBytes = null;
                while (fs.Position + 8 <= total)
                {
                    UInt32 length = br.ReadUInt32();
                    UInt32 type = br.ReadUInt32();
                    byte[] chunk = br.ReadBytes((int)length);
                    if (type == 0x4E4F534A) jsonBytes = chunk;
                    else if (type == 0x004E4942) binBytes = chunk;
                }
                if (jsonBytes == null || binBytes == null) throw new InvalidDataException("GLB is missing JSON or BIN data.");
                string json = Encoding.UTF8.GetString(jsonBytes).TrimEnd('\0', ' ', '\t', '\r', '\n');
                JavaScriptSerializer serializer = new JavaScriptSerializer();
                serializer.MaxJsonLength = Int32.MaxValue;
                serializer.RecursionLimit = 256;
                Dictionary<string, object> root = JsonUtil.Obj(serializer.DeserializeObject(json));
                GlbDocument doc = new GlbDocument();
                doc.Root = root;
                doc.Binary = binBytes;
                doc.BufferViews = JsonUtil.ObjList(root, "bufferViews");
                doc.Accessors = JsonUtil.ObjList(root, "accessors");
                doc.Materials = JsonUtil.ObjList(root, "materials");
                doc.Textures = JsonUtil.ObjList(root, "textures");
                doc.Images = JsonUtil.ObjList(root, "images");
                doc.Meshes = JsonUtil.ObjList(root, "meshes");
                doc.Nodes = JsonUtil.ObjList(root, "nodes");
                doc.Scenes = JsonUtil.ObjList(root, "scenes");
                return doc;
            }
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
                case 5120:
                    sbyte sb = unchecked((sbyte)data[offset]);
                    return normalized ? Math.Max(-1.0, sb / 127.0) : sb;
                case 5121:
                    byte ub = data[offset];
                    return normalized ? ub / 255.0 : ub;
                case 5122:
                    short ss = BitConverter.ToInt16(data, offset);
                    return normalized ? Math.Max(-1.0, ss / 32767.0) : ss;
                case 5123:
                    ushort us = BitConverter.ToUInt16(data, offset);
                    return normalized ? us / 65535.0 : us;
                case 5125:
                    UInt32 ui = BitConverter.ToUInt32(data, offset);
                    return normalized ? ui / 4294967295.0 : ui;
                case 5126:
                    return BitConverter.ToSingle(data, offset);
                default:
                    return 0.0;
            }
        }

        private static double[][] ReadAccessor(GlbDocument doc, int accessorIndex)
        {
            Dictionary<string, object> accessor = doc.Accessors[accessorIndex];
            int viewIndex = JsonUtil.Int(accessor, "bufferView", -1);
            if (viewIndex < 0) return new double[0][];
            Dictionary<string, object> view = doc.BufferViews[viewIndex];
            int count = JsonUtil.Int(accessor, "count", 0);
            int componentType = JsonUtil.Int(accessor, "componentType", 5126);
            string type = Convert.ToString(JsonUtil.Get(accessor, "type"), CultureInfo.InvariantCulture) ?? "SCALAR";
            int components = TypeComponents(type);
            int componentSize = ComponentSize(componentType);
            int stride = JsonUtil.Int(view, "byteStride", components * componentSize);
            int start = JsonUtil.Int(view, "byteOffset", 0) + JsonUtil.Int(accessor, "byteOffset", 0);
            bool normalized = JsonUtil.Bool(accessor, "normalized", false);
            double[][] result = new double[count][];
            for (int i = 0; i < count; i++)
            {
                double[] row = new double[components];
                int baseOffset = start + i * stride;
                for (int c = 0; c < components; c++) row[c] = ReadComponent(doc.Binary, baseOffset + c * componentSize, componentType, normalized);
                result[i] = row;
            }
            return result;
        }

        private static Int32Collection ReadIndices(GlbDocument doc, int accessorIndex)
        {
            double[][] values = ReadAccessor(doc, accessorIndex);
            Int32Collection indices = new Int32Collection(values.Length);
            for (int i = 0; i < values.Length; i++) indices.Add((int)values[i][0]);
            return indices;
        }

        private static BitmapSource ReadImage(GlbDocument doc, int imageIndex)
        {
            if (imageIndex < 0 || imageIndex >= doc.Images.Count) return null;
            Dictionary<string, object> image = doc.Images[imageIndex];
            int viewIndex = JsonUtil.Int(image, "bufferView", -1);
            if (viewIndex < 0 || viewIndex >= doc.BufferViews.Count) return null;
            Dictionary<string, object> view = doc.BufferViews[viewIndex];
            int offset = JsonUtil.Int(view, "byteOffset", 0);
            int length = JsonUtil.Int(view, "byteLength", 0);
            if (offset < 0 || length <= 0 || offset + length > doc.Binary.Length) return null;
            byte[] bytes = new byte[length];
            Buffer.BlockCopy(doc.Binary, offset, bytes, 0, length);
            using (MemoryStream ms = new MemoryStream(bytes, false))
            {
                BitmapImage bitmap = new BitmapImage();
                bitmap.BeginInit();
                bitmap.CacheOption = BitmapCacheOption.OnLoad;
                bitmap.CreateOptions = BitmapCreateOptions.PreservePixelFormat;
                bitmap.StreamSource = ms;
                bitmap.EndInit();
                bitmap.Freeze();
                return bitmap;
            }
        }

        private static int TextureSource(GlbDocument doc, int textureIndex)
        {
            if (textureIndex < 0 || textureIndex >= doc.Textures.Count) return -1;
            return JsonUtil.Int(doc.Textures[textureIndex], "source", -1);
        }

        private static object[] ColorFactor(Dictionary<string, object> block, string key, object[] fallback)
        {
            object[] arr = JsonUtil.Arr(JsonUtil.Get(block, key));
            return arr.Length >= 3 ? arr : fallback;
        }

        private static Color FactorColor(object[] values)
        {
            double r = values.Length > 0 ? Convert.ToDouble(values[0], CultureInfo.InvariantCulture) : 1.0;
            double g = values.Length > 1 ? Convert.ToDouble(values[1], CultureInfo.InvariantCulture) : 1.0;
            double b = values.Length > 2 ? Convert.ToDouble(values[2], CultureInfo.InvariantCulture) : 1.0;
            double a = values.Length > 3 ? Convert.ToDouble(values[3], CultureInfo.InvariantCulture) : 1.0;
            return Color.FromArgb((byte)Math.Max(0, Math.Min(255, a * 255.0)), (byte)Math.Max(0, Math.Min(255, r * 255.0)), (byte)Math.Max(0, Math.Min(255, g * 255.0)), (byte)Math.Max(0, Math.Min(255, b * 255.0)));
        }

        private static int GetTextureInfo(Dictionary<string, object> material, out int texCoord)
        {
            texCoord = 0;
            Dictionary<string, object> pbr = JsonUtil.Obj(JsonUtil.Get(material, "pbrMetallicRoughness"));
            Dictionary<string, object> baseTex = JsonUtil.Obj(JsonUtil.Get(pbr, "baseColorTexture"));
            if (baseTex.Count > 0)
            {
                texCoord = JsonUtil.Int(baseTex, "texCoord", 0);
                return JsonUtil.Int(baseTex, "index", -1);
            }
            Dictionary<string, object> extensions = JsonUtil.Obj(JsonUtil.Get(material, "extensions"));
            Dictionary<string, object> spec = JsonUtil.Obj(JsonUtil.Get(extensions, "KHR_materials_pbrSpecularGlossiness"));
            Dictionary<string, object> diffTex = JsonUtil.Obj(JsonUtil.Get(spec, "diffuseTexture"));
            if (diffTex.Count > 0)
            {
                texCoord = JsonUtil.Int(diffTex, "texCoord", 0);
                return JsonUtil.Int(diffTex, "index", -1);
            }
            return -1;
        }

        private static Material BuildMaterial(GlbDocument doc, int materialIndex, out int texCoord)
        {
            texCoord = 0;
            if (materialIndex < 0 || materialIndex >= doc.Materials.Count)
            {
                DiffuseMaterial dm = new DiffuseMaterial(DefaultBrush);
                dm.Freeze();
                return dm;
            }
            Dictionary<string, object> material = doc.Materials[materialIndex];
            Dictionary<string, object> pbr = JsonUtil.Obj(JsonUtil.Get(material, "pbrMetallicRoughness"));
            Dictionary<string, object> extensions = JsonUtil.Obj(JsonUtil.Get(material, "extensions"));
            Dictionary<string, object> spec = JsonUtil.Obj(JsonUtil.Get(extensions, "KHR_materials_pbrSpecularGlossiness"));
            object[] factor = ColorFactor(pbr, "baseColorFactor", new object[] { 1.0, 1.0, 1.0, 1.0 });
            if (spec.Count > 0) factor = ColorFactor(spec, "diffuseFactor", factor);
            Color color = FactorColor(factor);
            int textureIndex = GetTextureInfo(material, out texCoord);
            Brush brush;
            BitmapSource bitmap = ReadImage(doc, TextureSource(doc, textureIndex));
            if (bitmap != null)
            {
                ImageBrush ib = new ImageBrush(bitmap);
                ib.Stretch = Stretch.Fill;
                ib.Opacity = color.A / 255.0;
                ib.Freeze();
                brush = ib;
            }
            else
            {
                SolidColorBrush sb = new SolidColorBrush(color);
                sb.Freeze();
                brush = sb;
            }
            MaterialGroup group = new MaterialGroup();
            group.Children.Add(new DiffuseMaterial(brush));
            Dictionary<string, object> unlit = JsonUtil.Obj(JsonUtil.Get(extensions, "KHR_materials_unlit"));
            if (unlit.Count == 0)
            {
                double metallic = JsonUtil.Double(pbr, "metallicFactor", 0.0);
                double roughness = JsonUtil.Double(pbr, "roughnessFactor", 0.7);
                double power = 5.0 + (1.0 - roughness) * 55.0 + metallic * 20.0;
                SolidColorBrush specBrush = new SolidColorBrush(Color.FromArgb(145, 245, 245, 250));
                specBrush.Freeze();
                group.Children.Add(new SpecularMaterial(specBrush, power));
            }
            object[] emissive = JsonUtil.Arr(JsonUtil.Get(material, "emissiveFactor"));
            if (emissive.Length >= 3)
            {
                Color ec = FactorColor(new object[] { emissive[0], emissive[1], emissive[2], 1.0 });
                if (ec.R > 2 || ec.G > 2 || ec.B > 2)
                {
                    SolidColorBrush eb = new SolidColorBrush(ec); eb.Freeze();
                    group.Children.Add(new EmissiveMaterial(eb));
                }
            }
            group.Freeze();
            return group;
        }

        private static GeometryModel3D BuildPrimitive(GlbDocument doc, Dictionary<string, object> primitive)
        {
            int mode = JsonUtil.Int(primitive, "mode", 4);
            if (mode != 4) return null;
            Dictionary<string, object> attrs = JsonUtil.Obj(JsonUtil.Get(primitive, "attributes"));
            int posAccessor = JsonUtil.Int(attrs, "POSITION", -1);
            if (posAccessor < 0) return null;
            int materialIndex = JsonUtil.Int(primitive, "material", -1);
            int texCoordSet;
            Material material = BuildMaterial(doc, materialIndex, out texCoordSet);
            int normalAccessor = JsonUtil.Int(attrs, "NORMAL", -1);
            int uvAccessor = JsonUtil.Int(attrs, "TEXCOORD_" + texCoordSet.ToString(CultureInfo.InvariantCulture), -1);
            if (uvAccessor < 0) uvAccessor = JsonUtil.Int(attrs, "TEXCOORD_0", -1);
            double[][] positions = ReadAccessor(doc, posAccessor);
            double[][] normals = normalAccessor >= 0 ? ReadAccessor(doc, normalAccessor) : new double[0][];
            double[][] uvs = uvAccessor >= 0 ? ReadAccessor(doc, uvAccessor) : new double[0][];
            MeshGeometry3D mesh = new MeshGeometry3D();
            Point3DCollection points = new Point3DCollection(positions.Length);
            for (int i = 0; i < positions.Length; i++) points.Add(new Point3D(positions[i][0], positions[i][1], positions[i][2]));
            mesh.Positions = points;
            if (normals.Length == positions.Length)
            {
                Vector3DCollection ns = new Vector3DCollection(normals.Length);
                for (int i = 0; i < normals.Length; i++) ns.Add(new Vector3D(normals[i][0], normals[i][1], normals[i][2]));
                mesh.Normals = ns;
            }
            if (uvs.Length == positions.Length)
            {
                PointCollection tc = new PointCollection(uvs.Length);
                for (int i = 0; i < uvs.Length; i++) tc.Add(new Point(uvs[i][0], 1.0 - uvs[i][1]));
                mesh.TextureCoordinates = tc;
            }
            int indexAccessor = JsonUtil.Int(primitive, "indices", -1);
            if (indexAccessor >= 0) mesh.TriangleIndices = ReadIndices(doc, indexAccessor);
            else
            {
                Int32Collection ix = new Int32Collection(positions.Length);
                for (int i = 0; i < positions.Length; i++) ix.Add(i);
                mesh.TriangleIndices = ix;
            }
            GeometryModel3D gm = new GeometryModel3D(mesh, material);
            if (materialIndex >= 0 && materialIndex < doc.Materials.Count && JsonUtil.Bool(doc.Materials[materialIndex], "doubleSided", false)) gm.BackMaterial = material;
            return gm;
        }

        private static Model3DGroup BuildMesh(GlbDocument doc, int meshIndex)
        {
            Model3DGroup group = new Model3DGroup();
            if (meshIndex < 0 || meshIndex >= doc.Meshes.Count) return group;
            object[] primitives = JsonUtil.Arr(JsonUtil.Get(doc.Meshes[meshIndex], "primitives"));
            for (int i = 0; i < primitives.Length; i++)
            {
                GeometryModel3D gm = BuildPrimitive(doc, JsonUtil.Obj(primitives[i]));
                if (gm != null) group.Children.Add(gm);
            }
            return group;
        }

        private static Transform3D NodeTransform(Dictionary<string, object> node)
        {
            object[] matrix = JsonUtil.Arr(JsonUtil.Get(node, "matrix"));
            if (matrix.Length == 16)
            {
                double[] m = new double[16];
                for (int i = 0; i < 16; i++) m[i] = Convert.ToDouble(matrix[i], CultureInfo.InvariantCulture);
                Matrix3D mm = new Matrix3D(m[0],m[1],m[2],m[3],m[4],m[5],m[6],m[7],m[8],m[9],m[10],m[11],m[12],m[13],m[14],m[15]);
                return new MatrixTransform3D(mm);
            }
            Transform3DGroup t = new Transform3DGroup();
            object[] scale = JsonUtil.Arr(JsonUtil.Get(node, "scale"));
            if (scale.Length >= 3) t.Children.Add(new ScaleTransform3D(Convert.ToDouble(scale[0],CultureInfo.InvariantCulture),Convert.ToDouble(scale[1],CultureInfo.InvariantCulture),Convert.ToDouble(scale[2],CultureInfo.InvariantCulture)));
            object[] rotation = JsonUtil.Arr(JsonUtil.Get(node, "rotation"));
            if (rotation.Length >= 4)
            {
                Quaternion q = new Quaternion(Convert.ToDouble(rotation[0],CultureInfo.InvariantCulture),Convert.ToDouble(rotation[1],CultureInfo.InvariantCulture),Convert.ToDouble(rotation[2],CultureInfo.InvariantCulture),Convert.ToDouble(rotation[3],CultureInfo.InvariantCulture));
                t.Children.Add(new RotateTransform3D(new QuaternionRotation3D(q)));
            }
            object[] translation = JsonUtil.Arr(JsonUtil.Get(node, "translation"));
            if (translation.Length >= 3) t.Children.Add(new TranslateTransform3D(Convert.ToDouble(translation[0],CultureInfo.InvariantCulture),Convert.ToDouble(translation[1],CultureInfo.InvariantCulture),Convert.ToDouble(translation[2],CultureInfo.InvariantCulture)));
            return t.Children.Count == 0 ? Transform3D.Identity : t;
        }

        private static Model3DGroup BuildNode(GlbDocument doc, int nodeIndex, HashSet<int> stack)
        {
            Model3DGroup group = new Model3DGroup();
            if (nodeIndex < 0 || nodeIndex >= doc.Nodes.Count || stack.Contains(nodeIndex)) return group;
            stack.Add(nodeIndex);
            Dictionary<string, object> node = doc.Nodes[nodeIndex];
            group.Transform = NodeTransform(node);
            int meshIndex = JsonUtil.Int(node, "mesh", -1);
            if (meshIndex >= 0) group.Children.Add(BuildMesh(doc, meshIndex));
            object[] children = JsonUtil.Arr(JsonUtil.Get(node, "children"));
            for (int i = 0; i < children.Length; i++) group.Children.Add(BuildNode(doc, Convert.ToInt32(children[i], CultureInfo.InvariantCulture), stack));
            stack.Remove(nodeIndex);
            return group;
        }

        public static Model3DGroup BuildScene(GlbDocument doc)
        {
            Model3DGroup root = new Model3DGroup();
            int sceneIndex = JsonUtil.Int(doc.Root, "scene", 0);
            if (doc.Scenes.Count > 0 && sceneIndex >= 0 && sceneIndex < doc.Scenes.Count)
            {
                object[] nodes = JsonUtil.Arr(JsonUtil.Get(doc.Scenes[sceneIndex], "nodes"));
                for (int i = 0; i < nodes.Length; i++) root.Children.Add(BuildNode(doc, Convert.ToInt32(nodes[i], CultureInfo.InvariantCulture), new HashSet<int>()));
            }
            else
            {
                HashSet<int> childNodes = new HashSet<int>();
                for (int i = 0; i < doc.Nodes.Count; i++)
                {
                    object[] children = JsonUtil.Arr(JsonUtil.Get(doc.Nodes[i], "children"));
                    for (int j = 0; j < children.Length; j++) childNodes.Add(Convert.ToInt32(children[j], CultureInfo.InvariantCulture));
                }
                for (int i = 0; i < doc.Nodes.Count; i++) if (!childNodes.Contains(i)) root.Children.Add(BuildNode(doc, i, new HashSet<int>()));
            }
            return root;
        }
    }

    public static class ModelPreviewRenderer
    {
        private static Transform3D BuildDisplayTransform(Rect3D bounds, double yaw, double pitch)
        {
            double max = Math.Max(bounds.SizeX, Math.Max(bounds.SizeY, bounds.SizeZ));
            if (max <= 0.00001) max = 1.0;
            double scale = 2.15 / max;
            Point3D center = new Point3D(bounds.X + bounds.SizeX / 2.0, bounds.Y + bounds.SizeY / 2.0, bounds.Z + bounds.SizeZ / 2.0);
            Transform3DGroup group = new Transform3DGroup();
            group.Children.Add(new TranslateTransform3D(-center.X, -center.Y, -center.Z));
            group.Children.Add(new ScaleTransform3D(scale, scale, scale));
            group.Children.Add(new RotateTransform3D(new AxisAngleRotation3D(new Vector3D(1, 0, 0), pitch)));
            group.Children.Add(new RotateTransform3D(new AxisAngleRotation3D(new Vector3D(0, 1, 0), yaw)));
            return group;
        }

        public static void Render(string modelPath, string outputPath, int pixelSize, double yaw, double pitch)
        {
            GlbDocument doc = GlbLoader.Read(modelPath);
            Model3DGroup model = GlbLoader.BuildScene(doc);
            Rect3D bounds = model.Bounds;
            ModelVisual3D modelVisual = new ModelVisual3D();
            modelVisual.Content = model;
            modelVisual.Transform = BuildDisplayTransform(bounds, yaw, pitch);

            Model3DGroup lights = new Model3DGroup();
            lights.Children.Add(new AmbientLight(Color.FromRgb(110, 116, 128)));
            lights.Children.Add(new DirectionalLight(Color.FromRgb(255, 252, 242), new Vector3D(-0.6, -0.8, -1.7)));
            lights.Children.Add(new DirectionalLight(Color.FromRgb(135, 165, 210), new Vector3D(1.0, 0.35, -0.8)));
            ModelVisual3D lightVisual = new ModelVisual3D();
            lightVisual.Content = lights;

            Viewport3D viewport = new Viewport3D();
            viewport.Width = pixelSize;
            viewport.Height = pixelSize;
            PerspectiveCamera camera = new PerspectiveCamera();
            camera.Position = new Point3D(0, 0.10, 4.2);
            camera.LookDirection = new Vector3D(0, -0.05, -4.2);
            camera.UpDirection = new Vector3D(0, 1, 0);
            camera.FieldOfView = 34.0;
            viewport.Camera = camera;
            viewport.Children.Add(lightVisual);
            viewport.Children.Add(modelVisual);

            Grid root = new Grid();
            root.Background = Brushes.Transparent;
            root.Width = pixelSize;
            root.Height = pixelSize;
            root.Children.Add(viewport);
            root.Measure(new Size(pixelSize, pixelSize));
            root.Arrange(new Rect(0, 0, pixelSize, pixelSize));
            root.UpdateLayout();

            RenderTargetBitmap bitmap = new RenderTargetBitmap(pixelSize, pixelSize, 96, 96, PixelFormats.Pbgra32);
            bitmap.Render(root);
            PngBitmapEncoder encoder = new PngBitmapEncoder();
            encoder.Frames.Add(BitmapFrame.Create(bitmap));
            string dir = Path.GetDirectoryName(outputPath);
            if (!String.IsNullOrEmpty(dir)) Directory.CreateDirectory(dir);
            string temp = outputPath + ".tmp";
            using (FileStream fs = File.Create(temp)) encoder.Save(fs);
            if (File.Exists(outputPath)) File.Delete(outputPath);
            File.Move(temp, outputPath);
        }
    }

    public static class Program
    {
        private static string Arg(string[] args, string key, string fallback)
        {
            for (int i = 0; i + 1 < args.Length; i++) if (String.Equals(args[i], key, StringComparison.OrdinalIgnoreCase)) return args[i + 1];
            return fallback;
        }

        [STAThread]
        public static int Main(string[] args)
        {
            try
            {
                string model = Arg(args, "--model", "");
                string output = Arg(args, "--output", "");
                int size = Int32.Parse(Arg(args, "--size", "256"), CultureInfo.InvariantCulture);
                double yaw = Double.Parse(Arg(args, "--yaw", "24"), CultureInfo.InvariantCulture);
                double pitch = Double.Parse(Arg(args, "--pitch", "-12"), CultureInfo.InvariantCulture);
                if (String.IsNullOrWhiteSpace(model) || !File.Exists(model)) throw new FileNotFoundException("Model file was not found.", model);
                if (String.IsNullOrWhiteSpace(output)) throw new ArgumentException("Output path is required.");
                size = Math.Max(96, Math.Min(768, size));
                ModelPreviewRenderer.Render(model, output, size, yaw, pitch);
                return 0;
            }
            catch (Exception ex)
            {
                try { Console.Error.WriteLine(ex.ToString()); } catch { }
                return 1;
            }
        }
    }
}
