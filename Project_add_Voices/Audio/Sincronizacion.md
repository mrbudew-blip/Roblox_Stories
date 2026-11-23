# Sincronización de audio · Historia del Post-it

Tiempos medidos desde el **primer paso de la escena** (`t = 0`). Pasan `Config.RetrasoInicio` segundos (2 por defecto) después de pulsar Play. Con `Config.MostrarGuias = true` verás un reloj `t = …` arriba a la izquierda, y en la ventana Output aparece una línea `▶ postitN` cada vez que empieza una voz.

| Escena | Empieza en | Audio | Dura | Termina | Quién | Texto |
|---|---|---|---|---|---|---|
| 1 | **0.00 s** | `postit1.WAV` | 4.20 s | 4.20 s | Art (narrador, a cámara la 1.ª frase) | ¿Te interesa saber cómo se creó el primer Post-it? ¡Todo comenzó con un pegamento que parecía un fracaso! |
| 2 | **5.20 s** | `postit2.WAV` | 4.20 s | 9.40 s | Spencer | ¡He creado un pegamento especial! Se pega, pero puedes quitarlo sin problemas. |
| 2 | **9.75 s** | `postit3.WAV` | 1.30 s | 11.05 s | Art | ¿Y para qué sirve eso? |
| 3 | **12.45 s** | `postit4.WAV` | 4.04 s | 16.49 s | Art (narrador) | En 1974 tenía un problema: ¡mis marcapáginas siempre acababan en el suelo! |
| 3 | **16.60 s** | `postit5.WAV` | 1.07 s | 17.67 s | Art | ¡Otra vez no! |
| 4 | **17.95 s** | `postit6.WAV` | 2.88 s | 20.83 s | Art (narrador) | Entonces recordé aquel extraño pegamento y tuve una idea. |
| 4 | **21.10 s** | `postit7.WAV` | 2.11 s | 23.21 s | Art | ¡Espera! ¿Y si lo utilizo para crear un marcapáginas? |
| 5 | **23.75 s** | `postit8.WAV` | 2.88 s | 26.63 s | Art | ¡Funciona! ¡No se cae y puedo quitarlo sin romper nada! |
| 5 | **26.95 s** | `postit9.WAV` | 5.43 s | 32.38 s | Art (narrador) | Después empezamos a utilizarlos para dejar mensajes. ¡Habíamos encontrado algo mucho más útil que un simple marcapáginas! |
| 6 | **32.55 s** | `postit10.WAV` | 8.75 s | 41.30 s | Art (narrador) | En 1980 llegaron oficialmente a las tiendas como Post-it. ¡Y todo gracias a un pegamento que parecía inútil! |
| 6 | **41.80 s** | `postit11.WAV` | 1.65 s | 43.45 s | Spencer | ¡Al final sí que servía para algo! |
| — | **47.00 s** | — | — | — | — | Fin (título «¡DE FRACASO A INVENTO MILLONARIO!» desde 43.65 s) |

## Momentos clave sincronizados

| t (s) | Qué pasa | Coincide con |
|---|---|---|
| 0.00–2.05 | Primer plano de Art hablando a cámara (labios sincronizados) | «¿Te interesa saber…?» |
| 2.15–3.00 | Spencer pega el papel en el tablón de corcho | «¡Todo comenzó con un pegamento…» |
| 3.20–4.05 | El papel se despega y cae al suelo | «…que parecía un fracaso!» |
| 5.60 | Spencer enseña el papel, orgulloso | «¡He creado un pegamento especial!» |
| 6.75–7.85 | Spencer se lo entrega a Art | entre frases |
| 7.90–8.70 | Art lo pega en la pizarra | «Se pega…» |
| 8.85–9.25 | Art lo despega | «…puedes quitarlo sin problemas» |
| 11.15 | Spencer se encoge de hombros | tras «¿Y para qué sirve eso?» |
| 11.85–12.85 | Fundido a negro → sala de ensayo, rótulo «1974» | — |
| 14.00 | Art abre el cancionero | «tenía un problema» |
| 15.70–16.45 | El marcapáginas se escurre y cae | «…acababan en el suelo!» |
| 16.85 | Art se lleva la mano a la frente | «¡Otra vez no!» |
| 18.55–20.00 | Flashback en sepia: Spencer con su papel | «recordé aquel extraño pegamento» |
| 20.10 | Art levanta el dedo, 💡 | «y tuve una idea» |
| 21.75–22.75 | Art coge la muestra y la pega en la página | «¿Y si lo utilizo para crear un marcapáginas?» |
| 23.80 | Art señala el papel pegado | «¡Funciona!» |
| 25.10–26.30 | Spencer lo quita y lo vuelve a pegar | «¡No se cae y puedo quitarlo sin romper nada!» |
| 27.25–28.75 | Seis notas de colores aparecen en el tablón | «…para dejar mensajes» |
| 31.00 | Spencer celebra con el brazo en alto | «…que un simple marcapáginas!» |
| 32.35 | Fundido → rótulo «1980», cajas de producto | «En 1980» |
| 34.20 | Art presenta el bloc de notas amarillas | «…a las tiendas como Post-it» |
| 36.75–37.65 | Spencer se acerca; ambos miran el bloc | «¡Y todo gracias a un pegamento…» |
| 41.80 | Spencer a cámara (labios sincronizados) | «¡Al final sí que servía para algo!» |
| 43.65 | Título final | — |

## Dos formas de tener el sonido

1. **Dentro de Roblox (recomendado):** sube cada WAV en *Creator Hub > Creaciones > Audio* (si no acepta WAV, conviértelo a MP3 u OGG). Copia cada id en `Audio/voces.json` (campo `"Id"`) y ejecuta:
   ```
   python Audio/analizar_audio.py
   node build.js
   ```
   Reinstala la plantilla. Al grabar, el sonido ya sale sincronizado.
2. **Montándolo en el editor de vídeo:** graba sin sonido (deja los `Id` vacíos) y coloca cada WAV en el segundo de la tabla de arriba, contando desde el primer fotograma de la escena. Para tener una referencia exacta, pon `Config.CuentaAtras = true`: verás 3-2-1 y el `t = 0` es justo cuando desaparece el «1».

## Si cambias un audio

1. Sustituye el WAV (mismo nombre) y ejecuta `python Audio/analizar_audio.py`. Verás la nueva duración y los tramos de voz.
2. En `Scenes/Historia_PostIt.lua`, ajusta la tabla `VOZ` para que ningún audio empiece antes de que acabe el anterior. Todas las acciones están ancladas a su voz (`en("postit2", 1.5)`), así que se mueven solas.
3. `node build.js` y reinstala.
