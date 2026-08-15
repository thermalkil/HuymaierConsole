using System;
using System.Collections.Generic;
using System.Globalization;
using System.IO;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Media;
using System.Windows.Media.Media3D;

namespace HuymaierConsole.Modeling
{
    /// <summary>
    /// Geometry-only GLB scene builder used for small live platform cards.
    /// It deliberately skips embedded texture decoding while preserving the
    /// original mesh geometry, normals, indices, node hierarchy/transforms and
    /// material base colors. The full viewer continues to use GlbLoader.
    /// </summary>
    internal static class CardSceneBuilder
    {
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
            if (accessorIndex < 0 || accessorIndex >= doc.Accessors.Count) return new double[0][];
            Dictionary<string, object> accessor = doc.Accessors[accessorIndex];
            int viewIndex = JsonUtil.Int(accessor, "bufferView", -1);
            if (viewIndex < 0 || viewIndex >= doc.BufferViews.Count) return new double[0][];
            Dictionary<string, object> view = doc.BufferViews[viewIndex];
            int count = JsonUtil.Int(accessor, "count", 0);
            int componentType = JsonUtil.Int(accessor, "componentType", 5126);
            string type = Convert.ToString(JsonUtil.Get(accessor, "type"), CultureInfo.InvariantCulture) ?? "SCALAR";
            int components = TypeComponents(type);
            int componentSize = ComponentSize(componentType);
            int stride = JsonUtil.Int(view, "byteStride", components * componentSize);
            int start = JsonUtil.Int(view, "byteOffset", 0) + JsonUtil.Int(accessor, "byteOffset", 0);
            bool normalized = JsonUtil.Bool(accessor, "normalized", false);
            if (count <= 0 || start < 0 || start >= doc.Binary.Length) return new double[0][];
            double[][] result = new double[count][];
            for (int i = 0; i < count; i++)
            {
                double[] row = new double[components];
                int baseOffset = start + i * stride;
                if (baseOffset < 0 || baseOffset + components * componentSize > doc.Binary.Length) throw new InvalidDataException("GLB accessor exceeds BIN data.");
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

        private static object[] ColorFactor(Dictionary<string, object> block, string key, object[] fallback)
        {
            object[] arr = JsonUtil.Arr(JsonUtil.Get(block, key));
            return arr.Length >= 3 ? arr : fallback;
        }

        private static bool MaterialHasTexture(Dictionary<string, object> material)
        {
            Dictionary<string, object> pbr = JsonUtil.Obj(JsonUtil.Get(material, "pbrMetallicRoughness"));
            if (JsonUtil.Obj(JsonUtil.Get(pbr, "baseColorTexture")).Count > 0) return true;
            Dictionary<string, object> extensions = JsonUtil.Obj(JsonUtil.Get(material, "extensions"));
            Dictionary<string, object> spec = JsonUtil.Obj(JsonUtil.Get(extensions, "KHR_materials_pbrSpecularGlossiness"));
            return JsonUtil.Obj(JsonUtil.Get(spec, "diffuseTexture")).Count > 0;
        }

        private static Material BuildCardMaterial(GlbDocument doc, int materialIndex)
        {
            Color color = Color.FromRgb(172, 181, 194);
            double metallic = 0.0;
            double roughness = 0.66;
            if (materialIndex >= 0 && materialIndex < doc.Materials.Count)
            {
                Dictionary<string, object> material = doc.Materials[materialIndex];
                Dictionary<string, object> pbr = JsonUtil.Obj(JsonUtil.Get(material, "pbrMetallicRoughness"));
                Dictionary<string, object> extensions = JsonUtil.Obj(JsonUtil.Get(material, "extensions"));
                Dictionary<string, object> spec = JsonUtil.Obj(JsonUtil.Get(extensions, "KHR_materials_pbrSpecularGlossiness"));
                object[] factor = ColorFactor(pbr, "baseColorFactor", new object[] { 1.0, 1.0, 1.0, 1.0 });
                if (spec.Count > 0) factor = ColorFactor(spec, "diffuseFactor", factor);
                double r = factor.Length > 0 ? Convert.ToDouble(factor[0], CultureInfo.InvariantCulture) : 1.0;
                double g = factor.Length > 1 ? Convert.ToDouble(factor[1], CultureInfo.InvariantCulture) : 1.0;
                double b = factor.Length > 2 ? Convert.ToDouble(factor[2], CultureInfo.InvariantCulture) : 1.0;
                bool textured = MaterialHasTexture(material);
                // Texture-only materials are commonly pure white. A neutral
                // console-metal shade gives their actual geometry enough form
                // on a 100px card without decoding multi-megabyte images.
                if (textured && r > 0.93 && g > 0.93 && b > 0.93)
                {
                    r = 0.67; g = 0.72; b = 0.80;
                }
                color = Color.FromRgb(
                    (byte)Math.Max(18, Math.Min(245, r * 255.0)),
                    (byte)Math.Max(18, Math.Min(245, g * 255.0)),
                    (byte)Math.Max(18, Math.Min(245, b * 255.0)));
                metallic = JsonUtil.Double(pbr, "metallicFactor", 0.0);
                roughness = JsonUtil.Double(pbr, "roughnessFactor", 0.66);
            }
            SolidColorBrush diffuseBrush = new SolidColorBrush(color);
            diffuseBrush.Freeze();
            MaterialGroup group = new MaterialGroup();
            group.Children.Add(new DiffuseMaterial(diffuseBrush));
            double power = 7.0 + (1.0 - Math.Max(0.0, Math.Min(1.0, roughness))) * 52.0 + Math.Max(0.0, Math.Min(1.0, metallic)) * 18.0;
            SolidColorBrush specBrush = new SolidColorBrush(Color.FromArgb(155, 245, 247, 250));
            specBrush.Freeze();
            group.Children.Add(new SpecularMaterial(specBrush, power));
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
            double[][] positions = ReadAccessor(doc, posAccessor);
            if (positions.Length == 0) return null;
            int normalAccessor = JsonUtil.Int(attrs, "NORMAL", -1);
            double[][] normals = normalAccessor >= 0 ? ReadAccessor(doc, normalAccessor) : new double[0][];

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
            int indexAccessor = JsonUtil.Int(primitive, "indices", -1);
            if (indexAccessor >= 0) mesh.TriangleIndices = ReadIndices(doc, indexAccessor);
            else
            {
                Int32Collection ix = new Int32Collection(positions.Length);
                for (int i = 0; i < positions.Length; i++) ix.Add(i);
                mesh.TriangleIndices = ix;
            }
            try { mesh.Freeze(); } catch { }
            Material material = BuildCardMaterial(doc, JsonUtil.Int(primitive, "material", -1));
            GeometryModel3D gm = new GeometryModel3D(mesh, material);
            // Always expose both sides in card mode. User-supplied glTF assets
            // come from several coordinate/winding conventions, and culling a
            // 100px model is more harmful than the tiny extra fill cost.
            gm.BackMaterial = material;
            try { gm.Freeze(); } catch { }
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
            try { root.Freeze(); } catch { }
            return root;
        }
    }

