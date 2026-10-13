// Personagens animados: monstros, NPCs e o jogador viram GLB com esqueleto e animacoes.
// Uso: conversor personagens <pasta Data> <saida>
// Le personagens.json (nome -> esqueleto, partes, acoes) e grava <saida>/<nome>.glb
// e <saida>/personagens.json (acoes de cada um: nome, quadros, se trava a posicao).
// No MU cada vertice pertence a um osso so; aqui vira skin com um joint de peso 1.
// As animacoes saem com 1 s por quadro: o Godot acelera pelo PlaySpeed do cliente (x25).
using System.Numerics;
using System.Text.Json;
using Client.Data;
using Client.Data.BMD;
using SharpGLTF.Geometry;
using SharpGLTF.Geometry.VertexTypes;
using SharpGLTF.Materials;
using SharpGLTF.Scenes;

static class Personagens
{
    record Def(string esqueleto, string[]? partes, Dictionary<string, int> acoes, int[]? esconde);

    public static async Task Rodar(string data, string saida)
    {
        Directory.CreateDirectory(saida);
        var defs = JsonSerializer.Deserialize<Dictionary<string, Def>>(
            File.ReadAllText(Path.Combine(AppContext.BaseDirectory, "personagens.json")))!;
        var info = new Dictionary<string, object>();
        foreach (var (nome, d) in defs)
        {
            try
            {
                var esq = await Ler(data, d.esqueleto);
                var partes = new List<(BMD bmd, string dir)>();
                foreach (var p in d.partes ?? [d.esqueleto])
                {
                    var arq = Arquivo(data, p);
                    if (arq == null) { Console.WriteLine($"  {nome}: falta {p}"); continue; }
                    partes.Add((await new BMDReader().Load(arq), Path.GetDirectoryName(arq)!));
                }
                var acoes = await Glb(esq, partes, d.acoes, d.esconde ?? [], Path.Combine(saida, nome + ".glb"));
                info[nome] = acoes;
                Console.WriteLine($"{nome}: {esq.Bones.Length} ossos, {esq.Actions.Length} acoes, {partes.Sum(p => p.bmd.Meshes.Length)} malhas");
            }
            catch (Exception e) { Console.WriteLine($"  {nome}: {e.Message}"); }
        }
        File.WriteAllText(Path.Combine(saida, "personagens.json"), JsonSerializer.Serialize(info));
    }

    // conversor acoes <arquivo.bmd>: quadros de cada acao e altura do osso 0 no comeco e no fim
    public static async Task Acoes(string arq)
    {
        var b = await new BMDReader().Load(arq);
        var r = b.Bones.FirstOrDefault(o => o != BMDTextureBone.Dummy && o.Matrixes.Length > 0);
        for (int a = 0; a < b.Actions.Length; a++)
        {
            var p = r?.Matrixes[a].Position;
            Console.WriteLine($"{a} quadros={b.Actions[a].NumAnimationKeys} trava={b.Actions[a].LockPositions} z={p?.FirstOrDefault().Z:0}->{p?.LastOrDefault().Z:0}");
        }
    }

    static string? Arquivo(string data, string rel)
    {
        var dir = data;
        foreach (var parte in rel.Split('/'))
        {
            var achou = Directory.EnumerateFileSystemEntries(dir)
                .FirstOrDefault(p => Path.GetFileName(p).Equals(parte, StringComparison.OrdinalIgnoreCase));
            if (achou == null) return null;
            dir = achou;
        }
        return dir;
    }

    static async Task<BMD> Ler(string data, string rel) =>
        await new BMDReader().Load(Arquivo(data, rel) ?? throw new Exception($"sem {rel}"));

    static Matrix4x4 Local(BMDTextureBone b, int acao, int quadro)
    {
        var bm = b.Matrixes[acao];
        quadro = Math.Min(quadro, Math.Min(bm.Position.Length, bm.Quaternion.Length) - 1);
        var m = Matrix4x4.CreateFromQuaternion(bm.Quaternion[quadro]);
        m.Translation = bm.Position[quadro];
        return m;
    }

