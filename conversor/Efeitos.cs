// Texturas e modelos dos efeitos de skill (Data/Effect e Data/Skill) pro Godot.
// Uso: conversor efeitos <pasta Data> <saida>
// Grava <saida>/tex/<nome>.png (OZJ e OZT, nome em minusculas) e <saida>/<nome>.glb
// (cada BMD de Data/Skill e Data/Effect, com a acao 0 como "anda" quando tem).
using Client.Data.BMD;
using Client.Data.Texture;
using SixLabors.ImageSharp;

static class Efeitos
{
    public static async Task Rodar(string data, string saida)
    {
        Directory.CreateDirectory(Path.Combine(saida, "tex"));
        int texs = 0, mods = 0, erros = 0;
        foreach (var sub in new[] { "Effect", "Skill" })
        {
            var dir = Directory.EnumerateDirectories(data).First(d => Path.GetFileName(d).Equals(sub, StringComparison.OrdinalIgnoreCase));
            foreach (var f in Directory.GetFiles(dir).Order())
            {
                var ext = Path.GetExtension(f).ToLowerInvariant();
                var nome = Path.GetFileNameWithoutExtension(f).ToLowerInvariant().Replace(' ', '_').Replace("!", "");
                try
                {
                    if (ext is ".ozj" or ".ozt")
                    {
                        var destino = Path.Combine(saida, "tex", nome + (ext == ".ozt" ? "_t" : "") + ".png");
                        TextureData t = ext == ".ozt" ? await new OZTReader().Load(f) : await new OZJReader().Load(f);
                        using var img = Texturas.Imagem(t);
                        await img.SaveAsPngAsync(destino);
                        texs++;
                    }
                    else if (ext == ".bmd")
                    {
                        var bmd = await new BMDReader().Load(f);
                        if (bmd.Bones.Length == 0) throw new Exception("sem ossos");
                        var acoes = bmd.Actions.Length > 0 && bmd.Actions[0].NumAnimationKeys > 1 ? new Dictionary<string, int> { ["anda"] = 0 } : [];
                        await Personagens.Glb(bmd, [(bmd, dir)], [], acoes, [], Path.Combine(saida, nome + ".glb"));
                        mods++;
                    }
                }
                catch (Exception e) { Console.WriteLine($"  {sub}/{Path.GetFileName(f)}: {e.Message}"); erros++; }
            }
        }
        Console.WriteLine($"efeitos: {texs} texturas, {mods} modelos, {erros} erros");
    }
}