    /// <summary>
    /// A real WPF Viewport3D surface backed by glTF 2.0 geometry. The normal
    /// constructor keeps full textures/materials for the dedicated model viewer.
    /// The card-mode constructor uses CardSceneBuilder to avoid decoding the
    /// user's large embedded textures while remaining true live 3D geometry.
    /// </summary>
    public sealed class LiveModelView : System.Windows.Controls.Grid
    {
        private readonly System.Windows.Controls.Viewport3D viewport;
        private readonly PerspectiveCamera camera;
        private readonly ModelVisual3D modelVisual;
        private readonly ScaleTransform3D scaleTransform;
        private readonly AxisAngleRotation3D pitchRotation;
        private readonly AxisAngleRotation3D yawRotation;
        private readonly double normalizedScale;
        private double zoomDistance;

        public string ModelPath { get; private set; }
        public bool CardMode { get; private set; }
        public int GeometryCount { get; private set; }
        public int VertexCount { get; private set; }
        public double Yaw { get { return yawRotation.Angle; } }
        public double Pitch { get { return pitchRotation.Angle; } }
        public double ZoomDistance { get { return zoomDistance; } }

        public LiveModelView(string modelPath) : this(modelPath, false) { }

        public LiveModelView(string modelPath, bool cardMode)
        {
            if (String.IsNullOrWhiteSpace(modelPath) || !File.Exists(modelPath))
                throw new FileNotFoundException("Live platform model was not found.", modelPath);

            ModelPath = Path.GetFullPath(modelPath);
            CardMode = cardMode;
            ClipToBounds = true;
            Background = Brushes.Transparent;
            IsHitTestVisible = false;

            GlbDocument doc = GlbLoader.Read(ModelPath);
            Model3DGroup model = cardMode ? CardSceneBuilder.BuildScene(doc) : GlbLoader.BuildScene(doc);
            GeometryCount = CountGeometry(model);
            VertexCount = CountVertices(model);
            if (GeometryCount <= 0 || VertexCount <= 0) throw new InvalidDataException("GLB scene contains no renderable triangle geometry.");

            Rect3D bounds = model.Bounds;
            if (bounds.IsEmpty || !Finite(bounds.X) || !Finite(bounds.Y) || !Finite(bounds.Z) || !Finite(bounds.SizeX) || !Finite(bounds.SizeY) || !Finite(bounds.SizeZ))
                throw new InvalidDataException("GLB scene bounds are empty or non-finite.");
            double maxDimension = Math.Max(bounds.SizeX, Math.Max(bounds.SizeY, bounds.SizeZ));
            if (!Finite(maxDimension) || maxDimension <= 0.00001) throw new InvalidDataException("GLB scene bounds have no usable size.");
            normalizedScale = 2.15 / maxDimension;

            Point3D center = new Point3D(
                bounds.X + bounds.SizeX / 2.0,
                bounds.Y + bounds.SizeY / 2.0,
                bounds.Z + bounds.SizeZ / 2.0);

            scaleTransform = new ScaleTransform3D(normalizedScale, normalizedScale, normalizedScale);
            pitchRotation = new AxisAngleRotation3D(new Vector3D(1, 0, 0), -12.0);
            yawRotation = new AxisAngleRotation3D(new Vector3D(0, 1, 0), 24.0);

            Transform3DGroup modelTransform = new Transform3DGroup();
            modelTransform.Children.Add(new TranslateTransform3D(-center.X, -center.Y, -center.Z));
            modelTransform.Children.Add(scaleTransform);
            modelTransform.Children.Add(new RotateTransform3D(pitchRotation));
            modelTransform.Children.Add(new RotateTransform3D(yawRotation));

            modelVisual = new ModelVisual3D();
            modelVisual.Content = model;
            modelVisual.Transform = modelTransform;

            Model3DGroup lights = new Model3DGroup();
            lights.Children.Add(new AmbientLight(Color.FromRgb(128, 133, 145)));
            lights.Children.Add(new DirectionalLight(Color.FromRgb(255, 252, 242), new Vector3D(-0.6, -0.8, -1.7)));
            lights.Children.Add(new DirectionalLight(Color.FromRgb(145, 177, 220), new Vector3D(1.0, 0.35, -0.8)));
            lights.Children.Add(new DirectionalLight(Color.FromRgb(218, 184, 104), new Vector3D(0.25, 0.8, 0.65)));
            ModelVisual3D lightVisual = new ModelVisual3D();
            lightVisual.Content = lights;

            camera = new PerspectiveCamera();
            camera.UpDirection = new Vector3D(0, 1, 0);
            camera.FieldOfView = 34.0;
            camera.NearPlaneDistance = 0.01;
            camera.FarPlaneDistance = 100.0;
            zoomDistance = 4.2;
            UpdateCamera();

            viewport = new System.Windows.Controls.Viewport3D();
            viewport.HorizontalAlignment = HorizontalAlignment.Stretch;
            viewport.VerticalAlignment = VerticalAlignment.Stretch;
            viewport.ClipToBounds = true;
            viewport.IsHitTestVisible = false;
            viewport.Camera = camera;
            viewport.Children.Add(lightVisual);
            viewport.Children.Add(modelVisual);
            Children.Add(viewport);
        }

