using System;
using System.Collections.Generic;
using System.Globalization;
using System.IO;
using System.Text;

namespace HuymaierConsole.Modeling
{
    // HUYMAIER_BUILTIN_LIVE_GLB_GENERATOR_V1
    // Deterministically creates the built-in provider/console model set as real
    // glTF 2.0 binary geometry. These files are used by the WPF Viewport3D
    // runtime; the PNG atlas remains fallback-only.
    internal static class BuiltInModelGenerator
    {
        private sealed class Part
        {
            public readonly List<float> Position = new List<float>();
            public readonly List<float> Normal = new List<float>();
            public readonly List<ushort> Index = new List<ushort>();
            public float R, G, B, A;
        }

        private sealed class Model
        {
            public readonly List<Part> Parts = new List<Part>();
        }

        private static readonly string[] Frames = new string[] {
            "amazon","arcade","atari-2600","atari-lynx","battlenet","ea","epic-games","finalburn-neo","game-gear","gog",
            "jaguar","neo-geo-pocket-color","neo-geo","nintendo-3ds","nintendo-64","nintendo-ds","nintendo-dsi","nintendo-entertainment-system","nintendo-game-boy-advance","nintendo-game-boy-color",
            "nintendo-game-boy","nintendo-gamecube","nintendo-switch","nintendo-wii-u","nintendo-wii","playstation-2","playstation-3","playstation-4","playstation-5","primehack",
            "rockstar","sega-32x","sega-cd","sega-dreamcast","sega-genesis","sega-logo","sega-master-system","sega-mega-drive","sega-saturn","sony-playstation-portable",
            "sony-playstation-vita","sony-playstation","steam","super-nintendo-entertainment-system","turbografx-16","ubisoft","xbox-360","xbox-one","xbox-pc","xbox"
        };

        private static float F(double v) { return (float)v; }
        private static float[] C(double r, double g, double b) { return new float[] { F(r), F(g), F(b), 1f }; }
        private static readonly float[] Black = C(.035,.04,.05);
        private static readonly float[] Dark = C(.075,.085,.105);
        private static readonly float[] Gray = C(.32,.34,.37);
        private static readonly float[] LightGray = C(.72,.73,.72);
        private static readonly float[] White = C(.93,.94,.93);
        private static readonly float[] Blue = C(.08,.30,.68);
        private static readonly float[] Cyan = C(.08,.62,.92);
        private static readonly float[] Green = C(.06,.58,.24);
        private static readonly float[] Purple = C(.43,.14,.70);
        private static readonly float[] Red = C(.76,.07,.09);
        private static readonly float[] Orange = C(.92,.31,.07);
        private static readonly float[] Yellow = C(.95,.68,.05);
        private static readonly float[] Gold = C(.82,.62,.18);
        private static readonly float[] Wood = C(.40,.20,.085);
        private static readonly float[] Screen = C(.035,.095,.15);

        public static int Main(string[] args)
        {
            try
            {
                string output = null;
                for (int i = 0; i < args.Length; i++)
                    if (args[i] == "--output" && i + 1 < args.Length) output = args[++i];
                if (String.IsNullOrWhiteSpace(output)) throw new ArgumentException("--output <directory> is required.");
                Directory.CreateDirectory(output);
                foreach (string frame in Frames)
                {
                    Model model = Build(frame);
                    string path = Path.Combine(output, frame + ".glb");
                    WriteGlb(path, frame, model);
                }
                Console.WriteLine("generatedLivePlatformModels: " + Frames.Length.ToString(CultureInfo.InvariantCulture));
                return 0;
            }
            catch (Exception ex)
            {
                Console.Error.WriteLine(ex.ToString());
                return 2;
            }
        }

        private static Part NewPart(Model m, float[] color)
        {
            Part p = new Part(); p.R=color[0];p.G=color[1];p.B=color[2];p.A=color[3];m.Parts.Add(p);return p;
        }

