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
    // arma: BMD do item preso no osso da mao; esquerda = Weapon[1] do cliente (escudo ou segunda arma);
    // soma: malhas da arma que o cliente desenha somadas (BlendMesh do item em ZzzObject.cpp; -1 = todas,
    // o BlendMesh -2); o material sai com o nome "soma:<textura>" e o jogo troca pelo somado
    internal record Arma(string bmd, int osso, bool esquerda = false, int[]? soma = null);
    // texturas: pasta a mais onde procurar textura (a Uniria le as dela de Data/Item)
    record Def(string esqueleto, string[]? partes, Dictionary<string, int> acoes, int[]? esconde, Arma[]? armas, string? texturas = null);

    // so: converte so esses nomes (separados por virgula) e soma no personagens.json que ja existe
    public static async Task Rodar(string data, string saida, string? so = null)
    {
        Directory.CreateDirectory(saida);
        var defs = JsonSerializer.Deserialize<Dictionary<string, Def>>(
            File.ReadAllText(Path.Combine(AppContext.BaseDirectory, "personagens.json")))!;
        var info = new Dictionary<string, object>();
        var lista = so?.Split(',');
        var json = Path.Combine(saida, "personagens.json");
        if (lista != null && File.Exists(json))
            foreach (var (k, v) in JsonSerializer.Deserialize<Dictionary<string, JsonElement>>(File.ReadAllText(json))!)
                info[k] = v;
        foreach (var (nome, d) in defs)
        {
            if (lista != null && !lista.Contains(nome)) continue;
            try
            {
                var esq = await Ler(data, d.esqueleto);
                var partes = new List<(BMD bmd, string dir)>();
                foreach (var p in d.partes ?? [d.esqueleto])
                {
                    var arq = Arquivo(data, p);
                    if (arq == null) { Console.WriteLine($"  {nome}: falta {p}"); continue; }
                    var parte = await new BMDReader().Load(arq);
                    parte.Name = Path.GetFileNameWithoutExtension(arq);
                    var extra = d.texturas != null ? Arquivo(data, d.texturas) : null;
                    partes.Add((parte, Path.GetDirectoryName(arq)! + (extra != null ? ";" + extra : "")));
                }
                var armas = new List<(BMD bmd, string dir, Arma a)>();
                foreach (var a in d.armas ?? [])
                {
                    var arq = Arquivo(data, a.bmd);
                    if (arq == null) { Console.WriteLine($"  {nome}: falta {a.bmd}"); continue; }
                    armas.Add((await new BMDReader().Load(arq), Path.GetDirectoryName(arq)!, a));
                }
                var acoes = await Glb(esq, partes, armas, d.acoes, d.esconde ?? [], Path.Combine(saida, nome + ".glb"));
                info[nome] = acoes;
                Console.WriteLine($"{nome}: {esq.Bones.Length} ossos, {esq.Actions.Length} acoes, {partes.Sum(p => p.bmd.Meshes.Length)} malhas");
            }
            catch (Exception e) { Console.WriteLine($"  {nome}: {e.Message}"); }
        }
        File.WriteAllText(json, JsonSerializer.Serialize(info));
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

    // pose 0 de cada osso de um BMD, em coordenadas do modelo
    static Matrix4x4[] Pose0(BMD bmd)
    {
        var r = new Matrix4x4[bmd.Bones.Length];
        for (int i = 0; i < r.Length; i++)
        {
            var b = bmd.Bones[i];
            r[i] = Matrix4x4.Identity;
            if (b == BMDTextureBone.Dummy || b.Matrixes.Length == 0 || b.Matrixes[0].Position.Length == 0) continue;
            var local = Local(b, 0, 0);
            r[i] = b.Parent >= 0 && b.Parent < i ? local * r[b.Parent] : local;
        }
        return r;
    }

    // onde o cliente poe a arma em relacao ao osso (RenderLinkObject, caso padrao)
    static Matrix4x4 Encaixe(string item, bool esquerda)
    {
        static Matrix4x4 M(float ax, float ay, float az, float tx, float ty, float tz)
        {
            var m = Matrix4x4.CreateFromQuaternion(MathUtils.AngleQuaternion(new Vector3(ax, ay, az) * (MathF.PI / 180f)));
            m.Translation = new Vector3(tx, ty, tz);
            return m;
        }
        var nome = Path.GetFileName(item).ToLowerInvariant();
        bool escudo = nome.StartsWith("shield");
        var m = escudo ? M(70, 0, 90, -10, 0, 0)
            : nome.StartsWith("bow") || nome.StartsWith("crossbow") ? M(70, 0, 90, -10, 5, 10)
            : M(70, 0, 90, -20, 5, 40);
        // segunda arma na mao esquerda: o cliente gira mais (145, 0, 275) e desloca (0, 10, -30)
        if (esquerda && !escudo) m = M(145, 0, 275, 0, 10, -30) * m;
        return m;
    }

    // dir de cada parte: uma ou mais pastas de textura separadas por ';' (a primeira que tiver ganha)
    // preto: textura sem alfa vira transparente onde e escura (asas em jpg, que o cliente soma)
    internal static async Task<Dictionary<string, object>> Glb(BMD esq, List<(BMD bmd, string dir)> partes,
        List<(BMD bmd, string dir, Arma a)> armas, Dictionary<string, int> acoes, int[] esconde, string destino, bool preto = false)
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

        // uma malha por parte (o nome e o do arquivo: helmclass02, armormale10...): o jogo troca a parte
        // pela peca equipada; as armas vao juntas numa malha "arma"
        var malhas = new List<MeshBuilder<VertexPositionNormal, VertexTexture1, VertexJoints4>>();
        MeshBuilder<VertexPositionNormal, VertexTexture1, VertexJoints4> mb = null!;
        // cada vertice: (osso do esqueleto que o move, matriz da pose de repouso)
        async Task Malha(BMDTextureMesh me, string dir, Func<BMDTextureVertex, (int osso, Matrix4x4 m)> onde, bool soma = false)
        {
            var mat = new MaterialBuilder((soma ? "soma:" : "") + me.TexturePath).WithDoubleSide(true).WithMetallicRoughness(0, 1);
            (byte[] png, bool alfa)? tex = null;
            foreach (var d in dir.Split(';'))
                if ((tex = await Texturas.Textura(d, me.TexturePath)) != null) break;
            if (preto && tex != null && !tex.Value.alfa)
                tex = (Itens.PretoTransparente(tex.Value.png), true);
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
                var (osso, m) = onde(v);
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
        int malha = 0;
        foreach (var (bmd, dir) in partes)
        {
            var nomeParte = (bmd.Name ?? "corpo").ToLowerInvariant();
            if (nomeParte.EndsWith(".bmd")) nomeParte = nomeParte[..^4];
            malhas.Add(mb = new(nomeParte));
        foreach (var me in bmd.Meshes)
        {
            if (esconde.Contains(malha++)) continue;
            await Malha(me, dir, v =>
            {
                int osso = v.Node >= 0 && v.Node < mundo.Length ? v.Node : 0;
                return (osso, mundo.Length > 0 ? mundo[osso] : Matrix4x4.Identity);
            });
        }
        }
        if (armas.Count > 0) malhas.Add(mb = new("arma"));
        // armas: pose 0 do item, encaixe da mao, osso da mao; o vertice inteiro segue o osso da mao
        foreach (var (bmd, dir, a) in armas)
        {
            if (a.osso < 0 || a.osso >= mundo.Length) { Console.WriteLine($"  osso {a.osso} fora do esqueleto"); continue; }
            var pose = Pose0(bmd);
            var encaixe = Encaixe(a.bmd, a.esquerda) * mundo[a.osso];
            for (int k = 0; k < bmd.Meshes.Length; k++)
                await Malha(bmd.Meshes[k], dir, v => (a.osso, (v.Node >= 0 && v.Node < pose.Length ? pose[v.Node] : Matrix4x4.Identity) * encaixe),
                    a.soma != null && (a.soma.Contains(-1) || a.soma.Contains(k)));
        }
        var cena = new SceneBuilder();
        foreach (var m in malhas)
            if (m.Primitives.Count > 0) cena.AddSkinnedMesh(m, Matrix4x4.Identity, nos).WithName(m.Name);
        cena.ToGltf2().SaveGLB(destino);
        return info;
    }
}
