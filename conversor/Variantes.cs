// Itens que mudam de modelo pelo nivel (o cliente troca o modelo em ZzzObject.cpp CreateItem e em
// ZzzInventory.cpp RenderItem3D; rotacao e escala de Render/Items/ItemDisplay.cpp). A chave e
// "grupo,numero+nivel" e o Godot procura ela antes da "grupo,numero" (ItensMU.chave_modelo).
// Uso: conversor variantes <pasta Data> <saida itens> <saida modelos>
// (acrescenta nos dois modelos.json sem refazer o resto; itens e modelos tambem chamam no fim)
using System.Numerics;
using System.Text.Json;
using System.Text.Json.Nodes;
using Client.Data.BMD;

static class Variantes
{
    // Box of Luck (14,11) +8 a +12 = Box of Kundun +1 a +5: MODEL_EVENT + 10 (Data/Item/MagicBox08.bmd),
    // inventario na rotacao padrao (270, -10, 0), chao em (0, 0, -45) com escala 0,2
    static readonly (string chave, string rel, Vector3 inv, float[] chao, float escala)[] Lista =
        [.. Enumerable.Range(8, 5).Select(n => ($"14,11+{n}", "Data/Item/MagicBox08.bmd", new Vector3(270, -10, 0), new float[] { 0, 0, -45 }, 0.2f))];

    public static async Task Rodar(string data, string? itens, string? modelos)
    {
        var raiz = Path.GetDirectoryName(Path.GetFullPath(data).TrimEnd('/'))!;
        var mi = itens != null ? Ler(itens) : null;
        var mm = modelos != null ? Ler(modelos) : null;
        foreach (var v in Lista)
        {
            var arq = Itens.Arquivo(raiz, v.rel) ?? throw new Exception("falta " + v.rel);
            var nome = Path.GetFileNameWithoutExtension(v.rel).ToLowerInvariant();
            var pastas = new List<string> { Path.GetDirectoryName(arq)! };
            if (mi != null)
            {
                var glb = Path.Combine(itens!, nome + ".glb");
                if (!File.Exists(glb)) await Itens.Glb(arq, null, v.inv, pastas, glb);
                mi[v.chave] = nome;
            }
            if (mm != null)
            {
                var glb = Path.Combine(modelos!, nome + ".glb");
                if (!File.Exists(glb))
                {
                    var bmd = await new BMDReader().Load(arq);
                    bmd.Name = "outro";
                    await Personagens.Glb(bmd, [(bmd, string.Join(';', pastas))], [], [], [], glb, false);
                }
                mm[v.chave] = new JsonArray(nome, "outro", new JsonArray(v.chao.Select(x => (JsonNode)x).ToArray()), 0f, v.escala);
            }
        }
        if (mi != null) Gravar(itens!, mi);
        if (mm != null) Gravar(modelos!, mm);
        Console.WriteLine($"variantes: {Lista.Length} chaves");
    }

    static JsonObject Ler(string pasta) => JsonNode.Parse(File.ReadAllText(Path.Combine(pasta, "modelos.json")))!.AsObject();

    static void Gravar(string pasta, JsonObject o)
    {
        var ordem = new JsonObject();
        foreach (var k in o.Select(p => p.Key).Order(StringComparer.Ordinal).ToList())
        {
            var n = o[k];
            o.Remove(k);
            ordem[k] = n;
        }
        File.WriteAllText(Path.Combine(pasta, "modelos.json"), ordem.ToJsonString());
    }
}
