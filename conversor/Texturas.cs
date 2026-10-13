// Texturas do MU (OZJ/OZT) pra PNG, usadas pelo mundo e pelos personagens.
using Client.Data.Texture;
using SixLabors.ImageSharp;
using SixLabors.ImageSharp.PixelFormats;

static class Texturas
{
    static string? Achar(string dir, string nome) =>
        Directory.EnumerateFileSystemEntries(dir).FirstOrDefault(p => Path.GetFileName(p).Equals(nome, StringComparison.OrdinalIgnoreCase));

    public static Image<Rgba32> Imagem(TextureData t)
    {
        var img = new Image<Rgba32>(t.Width, t.Height);
        for (int y = 0; y < t.Height; y++)
        for (int x = 0; x < t.Width; x++)
        {
            int o = (y * t.Width + x) * t.Components;
            img[x, y] = t.Components == 4
                ? new Rgba32(t.Data[o], t.Data[o + 1], t.Data[o + 2], t.Data[o + 3])
                : new Rgba32(t.Data[o], t.Data[o + 1], t.Data[o + 2], 255);
        }
        return img;
    }

    public static async Task<(byte[] png, bool alfa)?> Textura(string dir, string caminho)
    {
        var baseNome = Path.GetFileNameWithoutExtension(caminho.Replace('\\', '/'));
        var ext = Path.GetExtension(caminho).ToLowerInvariant();
        string[] tentar = ext == ".tga" ? [".OZT", ".OZJ"] : [".OZJ", ".OZT"];
        foreach (var e in tentar)
        {
            var f = Achar(dir, baseNome + e);
            if (f == null) continue;
            TextureData t = e == ".OZT" ? await new OZTReader().Load(f) : await new OZJReader().Load(f);
            using var img = Imagem(t);
            bool alfa = false;
            if (t.Components == 4) for (int i = 3; i < t.Data.Length; i += 4) if (t.Data[i] < 250) { alfa = true; break; }
            using var ms = new MemoryStream();
            img.SaveAsPng(ms);
            return (ms.ToArray(), alfa);
        }
        return null;
    }
}
