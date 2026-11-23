"""
ANALIZAR AUDIO · genera Audio/Voces.lua a partir de los WAV y de Audio/voces.json

Uso (desde la carpeta del proyecto):
    python Audio/analizar_audio.py
    node build.js

Para cada voz de voces.json mide en su WAV:
  · Duracion   → segundos exactos del archivo
  · Segmentos  → tramos en los que se oye voz (para sincronizar acciones con frases)
  · Envolvente → volumen cada 0.05 s en una cifra 0-9 (la usa el Actor para mover
                 la boca al ritmo real de la voz)

Solo usa la librería estándar de Python (lee WAV PCM de 16 bits, mono o estéreo).
Si un audio está en MP3, conviértelo antes a WAV.
"""

import array
import json
import math
import os
import sys
import wave

CARPETA = os.path.dirname(os.path.abspath(__file__))
PASO = 0.05  # segundos por cifra de la envolvente
VENTANA_SEGMENTOS = 0.02
HUECO_MINIMO = 0.15  # silencio mínimo que separa dos frases


def leer_mono(ruta):
    with wave.open(ruta) as w:
        sr, ch, ancho, n = w.getframerate(), w.getnchannels(), w.getsampwidth(), w.getnframes()
        if ancho != 2:
            raise ValueError(f"{os.path.basename(ruta)}: solo se admiten WAV de 16 bits")
        datos = array.array("h", w.readframes(n))
    if sys.byteorder == "big":
        datos.byteswap()
    if ch == 1:
        return list(datos), sr
    return [sum(datos[i : i + ch]) / ch for i in range(0, len(datos), ch)], sr


def rms(muestras, sr, paso):
    tam = max(1, int(sr * paso))
    salida = []
    for i in range(0, len(muestras), tam):
        trozo = muestras[i : i + tam]
        salida.append(math.sqrt(sum(x * x for x in trozo) / len(trozo)))
    return salida


def segmentos(muestras, sr):
    r = rms(muestras, sr, VENTANA_SEGMENTOS)
    umbral = (max(r) or 1) * 0.06
    tramos, inicio, fin, hueco = [], None, 0, 0
    for i, v in enumerate(r):
        if v > umbral:
            if inicio is None:
                inicio = i
            fin, hueco = i, 0
        elif inicio is not None:
            hueco += 1
            if hueco * VENTANA_SEGMENTOS > HUECO_MINIMO:
                tramos.append((inicio, fin + 1))
                inicio = None
    if inicio is not None:
        tramos.append((inicio, fin + 1))
    return [
        (round(a * VENTANA_SEGMENTOS, 2), round(b * VENTANA_SEGMENTOS, 2))
        for a, b in tramos
        if (b - a) * VENTANA_SEGMENTOS > 0.06
    ]


def envolvente(muestras, sr):
    r = rms(muestras, sr, PASO)
    ordenados = sorted(r)
    referencia = ordenados[int(len(ordenados) * 0.95)] or 1
    cifras = []
    for v in r:
        x = min(1.0, v / referencia)
        x = math.sqrt(x)  # más natural: abre antes en sílabas suaves
        cifras.append(str(min(9, int(round(x * 9)))))
    return "".join(cifras)


def lua_texto(s):
    return '"' + s.replace("\\", "\\\\").replace('"', '\\"') + '"'


def main():
    with open(os.path.join(CARPETA, "voces.json"), encoding="utf-8") as f:
        voces = json.load(f)

    lineas = [
        "--[[",
        "\tVOCES · Datos de cada audio de la historia",
        "\tStudio: ReplicatedStorage > StoryTemplate > Modulos > Voces",
        "",
        "\tGENERADO por Audio/analizar_audio.py a partir de Audio/voces.json y los WAV.",
        "\tNo lo edites a mano: cambia voces.json (por ejemplo el Id) y vuelve a ejecutar",
        "\t  python Audio/analizar_audio.py  y  node build.js",
        "",
        "\tId         → id del audio subido a Roblox (\"rbxassetid://...\"). Vacío = sin sonido,",
        "\t             pero la escena mantiene los mismos tiempos (útil para montar el audio después).",
        "\tDuracion   → segundos del archivo.",
        "\tSegmentos  → tramos con voz { inicio, fin } en segundos desde el inicio del audio.",
        "\tEnvolvente → volumen cada Paso segundos (0-9) para mover la boca.",
        "]]",
        "",
        "return {",
        f"\tPaso = {PASO},",
    ]
    for v in voces:
        muestras, sr = leer_mono(os.path.join(CARPETA, v["Archivo"]))
        dur = round(len(muestras) / sr, 3)
        segs = segmentos(muestras, sr)
        env = envolvente(muestras, sr)
        ident = v.get("Id", "") or ""
        if ident.isdigit():
            ident = "rbxassetid://" + ident
        lineas += [
            f"\t{v['Nombre']} = {{",
            f"\t\tArchivo = {lua_texto(v['Archivo'])},",
            f"\t\tId = {lua_texto(ident)},",
            f"\t\tPersonaje = {lua_texto(v.get('Personaje', ''))},",
            f"\t\tTipo = {lua_texto(v.get('Tipo', 'Dialogo'))},",
            f"\t\tEscena = {v.get('Escena', 0)},",
            f"\t\tDuracion = {dur},",
            f"\t\tTexto = {lua_texto(v.get('Texto', ''))},",
            "\t\tSegmentos = { " + ", ".join(f"{{ {a}, {b} }}" for a, b in segs) + " },",
            f"\t\tEnvolvente = {lua_texto(env)},",
            "\t},",
        ]
        print(f"{v['Nombre']:10s} {dur:6.2f}s  voz: " + " ".join(f"[{a:.2f}-{b:.2f}]" for a, b in segs))
    lineas.append("}")
    destino = os.path.join(CARPETA, "Voces.lua")
    with open(destino, "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(lineas) + "\n")
    print(f"Generado {destino}")


if __name__ == "__main__":
    main()