        private static void Rotate(ref double x, ref double y, ref double z, double rx, double ry, double rz)
        {
            double c=Math.Cos(rx),s=Math.Sin(rx),ny=y*c-z*s,nz=y*s+z*c;y=ny;z=nz;
            c=Math.Cos(ry);s=Math.Sin(ry);double nx=x*c+z*s;nz=-x*s+z*c;x=nx;z=nz;
            c=Math.Cos(rz);s=Math.Sin(rz);nx=x*c-y*s;ny=x*s+y*c;x=nx;y=ny;
        }

        private static void AddVertex(Part p,double x,double y,double z,double nx,double ny,double nz,double cx,double cy,double cz,double rx,double ry,double rz)
        {
            Rotate(ref x,ref y,ref z,rx,ry,rz);Rotate(ref nx,ref ny,ref nz,rx,ry,rz);
            p.Position.Add(F(x+cx));p.Position.Add(F(y+cy));p.Position.Add(F(z+cz));
            p.Normal.Add(F(nx));p.Normal.Add(F(ny));p.Normal.Add(F(nz));
        }

        private static void AddQuad(Part p,double[] a,double[] b,double[] c,double[] d,double nx,double ny,double nz,double cx,double cy,double cz,double rx,double ry,double rz)
        {
            int start=p.Position.Count/3;
            AddVertex(p,a[0],a[1],a[2],nx,ny,nz,cx,cy,cz,rx,ry,rz);
            AddVertex(p,b[0],b[1],b[2],nx,ny,nz,cx,cy,cz,rx,ry,rz);
            AddVertex(p,c[0],c[1],c[2],nx,ny,nz,cx,cy,cz,rx,ry,rz);
            AddVertex(p,d[0],d[1],d[2],nx,ny,nz,cx,cy,cz,rx,ry,rz);
            p.Index.Add((ushort)start);p.Index.Add((ushort)(start+1));p.Index.Add((ushort)(start+2));
            p.Index.Add((ushort)start);p.Index.Add((ushort)(start+2));p.Index.Add((ushort)(start+3));
        }

        private static void Box(Model m,double cx,double cy,double cz,double sx,double sy,double sz,float[] color,double rx=0,double ry=0,double rz=0)
        {
            Part p=NewPart(m,color);double x=sx/2,y=sy/2,z=sz/2;
            AddQuad(p,new[]{-x,-y,z},new[]{x,-y,z},new[]{x,y,z},new[]{-x,y,z},0,0,1,cx,cy,cz,rx,ry,rz);
            AddQuad(p,new[]{x,-y,-z},new[]{-x,-y,-z},new[]{-x,y,-z},new[]{x,y,-z},0,0,-1,cx,cy,cz,rx,ry,rz);
            AddQuad(p,new[]{x,-y,z},new[]{x,-y,-z},new[]{x,y,-z},new[]{x,y,z},1,0,0,cx,cy,cz,rx,ry,rz);
            AddQuad(p,new[]{-x,-y,-z},new[]{-x,-y,z},new[]{-x,y,z},new[]{-x,y,-z},-1,0,0,cx,cy,cz,rx,ry,rz);
            AddQuad(p,new[]{-x,y,z},new[]{x,y,z},new[]{x,y,-z},new[]{-x,y,-z},0,1,0,cx,cy,cz,rx,ry,rz);
            AddQuad(p,new[]{-x,-y,-z},new[]{x,-y,-z},new[]{x,-y,z},new[]{-x,-y,z},0,-1,0,cx,cy,cz,rx,ry,rz);
        }

