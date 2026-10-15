// Conversor do MU Season 6 pro Godot (estudo interno).
// Uso: conversor <pasta Data> <mundo> <saida>   (personagens: veja Personagens.cs)
// Gera em <saida>/mundo<N>/:
//   altura.png  (L8, 256x256: altura do MU / 1,5)
//   mapa.png    (RGBA: R camada 1, G camada 2, B mistura, A atributo)
//   luz.png     (RGB, luz pintada do terreno)
//   tiles/<i>.png + tiles.json (textura de chao de cada indice e quantos tiles ela cobre)
//   modelos/<nome>.glb (cada BMD na pose 0, coordenadas do MU: Z pra cima, 100 por tile)
//   objetos.json (modelo, posicao, quaternion, escala de cada objeto do mapa)
using System.Numerics;
using System.Text.Json;
using Client.Data;
using Client.Data.ATT;
using Client.Data.BMD;
using Client.Data.MAP;
using Client.Data.OBJS;
using Client.Data.OZB;
using Client.Data.Texture;
using SharpGLTF.Geometry;
using SharpGLTF.Geometry.VertexTypes;
using SharpGLTF.Materials;
using SixLabors.ImageSharp;
using SixLabors.ImageSharp.PixelFormats;
using SixLabors.ImageSharp.Processing;
using static Texturas;

if (args[0] == "acoes") { await Personagens.Acoes(args[1]); return; }
if (args[0] == "personagens") { await Personagens.Rodar(args[1], args[2]); return; }
if (args[0] == "itens") { await Itens.Rodar(args[1], args[2], args[3]); return; }
if (args[0] == "modelos") { await Modelos.Rodar(args[1], args[2], args[3]); return; }
if (args[0] == "extras") { await Extras.Rodar(args[1], int.Parse(args[2]), args[3]); return; }
if (args[0] == "efeitos") { await Efeitos.Rodar(args[1], args[2]); return; }
// conversor textura <arquivo .OZJ/.OZT> <destino.png>: uma textura avulsa (as capas, de Player e Item)
if (args[0] == "textura") { await Extras.Png(args[1], args[2]); return; }
var data = args[0];
var mundo = int.Parse(args[1]);
var saida = Path.Combine(args[2], $"mundo{mundo}");
Directory.CreateDirectory(Path.Combine(saida, "tiles"));
Directory.CreateDirectory(Path.Combine(saida, "modelos"));
var pasta = Achar(data, $"World{mundo}") ?? throw new Exception($"sem World{mundo}");
const int N = 256;

// ---------- terreno ----------
var map = await new MapReader().Load(Achar(pasta, $"EncTerrain{mundo}.map")!);
var att = await new ATTReader().Load(Achar(pasta, $"EncTerrain{mundo}.att")!);
var altura = await new OZBReader().Load(Achar(pasta, "TerrainHeight.OZB")!);
// luz: S6 usa TerrainLight.OZJ, versoes novas usam .OZB
var luzOzb = Achar(pasta, "TerrainLight.OZB");
var luz = luzOzb != null ? await new OZBReader().Load(luzOzb) : Ozb(await new OZJReader().Load(Achar(pasta, "TerrainLight.OZJ")!));
Console.WriteLine($"mapa v{map.Version} · altura {altura.Width}x{altura.Height} · luz {luz.Width}x{luz.Height}");

using (var img = new Image<L8>(N, N))
using (var m = new Image<Rgba32>(N, N))
using (var l = new Image<Rgb24>(N, N))
{
    for (int y = 0; y < N; y++)
    for (int x = 0; x < N; x++)
    {
        int i = y * N + x;
        img[x, y] = new L8(altura.Data[i].R);
        m[x, y] = new Rgba32(map.Layer1[i], map.Layer2[i], map.Alpha[i], (byte)((ushort)att.TerrainWall[i] & 0xFF));
        l[x, y] = new Rgb24(luz.Data[i].R, luz.Data[i].G, luz.Data[i].B);
    }
    img.SaveAsPng(Path.Combine(saida, "altura.png"));
    m.SaveAsPng(Path.Combine(saida, "mapa.png"));
    l.SaveAsPng(Path.Combine(saida, "luz.png"));
}