    static async Task<Dictionary<string, object>> Glb(BMD esq, List<(BMD bmd, string dir)> partes,
        Dictionary<string, int> acoes, int[] esconde, string destino)
    {
        // ossos: um no por osso do MU; osso "dummy" vira no parado na raiz
        var raiz = new NodeBuilder("raiz");
        var nos = new NodeBuilder[esq.Bones.Length];
        NodeBuilder No(int i)
        {
            if (nos[i] != null) return nos[i];
            var b = esq.Bones[i];
            var dummy = b == BMDTextureBone.Dummy || b.Matrixes.Length == 0;
            var pai = !dummy && b.Parent >= 0 && b.Parent < nos.Length && b.Parent != i ? No(b.Parent) : raiz;
            var n = pai.CreateNode($"osso{i}");
            if (!dummy) n.LocalMatrix = Local(b, 0, 0);
            return nos[i] = n;
        }
        for (int i = 0; i < nos.Length; i++) No(i);

        // a pose de repouso (acao 0, quadro 0) em coordenadas do mundo: os vertices do MU sao relativos ao osso
        var mundo = new Matrix4x4[nos.Length];
        for (int i = 0; i < nos.Length; i++) mundo[i] = nos[i].WorldMatrix;

        var info = new Dictionary<string, object>();
        foreach (var (nomeAcao, a) in acoes)
        {
            if (a < 0 || a >= esq.Actions.Length) continue;
            var act = esq.Actions[a];
            int quadros = Math.Max(act.LockPositions ? act.NumAnimationKeys - 1 : act.NumAnimationKeys, 1);
            for (int i = 0; i < nos.Length; i++)
            {
                var b = esq.Bones[i];
                if (b == BMDTextureBone.Dummy || b.Matrixes.Length <= a) continue;
                var bm = b.Matrixes[a];
                if (bm.Position.Length == 0) continue;
                var tr = nos[i].UseTranslation(nomeAcao);
                var rt = nos[i].UseRotation(nomeAcao);
                // um quadro a mais no fim igual ao primeiro: o laco fecha liso
                for (int k = 0; k <= quadros; k++)
                {
                    int q = Math.Min(k % quadros, bm.Position.Length - 1);
                    var p = bm.Position[q];
                    // LockPositions: o osso raiz fica no lugar em X/Y (o MU anda pela posicao do objeto)
                    if (i == 0 && act.LockPositions) p = new Vector3(bm.Position[0].X, bm.Position[0].Y, p.Z);
                    tr.SetPoint(k, p);
                    rt.SetPoint(k, Quaternion.Normalize(bm.Quaternion[Math.Min(q, bm.Quaternion.Length - 1)]));
                }
            }
            info[nomeAcao] = new { a, quadros };
        }

        var mb = new MeshBuilder<VertexPositionNormal, VertexTexture1, VertexJoints4>("corpo");
        int malha = 0;
        foreach (var (bmd, dir) in partes)
        foreach (var me in bmd.Meshes)
        {
            if (esconde.Contains(malha++)) continue;
            var mat = new MaterialBuilder(me.TexturePath).WithDoubleSide(true).WithMetallicRoughness(0, 1);
            var tex = await Texturas.Textura(dir, me.TexturePath);
            if (tex != null)
            {
                mat.WithChannelImage(KnownChannel.BaseColor, new SharpGLTF.Memory.MemoryImage(tex.Value.png));
                if (tex.Value.alfa) mat.WithAlpha(SharpGLTF.Materials.AlphaMode.MASK, 0.5f);
            }
            var prim = mb.UsePrimitive(mat);
            (VertexPositionNormal, VertexTexture1, VertexJoints4) V(BMDTriangle tri, int k)
            {
                var v = me.Vertices[tri.VertexIndex[k]];
                var nrm = me.Normals[tri.NormalIndex[k]];
                int osso = v.Node >= 0 && v.Node < mundo.Length ? v.Node : 0;
                var m = mundo.Length > 0 ? mundo[osso] : Matrix4x4.Identity;
                var p = Vector3.Transform(v.Position, m);
                var n = Vector3.Normalize(Vector3.TransformNormal(nrm.Normal, m));
                if (float.IsNaN(n.X)) n = Vector3.UnitZ;
                var uv = me.TexCoords[tri.TexCoordIndex[k]];
                return (new VertexPositionNormal(p, n), new VertexTexture1(new Vector2(uv.U, uv.V)), new VertexJoints4((osso, 1f)));
            }
            foreach (var tri in me.Triangles)
            {
                prim.AddTriangle(V(tri, 0), V(tri, 1), V(tri, 2));
                if (tri.Polygon == 4) prim.AddTriangle(V(tri, 0), V(tri, 2), V(tri, 3));
            }
        }
        var cena = new SceneBuilder();
        cena.AddSkinnedMesh(mb, Matrix4x4.Identity, nos);
        cena.ToGltf2().SaveGLB(destino);
        return info;
    }
}
