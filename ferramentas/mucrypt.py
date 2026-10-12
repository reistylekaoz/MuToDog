"""Decifradores conhecidos dos arquivos do cliente de MU (estudo interno)."""

MAP_KEY = bytes([0xD1, 0x73, 0x52, 0xF6, 0xD2, 0x9A, 0xCB, 0x27,
                 0x3E, 0xAF, 0x59, 0x31, 0x37, 0xB3, 0xE7, 0xA2])

def map_decrypt(dados: bytes) -> bytes:
    """Cifra dos EncTerrain*.map/.att/.obj."""
    out = bytearray(len(dados))
    k = 0x5E
    for i, b in enumerate(dados):
        out[i] = ((b ^ MAP_KEY[i % 16]) - k) & 0xFF
        k = (b + 0x3D) & 0xFF
    return bytes(out)

BUX = bytes([0xFC, 0xCF, 0xAB])

def bux(dados: bytes) -> bytes:
    """XOR de 3 bytes usado em .att e tabelas antigas."""
    return bytes(b ^ BUX[i % 3] for i, b in enumerate(dados))
