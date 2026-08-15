using System;
using System.IO;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Media;
using System.Windows.Media.Media3D;

namespace HuymaierConsole.Modeling
{
    /// <summary>
    /// A real WPF Viewport3D surface backed by the same glTF 2.0 loader used by
    /// HuymaierModelPreviewWorker. This is intentionally not a bitmap preview:
    /// the Model3D graph remains live so cards and the full-screen viewer can
    /// rotate and zoom the original GLB geometry at runtime.
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
        public double Yaw { get { return yawRotation.Angle; } }
        public double Pitch { get { return pitchRotation.Angle; } }
        public double ZoomDistance { get { return zoomDistance; } }

        public LiveModelView(string modelPath)
        {
            if (String.IsNullOrWhiteSpace(modelPath) || !File.Exists(modelPath))
                throw new FileNotFoundException("Live platform model was not found.", modelPath);

            ModelPath = Path.GetFullPath(modelPath);
            ClipToBounds = true;
            Background = Brushes.Transparent;
            IsHitTestVisible = false;

            GlbDocument doc = GlbLoader.Read(ModelPath);
            Model3DGroup model = GlbLoader.BuildScene(doc);
            Rect3D bounds = model.Bounds;
            double maxDimension = Math.Max(bounds.SizeX, Math.Max(bounds.SizeY, bounds.SizeZ));
            if (maxDimension <= 0.00001) maxDimension = 1.0;
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
            lights.Children.Add(new AmbientLight(Color.FromRgb(112, 118, 130)));
            lights.Children.Add(new DirectionalLight(Color.FromRgb(255, 252, 242), new Vector3D(-0.6, -0.8, -1.7)));
            lights.Children.Add(new DirectionalLight(Color.FromRgb(135, 165, 210), new Vector3D(1.0, 0.35, -0.8)));
            lights.Children.Add(new DirectionalLight(Color.FromRgb(205, 170, 92), new Vector3D(0.25, 0.8, 0.65)));
            ModelVisual3D lightVisual = new ModelVisual3D();
            lightVisual.Content = lights;

            camera = new PerspectiveCamera();
            camera.UpDirection = new Vector3D(0, 1, 0);
            camera.FieldOfView = 34.0;
            zoomDistance = 4.2;
            UpdateCamera();

            viewport = new System.Windows.Controls.Viewport3D();
            viewport.HorizontalAlignment = HorizontalAlignment.Stretch;
            viewport.VerticalAlignment = VerticalAlignment.Stretch;
            viewport.Camera = camera;
            viewport.Children.Add(lightVisual);
            viewport.Children.Add(modelVisual);
            Children.Add(viewport);
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
