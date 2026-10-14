// Modelos dos itens pra vestir e pro chao: um GLB por modelo, sem a rotacao do inventario.
// Uso: conversor modelos <pasta Data> <pasta Models do MuMain> <saida>
// - pecas de armadura (grupos 7 a 11 em Data/Player): skin no esqueleto do player.bmd, com os
//   mesmos ossos (osso<i>) dos personagens: o Godot troca a peca do boneco por esta;
// - asas (grupo 12) e ajudantes (grupo 13): esqueleto proprio com a acao 0 como "voa";
// - o resto (armas, escudos, joias, pocoes): pose 0 do proprio modelo.
// Grava <saida>/<nome>.glb e <saida>/modelos.json:
// "grupo,numero" -> [glb, tipo, rotacao no chao (graus), altura no chao, escala no chao ou 0].
using System.Numerics;
using System.Text.Json;
using Client.Data.BMD;

static class Modelos
{
    public static async Task Rodar(string data, string modelos, string saida)
    {
        Directory.CreateDirectory(saida);
        var raiz = Path.GetDirectoryName(Path.GetFullPath(data).TrimEnd('/'))!;
        var comp = new Dictionary<string, string>();
        using (var j = JsonDocument.Parse(File.ReadAllText(Path.Combine(modelos, "SharedModels.json"))))
            foreach (var m in j.RootElement.GetProperty("models").EnumerateArray())
                comp[m.GetProperty("name").GetString()!] = m.GetProperty("file").GetString()!;
        var jogador = await new BMDReader().Load(Itens.Arquivo(raiz, "Data/Player/player.bmd")!);
        var mapa = new SortedDictionary<string, object[]>(StringComparer.Ordinal);
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
                bool parte = grupo is >= 7 and <= 11 && rel.Contains("/Player/", StringComparison.OrdinalIgnoreCase);
                string tipo = parte ? "parte" : grupo <= 6 ? "arma" : grupo == 12 ? "asa" : grupo == 13 ? "pet" : "outro";
                var chave = rel.ToLowerInvariant() + "|" + tipo;
                if (!feitos.TryGetValue(chave, out var nome))
                {
                    nome = Path.GetFileNameWithoutExtension(rel).ToLowerInvariant();
                    while (feitos.ContainsValue(nome)) nome += "_";
                    var arq = Itens.Arquivo(raiz, rel);
                    if (arq == null) { Console.WriteLine($"  {grupo},{numero}: falta {rel}"); erros++; continue; }
                    try
                    {
                        var pastas = new List<string>();
                        if (m.TryGetProperty("textureFolders", out var tf))
                            foreach (var p in tf.EnumerateArray())
                                if (Itens.Arquivo(raiz, "Data/" + p.GetString()) is { } d) pastas.Add(d);
                        pastas.Add(Path.GetDirectoryName(arq)!);
                        var bmd = await new BMDReader().Load(arq);
                        bmd.Name = tipo;
                        if (bmd.Bones.Length == 0) throw new Exception("modelo sem ossos");
                        var acoes = tipo is "asa" or "pet" && bmd.Actions.Length > 0 ? new Dictionary<string, int> { ["voa"] = 0 } : [];
                        bool preto = Path.GetFileName(arq).StartsWith("wing", StringComparison.OrdinalIgnoreCase);
                        await Personagens.Glb(parte ? jogador : bmd, [(bmd, string.Join(';', pastas))], [], acoes, [],
                            Path.Combine(saida, nome + ".glb"), preto);
                    }
                    catch (Exception e) { Console.WriteLine($"  {grupo},{numero} {rel}: {e.Message}"); erros++; continue; }
                    feitos[chave] = nome;
                }
                float[] rot = [0, 0, 0];
                float altura = 0, escala = 0; // escala 0: sem escala propria (o cliente usa 0,8)
                if (m.TryGetProperty("ground", out var gr))
                {
                    if (gr.TryGetProperty("rotation", out var r)) rot = [r[0].GetSingle(), r[1].GetSingle(), r[2].GetSingle()];
                    if (gr.TryGetProperty("bodyHeight", out var h)) altura = h.GetSingle();
                    if (gr.TryGetProperty("scale", out var s)) escala = s.GetSingle();
                }
                mapa[$"{grupo},{numero}"] = [nome, tipo, rot, altura, escala];
            }
        }
        File.WriteAllText(Path.Combine(saida, "modelos.json"), JsonSerializer.Serialize(mapa));
        Console.WriteLine($"modelos: {mapa.Count} itens, {feitos.Count} modelos, {erros} erros");
    }
}