        private static void Cylinder(Model m,double cx,double cy,double cz,double radius,double height,float[] color,int segments=20,double rx=0,double ry=0,double rz=0)
        {
            Part p=NewPart(m,color);double h=height/2;int sideStart=p.Position.Count/3;
            for(int i=0;i<segments;i++)
            {
                double a=Math.PI*2*i/segments, x=Math.Cos(a)*radius,z=Math.Sin(a)*radius;
                AddVertex(p,x,-h,z,Math.Cos(a),0,Math.Sin(a),cx,cy,cz,rx,ry,rz);
                AddVertex(p,x,h,z,Math.Cos(a),0,Math.Sin(a),cx,cy,cz,rx,ry,rz);
            }
            for(int i=0;i<segments;i++)
            {
                int n=(i+1)%segments,a=sideStart+i*2,b=sideStart+n*2;
                p.Index.Add((ushort)a);p.Index.Add((ushort)b);p.Index.Add((ushort)(b+1));
                p.Index.Add((ushort)a);p.Index.Add((ushort)(b+1));p.Index.Add((ushort)(a+1));
            }
            int topCenter=p.Position.Count/3;AddVertex(p,0,h,0,0,1,0,cx,cy,cz,rx,ry,rz);
            int topRing=p.Position.Count/3;
            for(int i=0;i<segments;i++){double a=Math.PI*2*i/segments;AddVertex(p,Math.Cos(a)*radius,h,Math.Sin(a)*radius,0,1,0,cx,cy,cz,rx,ry,rz);}
            for(int i=0;i<segments;i++){int n=(i+1)%segments;p.Index.Add((ushort)topCenter);p.Index.Add((ushort)(topRing+n));p.Index.Add((ushort)(topRing+i));}
            int bottomCenter=p.Position.Count/3;AddVertex(p,0,-h,0,0,-1,0,cx,cy,cz,rx,ry,rz);
            int bottomRing=p.Position.Count/3;
            for(int i=0;i<segments;i++){double a=Math.PI*2*i/segments;AddVertex(p,Math.Cos(a)*radius,-h,Math.Sin(a)*radius,0,-1,0,cx,cy,cz,rx,ry,rz);}
            for(int i=0;i<segments;i++){int n=(i+1)%segments;p.Index.Add((ushort)bottomCenter);p.Index.Add((ushort)(bottomRing+i));p.Index.Add((ushort)(bottomRing+n));}
        }

        private static void Sphere(Model m,double cx,double cy,double cz,double r,float[] color,int slices=16,int stacks=10)
        {
            Part p=NewPart(m,color);int start=p.Position.Count/3;
            for(int j=0;j<=stacks;j++)
            {
                double v=(double)j/stacks,phi=Math.PI*v;
                for(int i=0;i<=slices;i++)
                {
                    double u=(double)i/slices,theta=Math.PI*2*u;
                    double nx=Math.Sin(phi)*Math.Cos(theta),ny=Math.Cos(phi),nz=Math.Sin(phi)*Math.Sin(theta);
                    AddVertex(p,nx*r,ny*r,nz*r,nx,ny,nz,cx,cy,cz,0,0,0);
                }
            }
            for(int j=0;j<stacks;j++)for(int i=0;i<slices;i++)
            {
                int a=start+j*(slices+1)+i,b=a+slices+1;
                p.Index.Add((ushort)a);p.Index.Add((ushort)b);p.Index.Add((ushort)(a+1));
                p.Index.Add((ushort)(a+1));p.Index.Add((ushort)b);p.Index.Add((ushort)(b+1));
            }
        }

        private static void Button(Model m,double x,double y,double z,float[] color,double radius=.07)
        { Cylinder(m,x,y,z,radius,.035,color,16,Math.PI/2,0,0); }

        private static void ScreenHandheld(Model m,double w,double h,double d,float[] body,float[] accent,bool dual=false)
        {
            Box(m,0,0,0,w,h,d,body);
            Box(m,0,.06,d/2+.012,w*.55,h*.48,.025,Screen);
            Button(m,w*.34,-h*.16,d/2+.035,accent,.055);Button(m,w*.25,-h*.08,d/2+.035,accent,.045);
            Button(m,-w*.32,-h*.12,d/2+.035,Dark,.055);
            if(dual){Box(m,0,.20,d/2+.025,w*.60,.018,.03,Gray);}
        }

