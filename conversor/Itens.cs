// Itens do inventario: cada modelo de item vira um GLB ja girado como o cliente
// mostra no inventario (rotacao do "inventory" dos JSON do MuMain, Data/Items/Models).
// Uso: conversor itens <pasta Data> <pasta Models do MuMain> <saida>
// Grava <saida>/<arquivo>.glb e <saida>/modelos.json ("grupo,numero" -> glb).
// Pecas de armadura (Data/Player) sao presas no esqueleto do jogador: aqui vao na
// pose 0 do player.bmd, como o cliente desenha no inventario.
using System.Numerics;
using System.Text.Json;
using Client.Data;
using Client.Data.BMD;
using SharpGLTF.Geometry;
using SharpGLTF.Geometry.VertexTypes;
using SharpGLTF.Materials;

static class Itens
{
    public static async Task Rodar(string data, string modelos, string saida)
    {
        Directory.CreateDirectory(saida);
        var raiz = Path.GetDirectoryName(Path.GetFullPath(data).TrimEnd('/'))!;
        // modelos compartilhados: nome -> arquivo
        var comp = new Dictionary<string, string>();
        using (var j = JsonDocument.Parse(File.ReadAllText(Path.Combine(modelos, "SharedModels.json"))))
            foreach (var m in j.RootElement.GetProperty("models").EnumerateArray())
                comp[m.GetProperty("name").GetString()!] = m.GetProperty("file").GetString()!;
        var jogador = Pose0(await new BMDReader().Load(Arquivo(raiz, "Data/Player/player.bmd")!));
        var mapa = new SortedDictionary<string, string>(StringComparer.Ordinal);
        var feitos = new Dictionary<string, string>();
        int erros = 0;
        foreach (var g in Directory.GetFiles(modelos, "Group*.json").Order())
        {
            using var j = JsonDocument.Parse(File.ReadAllText(g));
            int grupo = j.RootElement.GetProperty("group").GetInt32();
            foreach (var m in j.RootElement.GetProperty("models").EnumerateArray())
            {
                int numero = m.GetProperty("number").GetInt32();
                string? rel = m.TryGetProperty("file", out var f) ? f.GetString()
                    : m.TryGetProperty("model", out var mo) && comp.TryGetValue(mo.GetString()!, out var c) ? c : null;
                if (rel == null) continue;
                var rot = new Vector3(270, -10, 0);
                if (m.TryGetProperty("inventory", out var inv) && inv.TryGetProperty("rotation", out var r))
                    rot = new Vector3(r[0].GetSingle(), r[1].GetSingle(), r[2].GetSingle());
                var chave = $"{rel.ToLowerInvariant()}|{rot}";
                if (!feitos.TryGetValue(chave, out var nome))
                {
                    nome = Path.GetFileNameWithoutExtension(rel).ToLowerInvariant();
                    while (feitos.ContainsValue(nome)) nome += "_";
                    var arq = Arquivo(raiz, rel);
                    if (arq == null) { Console.WriteLine($"  {grupo},{numero}: falta {rel}"); erros++; continue; }
                    try
                    {
                        // so elmo, armadura, calca, luva e bota vao presos no esqueleto do jogador
                        var corpo = grupo is >= 7 and <= 11 && rel.Contains("/Player/", StringComparison.OrdinalIgnoreCase) ? jogador : null;
                        var pastas = new List<string>();
                        if (m.TryGetProperty("textureFolders", out var tf))
                            foreach (var p in tf.EnumerateArray())
                                if (Arquivo(raiz, "Data/" + p.GetString()) is { } d) pastas.Add(d);
                        pastas.Add(Path.GetDirectoryName(arq)!);
                        await Glb(arq, corpo, rot, pastas, Path.Combine(saida, nome + ".glb"));
                    }
                    catch (Exception e) { Console.WriteLine($"  {grupo},{numero} {rel}: {e.Message}"); erros++; continue; }
                    feitos[chave] = nome;
                }
                mapa[$"{grupo},{numero}"] = nome;
            }
        }
        File.WriteAllText(Path.Combine(saida, "modelos.json"), JsonSerializer.Serialize(mapa));
        Console.WriteLine($"itens: {mapa.Count} itens, {feitos.Count} modelos, {erros} erros");
        await Variantes.Rodar(data, saida, null);
    }

    internal static byte[] PretoTransparente(byte[] png)
    {
        using var img = SixLabors.ImageSharp.Image.Load<SixLabors.ImageSharp.PixelFormats.Rgba32>(png);
        img.ProcessPixelRows(linhas =>
        {
            for (int y = 0; y < linhas.Height; y++)
                foreach (ref var px in linhas.GetRowSpan(y))
                    px.A = (byte)Math.Min(255, Math.Max(px.R, Math.Max(px.G, px.B)) * 3);
        });
        using var ms = new MemoryStream();
        SixLabors.ImageSharp.ImageExtensions.SaveAsPng(img, ms);
        return ms.ToArray();
    }

    internal static string? Arquivo(string raiz, string rel)
    {
        var dir = raiz;
        foreach (var parte in rel.Split('/'))
        {
            var achou = Directory.EnumerateFileSystemEntries(dir)
                .FirstOrDefault(p => Path.GetFileName(p).Equals(parte, StringComparison.OrdinalIgnoreCase));
            if (achou == null) return null;
            dir = achou;
        }
        return dir;
    }

    internal static Matrix4x4[] Pose0(BMD bmd)
    {
        var r = new Matrix4x4[bmd.Bones.Length];
        for (int i = 0; i < r.Length; i++)
        {
            var b = bmd.Bones[i];
            r[i] = Matrix4x4.Identity;
            if (b == BMDTextureBone.Dummy || b.Matrixes.Length == 0) continue;
            var bm = b.Matrixes[0];
            if (bm.Position.Length == 0 || bm.Quaternion.Length == 0) continue;
            var local = Matrix4x4.CreateFromQuaternion(bm.Quaternion[0]);
            local.Translation = bm.Position[0];
            r[i] = b.Parent >= 0 && b.Parent < i ? local * r[b.Parent] : local;
        }
        return r;
    }

    // corpo: pose do esqueleto do jogador (pecas de armadura); null = ossos do proprio item
    internal static async Task Glb(string arquivo, Matrix4x4[]? corpo, Vector3 rot, List<string> pastas, string destino)
    {
        var bmd = await new BMDReader().Load(arquivo);
        var dir = Path.GetDirectoryName(arquivo)!;
        var ossos = corpo ?? Pose0(bmd);
        var giro = Matrix4x4.CreateFromQuaternion(MathUtils.AngleQuaternion(rot * (MathF.PI / 180f)));
        var mb = new MeshBuilder<VertexPositionNormal, VertexTexture1>(bmd.Name);
        foreach (var me in bmd.Meshes)
        {
            var mat = new MaterialBuilder(me.TexturePath).WithDoubleSide(true).WithUnlitShader();
            (byte[] png, bool alfa)? tex = null;
            foreach (var pasta in pastas)
                if ((tex = await Texturas.Textura(pasta, me.TexturePath)) != null) break;
            // asas em jpg: o cliente desenha somando a cor (o preto some); aqui o preto vira transparente
            if (tex != null && !tex.Value.alfa && Path.GetFileName(arquivo).StartsWith("wing", StringComparison.OrdinalIgnoreCase))
                tex = (PretoTransparente(tex.Value.png), true);
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
                var m = (v.Node >= 0 && v.Node < ossos.Length ? ossos[v.Node] : Matrix4x4.Identity) * giro;
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
}