var nomesTile = new Dictionary<int, string>
{
    [0] = "TileGrass01", [1] = "TileGrass02", [2] = "TileGround01", [3] = "TileGround02", [4] = "TileGround03",
    [5] = "TileWater01", [6] = "TileWood01", [7] = "TileRock01", [8] = "TileRock02", [9] = "TileRock03",
    [10] = "TileRock04", [11] = "TileRock05", [12] = "TileRock06", [13] = "TileRock07",
};
for (int i = 1; i <= 16; i++) nomesTile[13 + i] = $"ExtTile{i:00}";
var tiles = new List<object>();
foreach (var (idx, nome) in nomesTile)
{
    var f = Achar(pasta, nome + ".OZJ");
    if (f == null) continue;
    var t = await new OZJReader().Load(f);
    using var im = Imagem(t);
    // um tile do MU cobre 64 px da textura; o Godot usa um array de 256x256, entao guarda a repeticao
    tiles.Add(new { i = idx, nome, repete = t.Width / 64f });
    im.Mutate(c => c.Resize(256, 256));
    im.SaveAsPng(Path.Combine(saida, "tiles", $"{idx}.png"));
}
File.WriteAllText(Path.Combine(saida, "tiles.json"), JsonSerializer.Serialize(tiles));
Console.WriteLine($"tiles: {tiles.Count}");

// ---------- objetos ----------
var obj = await new OBJReader().Load(Achar(pasta, $"EncTerrain{mundo}.obj")!);
var pastaObj = Achar(data, $"Object{mundo}") ?? throw new Exception($"sem Object{mundo}");
var arquivos = Directory.GetFiles(pastaObj).Where(p => p.EndsWith(".bmd", StringComparison.OrdinalIgnoreCase))
    .ToDictionary(p => Path.GetFileNameWithoutExtension(p).ToLowerInvariant());
// Lorencia usa nomes (Tree01.bmd): tabela tirada do MapManager.cpp do cliente S6 (sven-n/MuMain).
// Os outros mundos usam Object<tipo+1>.bmd
var nomesLorencia = JsonSerializer.Deserialize<Dictionary<string, string>>(
    File.ReadAllText(Path.Combine(AppContext.BaseDirectory, "lorencia.json")))!;
string? ArquivoDoTipo(short tipo)
{
    if (mundo == 1)
        return nomesLorencia.TryGetValue(tipo.ToString(), out var n) && arquivos.ContainsKey(n.ToLowerInvariant()) ? n.ToLowerInvariant() : null;
    var o = $"object{tipo + 1:00}";
    return arquivos.ContainsKey(o) ? o : null;
}

var lista = new List<object>();
var feitos = new Dictionary<string, bool>();
var faltam = new SortedDictionary<int, int>();
foreach (var o in obj.Objects)
{
    // Devias tem objeto com posicao/escala infinita no .obj: o cliente nao mostra, aqui pula
    if (!float.IsFinite(o.Position.X) || !float.IsFinite(o.Position.Y) || !float.IsFinite(o.Position.Z) || !float.IsFinite(o.Scale)
        || !float.IsFinite(o.Angle.X) || !float.IsFinite(o.Angle.Y) || !float.IsFinite(o.Angle.Z)) { faltam[-1] = faltam.GetValueOrDefault(-1) + 1; continue; }
    var nome = ArquivoDoTipo(o.Type);
    if (nome == null) { faltam[o.Type] = faltam.GetValueOrDefault(o.Type) + 1; continue; }
    if (!feitos.ContainsKey(nome))
    {
        try { await Glb(arquivos[nome], Path.Combine(saida, "modelos", nome + ".glb")); feitos[nome] = true; }
        catch (Exception e) { Console.WriteLine($"  {nome}: {e.Message}"); feitos[nome] = false; }
    }
    if (!feitos[nome]) continue;
    var a = o.Angle * (MathF.PI / 180f);
    var q = MathUtils.AngleQuaternion(a);
    lista.Add(new { m = nome, t = o.Type, p = new[] { o.Position.X, o.Position.Y, o.Position.Z }, q = new[] { q.X, q.Y, q.Z, q.W }, s = o.Scale });
}
File.WriteAllText(Path.Combine(saida, "objetos.json"), JsonSerializer.Serialize(lista));
// ossos na pose 0 de cada modelo (o cliente prende luz e faisca no osso: CreateSprite em BoneTransform[n])
File.WriteAllText(Path.Combine(saida, "ossos.json"), JsonSerializer.Serialize(OssosPose.Todos));
Console.WriteLine($"objetos: {lista.Count} de {obj.Objects.Length} · modelos: {feitos.Count(f => f.Value)} ok, {feitos.Count(f => !f.Value)} com erro");
if (faltam.Count > 0) Console.WriteLine("tipos sem arquivo: " + string.Join(" ", faltam.Select(f => $"{f.Key}x{f.Value}")));

