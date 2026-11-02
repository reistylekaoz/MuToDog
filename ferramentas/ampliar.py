#!/usr/bin/env python3
# Amplia texturas 4x com Real-ESRGAN no processador (sem placa de video) e gera o normal map.
# Uso: ~/casa/trabalho/.ferramentas/esrgan/bin/python ferramentas/ampliar.py <entrada.png|pasta> <saida> [--escala 2|4] [--rede geral|forte] [--normal]
# Textura do MU repete (chao, parede): amplia com 16 px da outra borda em volta e corta, pra nao abrir costura.
# O alfa vai no bicubico (a rede so ve RGB). --escala 2 amplia 4x e reduz pra 2x (fica mais nitido que 2x direto).
import argparse, os, sys, glob
import numpy as np
import torch
from torch import nn
from torch.nn import functional as F
from PIL import Image

PESOS = os.path.expanduser('~/casa/trabalho/.ferramentas/modelos_ia')
BORDA = 16


class SRVGGNetCompact(nn.Module):
    # realesr-general-x4v3 (Real-ESRGAN, BSD-3)
    def __init__(self, feat=64, convs=32, escala=4):
        super().__init__()
        self.escala = escala
        b = [nn.Conv2d(3, feat, 3, 1, 1), nn.PReLU(feat)]
        for _ in range(convs):
            b += [nn.Conv2d(feat, feat, 3, 1, 1), nn.PReLU(feat)]
        b += [nn.Conv2d(feat, 3 * escala * escala, 3, 1, 1)]
        self.body = nn.ModuleList(b)
        self.upsampler = nn.PixelShuffle(escala)

    def forward(self, x):
        o = x
        for c in self.body:
            o = c(o)
        return self.upsampler(o) + F.interpolate(x, scale_factor=self.escala, mode='nearest')


class RDB(nn.Module):
    def __init__(self, f=64, g=32):
        super().__init__()
        self.conv1 = nn.Conv2d(f, g, 3, 1, 1)
        self.conv2 = nn.Conv2d(f + g, g, 3, 1, 1)
        self.conv3 = nn.Conv2d(f + 2 * g, g, 3, 1, 1)
        self.conv4 = nn.Conv2d(f + 3 * g, g, 3, 1, 1)
        self.conv5 = nn.Conv2d(f + 4 * g, f, 3, 1, 1)
        self.lrelu = nn.LeakyReLU(0.2, True)

    def forward(self, x):
        x1 = self.lrelu(self.conv1(x))
        x2 = self.lrelu(self.conv2(torch.cat((x, x1), 1)))
        x3 = self.lrelu(self.conv3(torch.cat((x, x1, x2), 1)))
        x4 = self.lrelu(self.conv4(torch.cat((x, x1, x2, x3), 1)))
        return self.conv5(torch.cat((x, x1, x2, x3, x4), 1)) * 0.2 + x


class RRDB(nn.Module):
    def __init__(self, f=64):
        super().__init__()
        self.rdb1, self.rdb2, self.rdb3 = RDB(f), RDB(f), RDB(f)

    def forward(self, x):
        return self.rdb3(self.rdb2(self.rdb1(x))) * 0.2 + x


class RRDBNet(nn.Module):
    # RealESRGAN_x4plus (Real-ESRGAN, BSD-3)
    def __init__(self, f=64, blocos=23):
        super().__init__()
        self.conv_first = nn.Conv2d(3, f, 3, 1, 1)
        self.body = nn.Sequential(*[RRDB(f) for _ in range(blocos)])
        self.conv_body = nn.Conv2d(f, f, 3, 1, 1)
        self.conv_up1 = nn.Conv2d(f, f, 3, 1, 1)
        self.conv_up2 = nn.Conv2d(f, f, 3, 1, 1)
        self.conv_hr = nn.Conv2d(f, f, 3, 1, 1)
        self.conv_last = nn.Conv2d(f, 3, 3, 1, 1)
        self.lrelu = nn.LeakyReLU(0.2, True)

    def forward(self, x):
        f = self.conv_first(x)
        f = f + self.conv_body(self.body(f))
        f = self.lrelu(self.conv_up1(F.interpolate(f, scale_factor=2, mode='nearest')))
        f = self.lrelu(self.conv_up2(F.interpolate(f, scale_factor=2, mode='nearest')))
        return self.conv_last(self.lrelu(self.conv_hr(f)))


