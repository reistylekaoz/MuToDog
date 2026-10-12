// Inspetor de mapa do MU (estudo interno): le um World<N> do cliente e gera
// terreno.png (texturas + luz + objetos) e atributos.png (zona segura, parede, agua).
using Client.Data.ATT;
using Client.Data.MAP;
using Client.Data.OBJS;
using Client.Data.OZB;
using Client.Data.Texture;
using SixLabors.ImageSharp;
using SixLabors.ImageSharp.PixelFormats;

var data = args[0];           // .../Data
var mundo = int.Parse(args[1]); // 1 = Lorencia
var saida = args[2];
Directory.CreateDirectory(saida);
var pasta = Path.Combine(data, $"World{mundo}");
const int N = 256, PX = 8;

var map = await new MapReader().Load(Path.Combine(pasta, $"EncTerrain{mundo}.map"));
var att = await new ATTReader().Load(Path.Combine(pasta, $"EncTerrain{mundo}.att"));
OBJ? obj = null;
try { obj = await new OBJReader().Load(Path.Combine(pasta, $"EncTerrain{mundo}.obj")); }
catch (Exception e) { Console.WriteLine($"objetos: nao li ({e.InnerException?.Message ?? e.Message})"); }
var luz = await new OZBReader().Load(Path.Combine(pasta, "TerrainLight.OZB"));
Console.WriteLine($"map v{map.Version} n{map.MapNumber} · att {att.Width}x{att.Height} · obj {(obj == null ? "-" : obj.Objects.Length + " objetos")} · luz {luz.Width}x{luz.Height}");

string[] nomes = ["TileGrass01","TileGrass02","TileGround01","TileGround02","TileGround03","TileWater01","TileWood01",
                  "TileRock01","TileRock02","TileRock03","TileRock04","TileRock05","TileRock06","TileRock07"];
var tex = new Dictionary<int, TextureData>();
for (int i = 0; i < nomes.Length; i++)
{
    var f = Directory.GetFiles(pasta).FirstOrDefault(p => Path.GetFileName(p).Equals(nomes[i] + ".OZJ", StringComparison.OrdinalIgnoreCase));
    if (f != null) tex[i] = await new OZJReader().Load(f);
}
Console.WriteLine($"texturas: {tex.Count} ({string.Join(", ", tex.Keys.Select(k => nomes[k]))})");

Rgb24 Amostra(int idx, int gx, int gy)
{
    if (!tex.TryGetValue(idx, out var t)) return new Rgb24(255, 0, 255);
    int x = (gx * 8) % t.Width, y = (gy * 8) % t.Height, o = (y * t.Width + x) * t.Components;
    return new Rgb24(t.Data[o], t.Data[o + 1], t.Data[o + 2]);
}

using var img = new Image<Rgb24>(N * PX, N * PX);
using var mapa = new Image<Rgb24>(N * PX, N * PX);
var usados = new SortedDictionary<int, int>();
for (int ty = 0; ty < N; ty++)
for (int tx = 0; tx < N; tx++)
{
    int i = ty * N + tx;
    usados[map.Layer1[i]] = usados.GetValueOrDefault(map.Layer1[i]) + 1;
    float a = map.Alpha[i] / 255f;
    var l = luz.Data[i];
    var w = att.TerrainWall[i];
    for (int py = 0; py < PX; py++)
    for (int px = 0; px < PX; px++)
    {
        int gx = tx * PX + px, gy = ty * PX + py;
        var c1 = Amostra(map.Layer1[i], gx, gy);
        var c2 = a > 0 ? Amostra(map.Layer2[i], gx, gy) : c1;
        float r = (c1.R * (1 - a) + c2.R * a) * l.R / 255f, g = (c1.G * (1 - a) + c2.G * a) * l.G / 255f, b = (c1.B * (1 - a) + c2.B * a) * l.B / 255f;
        // y do MU cresce pra cima: inverte pra imagem
        img[gx, N * PX - 1 - gy] = new Rgb24((byte)Math.Min(255, r * 1.6f), (byte)Math.Min(255, g * 1.6f), (byte)Math.Min(255, b * 1.6f));
        Rgb24 cor = new(40, 44, 52);
        if (w.HasFlag(TWFlags.NoMove)) cor = new(15, 15, 18);
        else if (w.HasFlag(TWFlags.Water)) cor = new(40, 90, 160);
        else if (w.HasFlag(TWFlags.SafeZone)) cor = new(60, 150, 90);
        else cor = new(110, 100, 80);
        mapa[gx, N * PX - 1 - gy] = cor;
    }
}
// objetos: posicao em unidades de mundo (100 por tile)
foreach (var o in obj?.Objects ?? [])
{
    int cx = (int)(o.Position.X / 100f * PX), cy = N * PX - 1 - (int)(o.Position.Y / 100f * PX);
    for (int dy = -2; dy <= 2; dy++) for (int dx = -2; dx <= 2; dx++)
        if (cx + dx >= 0 && cy + dy >= 0 && cx + dx < N * PX && cy + dy < N * PX) img[cx + dx, cy + dy] = new Rgb24(255, 210, 60);
}
Console.WriteLine("tiles por textura (camada 1): " + string.Join(" ", usados.Select(k => $"{k.Key}:{k.Value}")));
int seg = att.TerrainWall.Count(x => x.HasFlag(TWFlags.SafeZone)), parede = att.TerrainWall.Count(x => x.HasFlag(TWFlags.NoMove));
Console.WriteLine($"zona segura {seg} tiles · bloqueado {parede} tiles · andavel {N * N - parede}");
await img.SaveAsPngAsync(Path.Combine(saida, $"mundo{mundo}-terreno.png"));
await mapa.SaveAsPngAsync(Path.Combine(saida, $"mundo{mundo}-atributos.png"));