        private static void Provider(Model m,string name)
        {
            float[] accent=Blue;
            if(name=="epic-games")accent=White;else if(name=="gog")accent=Purple;else if(name=="ea")accent=Orange;else if(name=="ubisoft")accent=Cyan;else if(name=="xbox-pc")accent=Green;else if(name=="battlenet")accent=Blue;else if(name=="rockstar")accent=Yellow;else if(name=="amazon")accent=Cyan;else if(name=="steam")accent=LightGray;else if(name=="primehack")accent=Orange;else if(name=="finalburn-neo")accent=Red;
            Box(m,0,0,0,1.65,1.02,.24,Dark,0,.05,0);
            Box(m,0,.02,.135,1.42,.80,.035,accent);
            Cylinder(m,-.46,-.17,.175,.13,.04,Black,20,Math.PI/2,0,0);
            Cylinder(m,.46,-.17,.175,.13,.04,Black,20,Math.PI/2,0,0);
            Sphere(m,-.50,-.16,.21,.045,White);Sphere(m,.50,-.16,.21,.045,White);
            Box(m,0,.31,.18,.56,.07,.05,Black);
        }

        private static Model Build(string f)
        {
            Model m=new Model();
            switch(f)
            {
                case "steam": case "epic-games": case "gog": case "ea": case "ubisoft": case "xbox-pc": case "battlenet": case "rockstar": case "amazon": case "primehack": case "finalburn-neo": Provider(m,f); break;
                case "sony-playstation":
                    Box(m,0,0,0,1.70,.34,1.25,LightGray);Cylinder(m,0,.19,-.02,.43,.045,Gray);Button(m,-.61,.20,.34,Dark,.08);Button(m,.61,.20,.34,Dark,.08);break;
                case "playstation-2":
                    for(int i=0;i<5;i++)Box(m,0,-.16+i*.075,0,1.82,.065,1.18,i%2==0?Black:Dark);
                    Box(m,-.68,.10,.61,.31,.07,.025,Blue);break;
                case "playstation-3":
                    Box(m,0,0,0,1.82,.38,1.08,Black,0,0,.035);Box(m,0,.22,-.05,1.55,.08,.92,Dark,0,0,.035);Box(m,.68,.20,.47,.30,.025,.04,Silver());break;
                case "playstation-4":
                    Box(m,0,-.07,0,1.85,.20,1.08,Black,0,.03,.035);Box(m,0,.12,-.02,1.85,.18,1.08,Dark,0,.03,-.025);Box(m,-.62,.22,.53,.42,.025,.035,Blue);break;
                case "playstation-5":
                    Box(m,0,0,0,.72,1.60,.58,Black);Box(m,-.44,0,0,.22,1.78,.70,White,0,0,-.07);Box(m,.44,0,0,.22,1.78,.70,White,0,0,.07);Box(m,0,.60,.32,.28,.04,.04,Blue);break;
                case "xbox":
                    Box(m,0,0,0,1.85,.42,1.25,Black);Box(m,0,.23,0,1.58,.055,.98,Dark,.0,.0,.12);Cylinder(m,0,.27,0,.34,.055,Green);break;
                case "xbox-360":
                    Box(m,0,0,0,.76,1.68,.62,White,0,0,.025);Box(m,0,.05,.325,.46,1.42,.03,LightGray);Cylinder(m,0,.55,.35,.07,.035,Green,16,Math.PI/2,0,0);break;
                case "xbox-one":
                    Box(m,0,0,0,1.95,.50,1.02,Black);Box(m,-.48,.27,.12,.90,.035,.72,Dark);Box(m,.71,.27,.45,.08,.025,.03,White);break;
                case "nintendo-entertainment-system":
                    Box(m,0,0,0,1.72,.52,1.05,LightGray);Box(m,0,-.02,.54,1.72,.32,.06,Gray);Box(m,.55,.14,.58,.35,.07,.03,Red);break;
                case "super-nintendo-entertainment-system":
                    Box(m,0,0,0,1.70,.40,1.12,LightGray);Box(m,0,.22,-.03,1.10,.08,.66,Gray);Button(m,.52,.24,.25,Purple,.08);Button(m,.70,.24,.16,Purple,.065);break;
                case "nintendo-64":
                    Box(m,0,0,0,1.58,.50,.96,Dark);Box(m,-.55,.18,.15,.46,.34,.72,Dark,0,0,.12);Box(m,.55,.18,.15,.46,.34,.72,Dark,0,0,-.12);Cylinder(m,0,.30,.08,.22,.06,Gray);break;
                case "nintendo-gamecube":
                    Box(m,0,0,0,1.18,1.05,1.15,Purple);Cylinder(m,0,.56,0,.39,.055,Dark);Box(m,0,.93,-.33,.72,.10,.12,Black);Box(m,-.30,.98,-.33,.12,.40,.12,Black);Box(m,.30,.98,-.33,.12,.40,.12,Black);break;
                case "nintendo-wii":
                    Box(m,0,0,0,.48,1.72,.78,White,0,0,-.035);Box(m,.17,.20,.41,.05,.78,.025,Cyan);break;
                case "nintendo-wii-u":
                    ScreenHandheld(m,1.85,.92,.22,White,Cyan,true);break;
                case "nintendo-switch":
                    Box(m,0,0,0,1.25,.73,.18,Dark);Box(m,0,.02,.105,1.03,.58,.025,Screen);Box(m,-.73,0,0,.28,.82,.24,Cyan);Box(m,.73,0,0,.28,.82,.24,Red);Button(m,-.73,.18,.135,Dark,.07);Button(m,.73,-.18,.135,Dark,.07);break;
                case "nintendo-game-boy": ScreenHandheld(m,.96,1.62,.24,LightGray,Purple);break;
                case "nintendo-game-boy-color": ScreenHandheld(m,.92,1.57,.22,Purple,Red);break;
                case "nintendo-game-boy-advance": ScreenHandheld(m,1.55,.86,.20,Purple,White);break;
                case "nintendo-ds": case "nintendo-dsi":
                    Box(m,0,.34,0,1.35,.64,.16,f=="nintendo-dsi"?Black:LightGray,-.22,0,0);Box(m,0,-.34,0,1.35,.64,.16,f=="nintendo-dsi"?Black:LightGray,.22,0,0);Box(m,0,.37,.09,.93,.41,.02,Screen,-.22,0,0);Box(m,0,-.37,.09,.93,.41,.02,Screen,.22,0,0);break;
                case "nintendo-3ds":
                    Box(m,0,.35,0,1.42,.66,.17,Red,-.20,0,0);Box(m,0,-.35,0,1.42,.66,.17,Red,.20,0,0);Box(m,0,.39,.10,.98,.43,.02,Screen,-.20,0,0);Box(m,0,-.39,.10,.90,.38,.02,Screen,.20,0,0);break;
                case "sony-playstation-portable": ScreenHandheld(m,1.70,.72,.18,Black,White);break;
                case "sony-playstation-vita": ScreenHandheld(m,1.72,.78,.17,Black,Blue);break;
                case "sega-dreamcast":
                    Box(m,0,0,0,1.52,.43,1.20,White);Cylinder(m,0,.24,-.05,.40,.055,LightGray);Cylinder(m,0,.29,-.05,.08,.025,Orange);break;
                case "sega-genesis": case "sega-mega-drive":
                    Box(m,0,0,0,1.72,.35,1.16,Black);Cylinder(m,0,.21,-.05,.44,.06,Dark);Box(m,.48,.24,.40,.44,.045,.06,Red);break;
                case "sega-master-system":
                    Box(m,0,0,0,1.78,.30,1.04,Black);Box(m,-.35,.17,.10,.74,.035,.68,Dark);Box(m,.62,.17,.30,.22,.025,.04,Red);break;
                case "sega-saturn":
                    Box(m,0,0,0,1.55,.38,1.20,Black);Cylinder(m,0,.22,-.04,.40,.05,Dark);Button(m,.56,.23,.40,Gray,.07);break;
                case "game-gear": ScreenHandheld(m,1.58,.88,.25,Black,Blue);break;
                case "sega-32x":
                    Box(m,0,0,0,1.22,.70,.92,Black);Box(m,0,.42,.05,.78,.30,.60,Dark);break;
                case "sega-cd":
                    Box(m,0,0,0,1.80,.28,1.20,Black);Cylinder(m,.22,.17,-.04,.39,.045,Dark);Box(m,-.58,.17,.38,.35,.03,.05,Red);break;
                case "sega-logo": Provider(m,"battlenet");break;
                case "atari-2600":
                    Box(m,0,0,0,1.78,.40,1.02,Black);Box(m,0,.10,.53,1.78,.18,.05,Wood);for(int i=0;i<4;i++)Box(m,-.48+i*.32,.28,.12,.06,.14,.08,Silver());break;
                case "atari-lynx": ScreenHandheld(m,1.72,.76,.23,Dark,Orange);break;
                case "jaguar":
                    Box(m,0,0,0,1.75,.38,1.06,Black);Box(m,0,.24,-.03,1.18,.10,.66,Dark);Button(m,.55,.24,.36,Red,.08);break;
                case "arcade":
                    Box(m,0,-.10,0,1.05,1.85,.72,Dark,0,0,-.04);Box(m,0,.42,.38,.80,.55,.04,Screen);Box(m,0,-.04,.43,.86,.22,.14,Black,.18,0,0);Cylinder(m,-.22,.05,.55,.06,.22,Red,16,0,0,.10);Button(m,.18,-.08,.56,Yellow,.07);Button(m,.38,-.08,.56,Green,.07);break;
                case "neo-geo":
                    Box(m,0,0,0,1.78,.38,1.14,Black);Box(m,0,.23,-.12,1.32,.08,.70,Dark);Button(m,.55,.25,.34,Red,.08);break;
                case "neo-geo-pocket-color": ScreenHandheld(m,.92,1.45,.22,Dark,Cyan);break;
                case "turbografx-16":
                    Box(m,0,0,0,1.70,.26,.95,White);Box(m,-.35,.15,.10,.78,.04,.58,Dark);Box(m,.55,.15,.31,.30,.025,.04,Orange);break;
                default: Provider(m,f);break;
            }
            return m;
        }