// ---------- funcoes ----------
static string? Achar(string dir, string nome) =>
    Directory.EnumerateFileSystemEntries(dir).FirstOrDefault(p => Path.GetFileName(p).Equals(nome, StringComparison.OrdinalIgnoreCase));

// a luz em jpg vira o mesmo formato da OZB (de baixo pra cima, como o MU guarda)
static OZB Ozb(TextureData t)
{
    var o = new OZB { Width = t.Width, Height = t.Height, Data = new System.Drawing.Color[t.Width * t.Height] };
    for (int i = 0; i < o.Data.Length; i++)
        o.Data[i] = System.Drawing.Color.FromArgb(t.Data[i * t.Components], t.Data[i * t.Components + 1], t.Data[i * t.Components + 2]);
    return o;
}

static async Task Glb(string arquivo, string destino)
{
    var bmd = await new BMDReader().Load(arquivo);
    var dir = Path.GetDirectoryName(arquivo)!;
    // pose do quadro 0 da acao 0: cada vertice e relativo ao osso dele
    var ossos = new Matrix4x4[bmd.Bones.Length];
    for (int i = 0; i < bmd.Bones.Length; i++)
    {
        var b = bmd.Bones[i];
        ossos[i] = Matrix4x4.Identity;
        if (b == BMDTextureBone.Dummy || b.Matrixes.Length == 0) continue;
        var bm = b.Matrixes[0];
        if (bm.Position.Length == 0 || bm.Quaternion.Length == 0) continue;
        var local = Matrix4x4.CreateFromQuaternion(bm.Quaternion[0]);
        local.Translation = bm.Position[0];
        ossos[i] = b.Parent >= 0 && b.Parent < i ? local * ossos[b.Parent] : local;
    }
    OssosPose.Todos[Path.GetFileNameWithoutExtension(destino)] = ossos.Select(m => new[] { m.Translation.X, m.Translation.Y, m.Translation.Z }).ToArray();

    var mb = new MeshBuilder<VertexPositionNormal, VertexTexture1>(bmd.Name);
    foreach (var me in bmd.Meshes)
    {
        var mat = new MaterialBuilder(me.TexturePath).WithDoubleSide(true).WithMetallicRoughness(0, 1);
        var tex = await Textura(dir, me.TexturePath);
        if (tex != null)
        {
            mat.WithChannelImage(KnownChannel.BaseColor, new SharpGLTF.Memory.MemoryImage(tex.Value.png));
            if (tex.Value.alfa) mat.WithAlpha(SharpGLTF.Materials.AlphaMode.MASK, 0.5f);
        }
        var prim = mb.UsePrimitive(mat);
        (VertexPositionNormal, VertexTexture1) V(BMDTriangle tri, int k)
        {
            var v = me.Vertices[tri.VertexIndex[k]];
            var nrm = me.Normals[tri.NormalIndex[k]];
            var m = v.Node >= 0 && v.Node < ossos.Length ? ossos[v.Node] : Matrix4x4.Identity;
            var p = Vector3.Transform(v.Position, m);
            var n = Vector3.Normalize(Vector3.TransformNormal(nrm.Normal, m));
            if (float.IsNaN(n.X)) n = Vector3.UnitZ;
            var uv = me.TexCoords[tri.TexCoordIndex[k]];
            return (new VertexPositionNormal(p, n), new VertexTexture1(new Vector2(uv.U, uv.V)));
        }
        foreach (var tri in me.Triangles)
        {
            prim.AddTriangle(V(tri, 0), V(tri, 1), V(tri, 2));
            if (tri.Polygon == 4) prim.AddTriangle(V(tri, 0), V(tri, 2), V(tri, 3));
        }
    }
    var cena = new SharpGLTF.Scenes.SceneBuilder();
    cena.AddRigidMesh(mb, Matrix4x4.Identity);
    cena.ToGltf2().SaveGLB(destino);
}

static class OssosPose
{
    public static readonly Dictionary<string, float[][]> Todos = new();
}