def rede(nome):
    if nome == 'forte':
        r, arq = RRDBNet(), 'RealESRGAN_x4plus.pth'
    else:
        r, arq = SRVGGNetCompact(), 'realesr-general-x4v3.pth'
    sd = torch.load(os.path.join(PESOS, arq), map_location='cpu')
    r.load_state_dict(sd.get('params_ema', sd.get('params', sd)), strict=True)
    return r.eval()


def ampliar(r, img: Image.Image, escala: int) -> Image.Image:
    rgba = img.convert('RGBA')
    a = np.asarray(rgba).astype(np.float32) / 255.0
    w, h = rgba.size
    b = min(BORDA, w, h)
    rgb = np.pad(a[:, :, :3], ((b, b), (b, b), (0, 0)), mode='wrap')
    with torch.no_grad():
        t = torch.from_numpy(rgb).permute(2, 0, 1)[None]
        s = r(t).clamp(0, 1)[0].permute(1, 2, 0).numpy()
    s = s[b * 4:(b + h) * 4, b * 4:(b + w) * 4]
    out = Image.fromarray((s * 255 + 0.5).astype(np.uint8))
    alfa = rgba.getchannel('A').resize((w * 4, h * 4), Image.BICUBIC)
    out.putalpha(alfa)
    if escala != 4:
        out = out.resize((w * escala, h * escala), Image.LANCZOS)
    return out if img.mode == 'RGBA' or 'A' in img.getbands() else out.convert('RGB')


def normal(img: Image.Image, forca=2.0) -> Image.Image:
    # relevo pela luminancia (Sobel com repeticao nas bordas): claro = alto
    l = np.asarray(img.convert('L')).astype(np.float32) / 255.0
    p = np.pad(l, 1, mode='wrap')
    dx = (p[1:-1, 2:] - p[1:-1, :-2]) * 2 + (p[:-2, 2:] - p[:-2, :-2]) + (p[2:, 2:] - p[2:, :-2])
    dy = (p[2:, 1:-1] - p[:-2, 1:-1]) * 2 + (p[2:, :-2] - p[:-2, :-2]) + (p[2:, 2:] - p[:-2, 2:])
    n = np.stack([-dx * forca, dy * forca, np.ones_like(l)], -1)
    n /= np.linalg.norm(n, axis=-1, keepdims=True)
    return Image.fromarray(((n * 0.5 + 0.5) * 255 + 0.5).astype(np.uint8))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('entrada')
    ap.add_argument('saida')
    ap.add_argument('--escala', type=int, default=4)
    ap.add_argument('--rede', default='geral')
    ap.add_argument('--normal', action='store_true')
    ap.add_argument('--forca', type=float, default=2.0)
    a = ap.parse_args()
    torch.set_num_threads(os.cpu_count())
    r = rede(a.rede)
    if os.path.isdir(a.entrada):
        arqs = sorted(glob.glob(os.path.join(a.entrada, '**', '*.png'), recursive=True))
        base = a.entrada
    else:
        arqs, base = [a.entrada], os.path.dirname(a.entrada)
    for i, f in enumerate(arqs):
        destino = os.path.join(a.saida, os.path.relpath(f, base)) if os.path.isdir(a.entrada) else a.saida
        if os.path.exists(destino) and os.path.getmtime(destino) > os.path.getmtime(f):
            continue
        os.makedirs(os.path.dirname(destino) or '.', exist_ok=True)
        img = Image.open(f)
        img.load()
        hd = ampliar(r, img, a.escala)
        hd.save(destino)
        if a.normal:
            normal(hd, a.forca).save(destino[:-4] + '_n.png')
        print(f'{i + 1}/{len(arqs)} {destino} {img.size} -> {hd.size}', flush=True)


if __name__ == '__main__':
    main()
