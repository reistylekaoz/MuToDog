#!/usr/bin/env python3
# Ponte so dos testes: liga a entrada e a saida padrao num socket Unix do
# OpenMU (servidor.sh ligar-teste). O cliente abre isso com MU_PONTE.
import os, socket, sys, threading

s = socket.socket(socket.AF_UNIX)
s.connect(sys.argv[1])


def entrada():
    while True:
        d = os.read(0, 65536)
        if not d:
            break
        s.sendall(d)
    s.close()


threading.Thread(target=entrada, daemon=True).start()
while True:
    d = s.recv(65536)
    if not d:
        break
    os.write(1, d)
