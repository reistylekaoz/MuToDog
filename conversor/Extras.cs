// O que cada mapa tem de proprio alem do terreno e dos objetos (MapManager.cpp do cliente S6).
// Uso: conversor extras <pasta Data> <mundo> <saida>
// Grava em <saida>/mundo<N>/:
//   grama/<i>.png  cartao de grama da camada 1 = i (World<N>/TileGrass0<i+1>.OZT; so os que existem)
//   folha1.png, folha2.png  neve (Devias) ou folha (Lorencia, Noria): leaf01 e leaf02
//   warp0<1..3>.glb  portal de Devias e Noria (Data/Npc/warp0X.bmd, com a acao 0 como "anda")
//   agua/<0..31>.png, bolha.png  Atlans: agua que corre no chao e bolha
//   agua1.png, agua2.png  Kalima: a agua que faz as vezes de chao
//   musica.mp3, fundo.wav  Dungeon, Lost Tower, Atlans e Tarkan: musica do mapa todo e o som de fundo
//     (SceneManager.cpp; vao no pacote do mapa, o pck principal do navegador esta no limite)
using Client.Data.BMD;
using Client.Data.Texture;
using SixLabors.ImageSharp;

static class Extras
{
    static string? Achar(string dir, string nome) =>
        Directory.EnumerateFileSystemEntries(dir).FirstOrDefault(p => Path.GetFileName(p).Equals(nome, StringComparison.OrdinalIgnoreCase));

    internal static async Task<bool> Png(string arquivo, string destino)
    {
        TextureData t = arquivo.EndsWith(".OZT", StringComparison.OrdinalIgnoreCase)
            ? await new OZTReader().Load(arquivo) : await new OZJReader().Load(arquivo);
        using var img = Texturas.Imagem(t);
        await img.SaveAsPngAsync(destino);
        Console.WriteLine($"  {Path.GetFileName(arquivo)} -> {Path.GetFileName(destino)} ({t.Width}x{t.Height})");
        return true;
    }

    public static async Task Rodar(string data, int mundo, string saida)
    {
        var pasta = Achar(data, $"World{mundo}") ?? throw new Exception($"sem World{mundo}");
        var dest = Path.Combine(saida, $"mundo{mundo}");
        Directory.CreateDirectory(Path.Combine(dest, "grama"));
        for (int i = 0; i < 3; i++)
        {
            var f = Achar(pasta, $"TileGrass0{i + 1}.OZT");
            if (f != null) await Png(f, Path.Combine(dest, "grama", $"{i}.png"));
        }
        // o cliente le leaf01.tga em Lorencia e Noria e leaf01.jpg nos outros (a neve de Devias)
        var folha1 = mundo is 1 or 4 ? new[] { "leaf01.OZT", "leaf01.OZJ" } : new[] { "leaf01.OZJ", "leaf01.OZT" };
        foreach (var n in folha1)
            if (Achar(pasta, n) is { } f) { await Png(f, Path.Combine(dest, "folha1.png")); break; }
        if (Achar(pasta, "leaf02.OZJ") is { } f2) await Png(f2, Path.Combine(dest, "folha2.png"));
        // Atlans: agua do chao em 32 quadros (Object8/wt00..31) e a bolha (Object8/drop01)
        if (mundo == 8)
        {
            var obj8 = Achar(data, "Object8") ?? throw new Exception("sem Object8");
            Directory.CreateDirectory(Path.Combine(dest, "agua"));
            for (int i = 0; i < 32; i++)
                await Png(Achar(obj8, $"wt{i:00}.OZJ")!, Path.Combine(dest, "agua", $"{i}.png"));
            await Png(Achar(obj8, "drop01.OZJ")!, Path.Combine(dest, "bolha.png"));
        }
        // Kalima: o chao e so agua (CSWaterTerrain): water1.tga com as ondas e water2.jpg somado por cima
        if (mundo == 25)
        {
            var obj25 = Achar(data, "Object25") ?? throw new Exception("sem Object25");
            await Png(Achar(obj25, "water1.OZT")!, Path.Combine(dest, "agua1.png"));
            await Png(Achar(obj25, "water2.OZJ")!, Path.Combine(dest, "agua2.png"));
        }
        // musica e som de fundo do mapa todo (PlayBGM e PlayWorldAmbientSounds do SceneManager.cpp do cliente)
        var sons = mundo switch { 2 => ("Dungeon.mp3", "aDungeon.wav"), 5 => ("lost_tower_a.mp3", "aTower.wav"),
            8 => ("atlans.mp3", "aWater.wav"), 9 => ("tarkan.mp3", "desert.wav"),
            11 => ("icarus.mp3", "aHeaven.wav"), 25 => ("kalima.mp3", "aKalima.wav"), 63 => ("Santa_Village.mp3", ""), 65 => ("DuelArena.mp3", ""), 31 => ("castle.mp3", ""), 32 => ("huntingground.mp3", ""),
            34 => ("Aida.mp3", ""), 35 => ("crywolf1st.mp3", ""), 38 => ("kanturu_1st.mp3", ""), 39 => ("kanturu_2nd.mp3", ""),
            52 => ("elbeland.mp3", ""), 57 => ("SwampOfCalmness.mp3", ""), 58 => ("Raklion.mp3", ""), 64 => ("PK_Field.mp3", ""),
            80 => ("iDoppelganger.mp3", "aWind.wav"), 81 => ("Karutan_A.mp3", "Karutan/Karutan_desert_env.wav"),
            82 => ("Karutan_B.mp3", "Karutan/Karutan_desert_env.wav"), _ => default };
        if (sons != default)
        {
            File.Copy(Achar(Achar(data, "Music")!, sons.Item1)!, Path.Combine(dest, "musica.mp3"), true);
            var som = Achar(data, "Sound")!;
            foreach (var parte in sons.Item2.Split('/', StringSplitOptions.RemoveEmptyEntries)) som = Achar(som, parte)!;
            if (sons.Item2 != "") File.Copy(som, Path.Combine(dest, "fundo.wav"), true);
            Console.WriteLine($"  {sons.Item1}, {sons.Item2} -> musica.mp3, fundo.wav");
        }
        if (mundo is 3 or 4)
        {
            var npc = Achar(data, "NPC") ?? throw new Exception("sem NPC");
            for (int i = 1; i <= 3; i++)
            {
                var bmd = await new BMDReader().Load(Achar(npc, $"warp0{i}.bmd")!);
                var acoes = bmd.Actions.Length > 0 && bmd.Actions[0].NumAnimationKeys > 1 ? new Dictionary<string, int> { ["anda"] = 0 } : [];
                await Personagens.Glb(bmd, [(bmd, npc)], [], acoes, [], Path.Combine(dest, $"warp0{i}.glb"));
                Console.WriteLine($"  warp0{i}.glb ({bmd.Meshes.Length} malhas, {(acoes.Count > 0 ? bmd.Actions[0].NumAnimationKeys + " quadros" : "parado")})");
            }
        }
    }
}