        private static bool Finite(double value)
        {
            return !Double.IsNaN(value) && !Double.IsInfinity(value);
        }

        private static int CountGeometry(Model3D model)
        {
            GeometryModel3D gm = model as GeometryModel3D;
            if (gm != null) return 1;
            Model3DGroup group = model as Model3DGroup;
            if (group == null) return 0;
            int total = 0;
            foreach (Model3D child in group.Children) total += CountGeometry(child);
            return total;
        }

        private static int CountVertices(Model3D model)
        {
            GeometryModel3D gm = model as GeometryModel3D;
            if (gm != null)
            {
                MeshGeometry3D mesh = gm.Geometry as MeshGeometry3D;
                return mesh == null || mesh.Positions == null ? 0 : mesh.Positions.Count;
            }
            Model3DGroup group = model as Model3DGroup;
            if (group == null) return 0;
            int total = 0;
            foreach (Model3D child in group.Children) total += CountVertices(child);
            return total;
        }

        private void UpdateCamera()
        {
            camera.Position = new Point3D(0, 0.10, zoomDistance);
            camera.LookDirection = new Vector3D(0, -0.05, -zoomDistance);
        }

        public void SetScalePercent(double percent)
        {
            double factor = Math.Max(0.40, Math.Min(2.20, percent / 100.0));
            double value = normalizedScale * factor;
            scaleTransform.ScaleX = value;
            scaleTransform.ScaleY = value;
            scaleTransform.ScaleZ = value;
        }

        public void Rotate(double yawDelta, double pitchDelta)
        {
            double yaw = yawRotation.Angle + yawDelta;
            while (yaw >= 360.0) yaw -= 360.0;
            while (yaw < 0.0) yaw += 360.0;
            yawRotation.Angle = yaw;
            pitchRotation.Angle = Math.Max(-80.0, Math.Min(80.0, pitchRotation.Angle + pitchDelta));
        }

        public void Zoom(double delta)
        {
            zoomDistance = Math.Max(2.0, Math.Min(8.0, zoomDistance - delta));
            UpdateCamera();
        }

        public void ResetView()
        {
            yawRotation.Angle = 24.0;
            pitchRotation.Angle = -12.0;
            zoomDistance = 4.2;
            UpdateCamera();
        }
    }
}