        private static float[] Silver() { return C(.62,.64,.67); }

        private static void Align4(Stream s) { while ((s.Position & 3) != 0) s.WriteByte(0); }
        private static void WriteUInt32(BinaryWriter w,uint v){w.Write(v);}

        private static void WriteGlb(string path,string name,Model model)
        {
            MemoryStream bin=new MemoryStream();BinaryWriter bw=new BinaryWriter(bin);
            List<string> views=new List<string>();List<string> accessors=new List<string>();List<string> primitives=new List<string>();List<string> materials=new List<string>();
            int viewIndex=0, accessorIndex=0, materialIndex=0;
            foreach(Part p in model.Parts)
            {
                Align4(bin);long posOff=bin.Position;foreach(float v in p.Position)bw.Write(v);long posLen=bin.Position-posOff;
                int posView=viewIndex++;views.Add("{\"buffer\":0,\"byteOffset\":"+posOff.ToString(CultureInfo.InvariantCulture)+",\"byteLength\":"+posLen.ToString(CultureInfo.InvariantCulture)+",\"target\":34962}");
                int count=p.Position.Count/3;float minX=Single.MaxValue,minY=Single.MaxValue,minZ=Single.MaxValue,maxX=Single.MinValue,maxY=Single.MinValue,maxZ=Single.MinValue;
                for(int i=0;i<p.Position.Count;i+=3){float x=p.Position[i],y=p.Position[i+1],z=p.Position[i+2];minX=Math.Min(minX,x);minY=Math.Min(minY,y);minZ=Math.Min(minZ,z);maxX=Math.Max(maxX,x);maxY=Math.Max(maxY,y);maxZ=Math.Max(maxZ,z);}
                int posAcc=accessorIndex++;accessors.Add("{\"bufferView\":"+posView+",\"componentType\":5126,\"count\":"+count+",\"type\":\"VEC3\",\"min\":["+N(minX)+","+N(minY)+","+N(minZ)+"],\"max\":["+N(maxX)+","+N(maxY)+","+N(maxZ)+"]}");
                Align4(bin);long normOff=bin.Position;foreach(float v in p.Normal)bw.Write(v);long normLen=bin.Position-normOff;
                int normView=viewIndex++;views.Add("{\"buffer\":0,\"byteOffset\":"+normOff+",\"byteLength\":"+normLen+",\"target\":34962}");
                int normAcc=accessorIndex++;accessors.Add("{\"bufferView\":"+normView+",\"componentType\":5126,\"count\":"+count+",\"type\":\"VEC3\"}");
                Align4(bin);long idxOff=bin.Position;foreach(ushort v in p.Index)bw.Write(v);long idxLen=bin.Position-idxOff;
                int idxView=viewIndex++;views.Add("{\"buffer\":0,\"byteOffset\":"+idxOff+",\"byteLength\":"+idxLen+",\"target\":34963}");
                int idxAcc=accessorIndex++;accessors.Add("{\"bufferView\":"+idxView+",\"componentType\":5123,\"count\":"+p.Index.Count+",\"type\":\"SCALAR\"}");
                int mat=materialIndex++;materials.Add("{\"pbrMetallicRoughness\":{\"baseColorFactor\":["+N(p.R)+","+N(p.G)+","+N(p.B)+","+N(p.A)+"],\"metallicFactor\":0.18,\"roughnessFactor\":0.48}}");
                primitives.Add("{\"attributes\":{\"POSITION\":"+posAcc+",\"NORMAL\":"+normAcc+"},\"indices\":"+idxAcc+",\"material\":"+mat+",\"mode\":4}");
            }
            bw.Flush();byte[] binBytes=bin.ToArray();bw.Dispose();bin.Dispose();
            string json="{\"asset\":{\"version\":\"2.0\",\"generator\":\"Huymaier Console BuiltInModelGenerator v1\"},\"scene\":0,\"scenes\":[{\"nodes\":[0]}],\"nodes\":[{\"mesh\":0,\"name\":\""+name+"\"}],\"meshes\":[{\"name\":\""+name+"\",\"primitives\":["+String.Join(",",primitives.ToArray())+"]}],\"materials\":["+String.Join(",",materials.ToArray())+"],\"buffers\":[{\"byteLength\":"+binBytes.Length+"}],\"bufferViews\":["+String.Join(",",views.ToArray())+"],\"accessors\":["+String.Join(",",accessors.ToArray())+"]}";
            byte[] jsonBytes=Encoding.UTF8.GetBytes(json);int jsonPad=(4-(jsonBytes.Length%4))%4;int binPad=(4-(binBytes.Length%4))%4;uint total=(uint)(12+8+jsonBytes.Length+jsonPad+8+binBytes.Length+binPad);
            using(FileStream fs=File.Create(path))using(BinaryWriter o=new BinaryWriter(fs))
            {
                o.Write(new byte[]{0x67,0x6c,0x54,0x46});WriteUInt32(o,2);WriteUInt32(o,total);
                WriteUInt32(o,(uint)(jsonBytes.Length+jsonPad));WriteUInt32(o,0x4E4F534A);o.Write(jsonBytes);for(int i=0;i<jsonPad;i++)o.Write((byte)0x20);
                WriteUInt32(o,(uint)(binBytes.Length+binPad));WriteUInt32(o,0x004E4942);o.Write(binBytes);for(int i=0;i<binPad;i++)o.Write((byte)0);
            }
        }
        private static string N(float f){return f.ToString("0.######",CultureInfo.InvariantCulture);}
    }
}
