# Plantilla de historias · Roblox Studio

> **Este proyecto (`Project_add_Voices`) contiene la historia «El origen del Post-it»**, sincronizada con los 11 audios de `Audio/`. Al instalar y pulsar Play se reproduce `Historia_PostIt` (~47 s). Ver [Guion.md](Guion.md), la tabla de tiempos en [Audio/Sincronizacion.md](Audio/Sincronizacion.md) y la sección **10. Historia del Post-it** al final de este documento.

Proyecto base para producir vídeos cortos verticales (9:16) de historias narradas. Los personajes, escenarios, animaciones y cámaras ya están hechos: cada vídeo nuevo es **un único archivo de escena** que dice quién sale, dónde y qué hace.

> Todavía no contiene ninguna historia. Solo trae la escena técnica `Prueba_Plantilla`, que recorre todos los recursos para comprobar que funcionan.

---

## 1. Instalación (una sola vez por lugar)

1. Abre Roblox Studio y crea un lugar nuevo con la plantilla **Baseplate**.
2. Instala la plantilla de una de estas dos formas:
   - **Barra de comandos:** menú *Ver/View* > *Barra de comandos/Command Bar*. Abre `Build/InstalarPlantilla.lua`, copia **todo** su contenido, pégalo en la barra y pulsa **Enter**.
   - **Plugin:** ejecuta `node build.js --plugin` (o copia `Build/InstalarPlantilla.lua` a la carpeta de plugins de Studio) y reinicia Studio. Aparece la pestaña *Plugins* > **Instalar plantilla**.
3. En la ventana **Output** debe salir `[Plantilla] Instalada.`
4. Pulsa **Play (F5)**. Se reproduce `Prueba_Plantilla` (~1 minuto).
5. Guarda el lugar (*Archivo > Guardar en Roblox* o como `.rbxl`). Ese archivo es tu plantilla: duplícalo para cada serie de vídeos.

El instalador también:
- desactiva la aparición del avatar del jugador (`Players.CharacterAutoLoads = false`);
- pone la iluminación en `Voxel` y desactiva SunRays, DepthOfField y Blur;
- desactiva `StreamingEnabled`;
- aparta el `Baseplate` y el `SpawnLocation` a `ServerStorage > StoryTemplate_Sobrantes` (no los borra);
- si ya había una plantilla, guarda la anterior en `ServerStorage > StoryTemplate_Copias`.

---

## 2. Dónde está cada cosa

### En Roblox Studio

```
ReplicatedStorage
└─ StoryTemplate
   ├─ Config                 ← qué escena se reproduce y ajustes de grabación
   ├─ Escenas                ← UNA escena = UN ModuleScript (aquí trabajas)
   │   ├─ _PlantillaEscena   ← copia esta para empezar una escena
   │   ├─ Prueba_Plantilla   ← prueba técnica de todo
   │   └─ Prueba_Caras       ← prueba de caras: parpadeo y boca
   ├─ Personajes             ← Protagonista, Secundario1, Secundario2 (Models R15)
   ├─ Entornos               ← Calle, Habitacion, Exterior, Neutro (Models)
   │   └─ <Entorno>
   │       ├─ Geometria      ← las piezas del escenario
   │       └─ Marcas         ← posiciones de personajes, objetos y cámaras
   ├─ Objetos                ← Caja, Sobre, Telefono, Libro, Bolsa
   ├─ Audio                  ← Musica, Narracion, Efecto (Sounds vacíos)
   ├─ Modulos                ← motor: Director, Actor, Animaciones, Camaras, Guias,
   │                            DefPersonajes, Atuendos, FabricaPersonajes
   └─ Herramientas           ← ConstructorEntornos, ConstructorObjetos (solo para regenerar)
StarterPlayer > StarterPlayerScripts > StoryRunner   ← arranca la escena al pulsar Play
ServerScriptService > StoryServer                    ← crea personajes que falten
```

### En este repositorio

| Carpeta | Contenido | Módulo en Studio |
|---|---|---|
| `Characters/` | `DefPersonajes.lua`, `Atuendos.lua`, `FabricaPersonajes.lua` | Modulos |
| `Enviroments/` | `ConstructorEntornos.lua` | Herramientas |
| `Props/` | `ConstructorObjetos.lua` | Herramientas |
| `Animations/` | `Animaciones.lua` | Modulos |
| `Cameras/` | `Camaras.lua`, `Guias.lua` | Modulos |
| `Scripts/` | `Config`, `Director`, `Actor`, `StoryRunner`, `StoryServer`, plantilla del instalador | varios |
| `Scenes/` | `_PlantillaEscena.lua`, `Prueba_Plantilla.lua`, `Prueba_Caras.lua` | Escenas |
| `Build/` | `InstalarPlantilla.lua` (generado, **no editar**) | — |
| `Videos/` | grabaciones exportadas (no se suben a git) | — |

Si cambias algún `.lua` del repositorio, ejecuta `node build.js` para regenerar el instalador. Si cambias algo directamente en Studio, el cambio vive en tu archivo `.rbxl`.

---

## 3. Catálogo de recursos

Usa estos nombres exactos en las escenas (y para pedirme qué reutilizar).

### Personajes (`StoryTemplate > Personajes`)
| Nombre | Complexión | Personalidad | Atuendo |
|---|---|---|---|
| `Protagonista` | flaco, estatura media, piel clara | curioso, tímido y algo nervioso (ojos grandes azules, cejas preocupadas, pecas) | sudadera azul con capucha, vaqueros, zapatillas blancas, pelo castaño despeinado |
| `Secundario1` | alto y fuerte, piel negra | seguro, tranquilo y protector (ojos marrones con párpados entornados, media sonrisa) | camiseta blanca, pantalón gris oscuro, cinturón, botas marrones, pelo rapado y barba corta |
| `Secundario2` | pequeño y gordito, piel amarilla clásica | alegre, glotón y gracioso (ojos verdes sonrientes, boca abierta, mejillas rosadas) | camiseta de rayas azul y blanca, pantalón caqui, zapatillas rojas, gorra roja hacia atrás |

Las prendas son básicas a propósito para que sirvan en casi cualquier contexto. Todo (caras incluidas) está hecho con colores planos y unas pocas piezas: no usa ids del catálogo ni texturas.

**Caras vivas:** los personajes llevan la cabeza clásica de bloques (se sustituye la cabeza dinámica de Roblox, que traía su propia cara animada). Los ojos son detallados (blanco, iris de color, pupila, brillos, pestañas y párpados) y **parpadean solos** cada 2-5 segundos. Al usar la acción `Hablar` la boca **se abre y se cierra**; con `SoloBoca = true` habla sin mover los brazos.

### Atuendos (`Modulos > Atuendos`)
Piezas reutilizables para vestir personajes en `DefPersonajes`:

| Tipo | Opciones |
|---|---|
| Caras predefinidas | `Timido`, `Seguro`, `Alegre`, `Neutral`, `Serio` |
| Ojos (caras a medida) | `{ Iris = Color3, Parpado = 0..0.6, ParpadoInferior = 0..0.4, Tamano = 1 }` — `Parpado` alto = mirada entornada; `ParpadoInferior` = ojos sonrientes |
| Cejas / Boca | `Normales`, `Gruesas`, `Preocupadas`, `Arqueadas`, `Ninguna` / `Sonrisa`, `SonrisaPequena`, `SonrisaAbierta`, `MediaSonrisa`, `Seria`, `O` (+ `Mejillas`, `Pecas`) |
| Pelo | `Corto`, `Despeinado`, `Rapado`, `Ninguno` |
| Prenda superior | `Camiseta`, `MangaLarga`, `Sudadera`, `Polo`, `Tirantes`, `Chaqueta`, `CamisetaRayas` |
| Prenda inferior | `Pantalon`, `Corto` |
| Accesorios | `Gorra`, `GorraAtras`, `Gafas`, `Barba`, `Cinturon`, `Barriga`, `Mochila` |

### Entornos (`StoryTemplate > Entornos`)
| Nombre | Descripción |
|---|---|
| `Calle` | acera con edificios detrás, carretera delante, farolas, árbol y banco |
| `Habitacion` | salón abierto por delante: mesa, silla, sofá, ventana, puerta, alfombra |
| `Exterior` | campo de césped con camino, árboles, rocas, banco y colinas |
| `Neutro` | fondo liso lila claro, para conversaciones |

Marcas de **todos** los entornos (mismos nombres en todos):

| Marca | Uso |
|---|---|
| `Pos_A`, `Pos_B`, `Pos_C`, `Pos_D` | dónde se colocan los personajes (la cara **FRENTE** indica hacia dónde miran) |
| `Entrada_Izq`, `Entrada_Der` | entradas y salidas de plano |
| `Obj_1`, `Obj_2` | sitios para objetos (`Obj_1` está sobre mesa/banco cuando lo hay) |
| `Cam_General`, `Cam_Izquierda`, `Cam_Derecha`, `Cam_Alta` | puntos de cámara fijos |
| `Audiencia` | lado del "público": orienta los planos automáticos |

### Animaciones (`Modulos > Animaciones`)
| Tipo | Nombres | Cómo se usan |
|---|---|---|
| Base (bucle) | `Quieto`, `Caminar`, `Correr` | automáticas al estar quieto / `Caminar` / `Correr` |
| Gestos | `Hablar`, `Senalar`, `Sorpresa`, `Entregar`, `Recibir`, `Agacharse`, `Sostener`, `Asentir`, `Negar`, `Pensar` | acción `Gesto` (o sus atajos) |
| Clips | `Saludar`, `Reir`, `Celebrar` | acción `Animacion` |
| Mirar | — | acción `Mirar` (cuerpo entero o solo cabeza) |

### Planos de cámara (`Modulos > Camaras`)
| Plano | Qué muestra |
|---|---|
| `General` | todos los personajes visibles, cuerpo entero |
| `Medio` | uno o varios personajes, de rodilla/cintura para arriba |
| `PrimerPlano` | cara y hombros de un personaje |
| `Personaje` | cámara enfocada en un personaje (con `Seguir = true` lo acompaña) |
| `DosPersonajes` | dos personajes de lado, para conversaciones |
| `Fija` | uno de los puntos `Cam_...` del entorno |

### Objetos (`StoryTemplate > Objetos`)
`Caja`, `Sobre`, `Telefono`, `Libro`, `Bolsa`.

### Audio (`StoryTemplate > Audio`)
`Musica`, `Narracion`, `Efecto` — vienen **vacíos**. Pon en su `SoundId` el id de un audio que tengas permiso para usar (por ejemplo, uno subido por ti). También puedes usar ids directamente en la escena (`Sonido = 1234567890`).

---

## 4. Cómo funciona una escena

Una escena es un ModuleScript en `StoryTemplate > Escenas` que devuelve una tabla:

```lua
return {
	Entorno = "Neutro",                          -- escenario inicial

	Reparto = {                                  -- ROL = MODELO
		Protagonista = "Protagonista",
		Secundario1 = "Secundario1",
	},

	Posiciones = {                               -- dónde empieza cada rol
		Protagonista = "Pos_A",
		Secundario1 = { Marca = "Pos_B", MirarA = "Protagonista" },
	},

	Objetos = {                                  -- objetos al empezar
		Caja = "Obj_1",
		Carta = { Modelo = "Sobre", EnManoDe = "Protagonista" },
	},

	Musica = { Sonido = "Musica", Volumen = 0.3 },

	Camara = { Plano = "DosPersonajes" },        -- plano inicial

	Pasos = {                                    -- lo que ocurre, en orden
		{ Accion = "Hablar", Actor = "Protagonista", Duracion = 2 },
		{ Accion = "Entregar", De = "Protagonista", A = "Secundario1", Objeto = "Carta" },
		{ Accion = "Camara", Plano = "PrimerPlano", Actor = "Secundario1" },
		{ Accion = "Sorpresa", Actor = "Secundario1" },
	},
}
```

**Qué se cambia y dónde:**

| Quiero cambiar… | Dónde |
|---|---|
| el protagonista / secundarios | `Reparto` (rol → modelo) |
| el escenario | `Entorno`, o el paso `Entorno` a mitad de escena |
| los objetos | `Objetos` y los pasos `Objeto`, `Recoger`, `Entregar`, `Soltar` |
| las posiciones | `Posiciones`, los pasos `Colocar`/`Caminar`, o mover las marcas en Studio |
| las animaciones | los pasos `Gesto`, `Hablar`, `Senalar`, `Sorpresa`, `Animacion`, `Mirar` |
| la cámara | `Camara` (inicial) y los pasos `Camara` |
| el audio | `Musica` y los pasos `Sonido`, `Musica`, `Hablar` con `Sonido` |

### Regla de tiempo

- Cada paso **espera a que termine** su acción antes del siguiente (caminar hasta llegar, un gesto, un sonido…).
- `Paralelo = true` → el siguiente paso empieza a la vez.
- `Pausa = 1.5` → espera esos segundos extra después del paso.
- Los cambios instantáneos (`Camara`, `Colocar`, `Objeto`, `Musica`, `Entorno`, `Ocultar`) no esperan: si quieres ver una transición de cámara entera, añade `Pausa`.

### Destinos

Donde un paso pide un lugar (`En`, `Hasta`, `Desde`, `A`, `MirarA`) puedes poner:
- una **marca**: `"Pos_A"`, `"Entrada_Der"`, `"Obj_1"`…
- un **rol** visible: `"Secundario1"` (al caminar se queda a `Distancia`, 3 studs por defecto);
- un **objeto** en escena: `"Caja"` (se queda a 1.6 studs);
- `"Camara"` (solo para mirar): se gira hacia la cámara;
- un `Vector3.new(x, y, z)`.

---

## 5. Referencia de acciones

| Acción | Campos | Notas |
|---|---|---|
| `Esperar` | `Tiempo` | también `{ "Esperar", 2 }` |
| `Colocar` | `Actor`, `En`, `MirarA`? | aparece/teletransporta. Mira hacia donde apunta la marca |
| `Ocultar` | `Actor` | lo quita de escena (vuelve con `Colocar`) |
| `Caminar` | `Actor`, `Hasta`, `Desde`?, `MirarA`?, `Velocidad`?, `Distancia`? | con `Desde` el actor aparece ahí antes de andar |
| `Correr` | igual que `Caminar` | |
| `Mirar` | `Actor`, `A`, `SoloCabeza`?, `Tiempo`? | `SoloCabeza = true` y sin `A` → cabeza al frente |
| `Hablar` | `Actor`, `Duracion`?, `Sonido`?, `Volumen`?, `SoloBoca`? | mueve la boca y gesticula; con `SoloBoca = true` solo la boca. Con `Sonido` dura lo que dure el audio |
| `Senalar` | `Actor`, `A`?, `Duracion`?, `Mantener`? | gira hacia `A` y señala |
| `Sorpresa` | `Actor`, `Duracion`?, `Mantener`? | |
| `Gesto` | `Actor`, `Gesto`, `Duracion`?, `Mantener`? | cualquier gesto de `Animaciones.Gestos` |
| `Animacion` | `Actor`, `Clip` | cualquier clip de `Animaciones.Clips` |
| `Entregar` | `De`, `A`, `Objeto`? | se miran, uno extiende el brazo, el objeto cambia de mano. Colócalos a ~3 studs |
| `Recoger` | `Actor`, `Objeto` | se agacha y lo coge (acércalo antes con `Caminar Hasta = "Objeto"`) |
| `Soltar` | `Actor`, `En`? | lo deja en una marca; sin `En` el objeto desaparece |
| `Objeto` | `Objeto`, `En` / `EnManoDe` / `Visible = false` | coloca, da u oculta un objeto sin animación |
| `Camara` | `Plano` + opciones (abajo) | |
| `Sonido` | `Sonido`, `Volumen`? | espera a que acabe (usa `Paralelo = true` para narración de fondo) |
| `Musica` | `Sonido`, `Volumen`?, `Parar`? | en bucle; sustituye a la anterior |
| `Entorno` | `Nombre` | cambia de escenario; los personajes siguen donde estaban, recolócalos |
| `Ejecutar` | `Funcion = function(ctx) ... end` | vía de escape para casos especiales |
| `Voz` | `Voz`, `Actor`?, `Labios`?, `LabiosHasta`?, `Gestos`?, `Volumen`? | reproduce un audio de `Modulos > Voces` y mueve la boca **al ritmo real de la voz**. Por defecto: labios en diálogos, no en narración |
| `EsperarHasta` | `Tiempo` | espera hasta ese segundo de la escena |
| `Expresion` | `Actor`, `Expresion`, `Duracion`? | `Sorpresa`, `Frustracion`, `Idea`, `Feliz`, `Curiosidad`, `Duda`, `Orgullo`, `Pensativo` o `Ninguna` |
| `Postura` | `Actor`, `Postura` | gesto que se mantiene debajo de los demás (p. ej. `Mostrar` para sostener algo en alto); `Ninguna` lo quita |
| `Sentar` / `Levantar` | `Actor`, `En` (marca `Silla_…`) | sienta al personaje con las piernas dobladas; `Levantar` (o `Colocar`) lo pone de pie |
| `Pegar` | `Actor`, `Objeto`?, `En`, `Desplazamiento`? | pega lo que lleva en una pared (`Pared_…`, `Nota_…`) o encima de un objeto |
| `Caer` | `Objeto`, `Hasta`?, `Tiempo`? | el objeto cae balanceándose como un papel |
| `Aparecer` | `Objeto`, `En` | el objeto aparece con un rebote |
| `Texto` | `Texto`, `Estilo`, `Duracion`?, `Posicion`? | `Titulo`, `Rotulo` (nota amarilla para fechas), `Icono` (emoji) o `Subtitulo`, siempre dentro del 9:16 |
| `Fundido` | `Color`? (`"Blanco"`), `Entrada`?, `Mantener`?, `Salida`? | fundido a negro/blanco; cambia de entorno mientras la pantalla está cubierta |
| `Filtro` | `Filtro` | `Recuerdo` (sepia, para flashbacks), `Calido` o `Ninguno` |

**Línea de tiempo:** cualquier paso puede llevar `T = segundos`. Se ejecuta exactamente en ese segundo de la escena y no bloquea a los siguientes, así que los tiempos no se desvían. Es la forma recomendada para sincronizar con audio (ver `Escenas > Historia_PostIt`).

**Entornos con memoria:** al cambiar de entorno, el anterior recuerda quién y qué había. Si vuelves, todo aparece donde estaba (ideal para flashbacks). En un entorno nuevo no hay nadie hasta que colocas a los personajes.

**Recoger / Soltar / Pegar** eligen solos el gesto según la altura: agacharse (suelo), alcanzar (mesa) o brazo arriba (pared).

Opciones de **`Camara`**: `Actor` o `Actores = {…}`, `Encuadre = "Cuerpo" | "Medio" | "Cara"`, `Angulo` (grados, + = cámara más a la derecha), `Inclinacion` (grados, + = picado), `Holgura` (1.2 = más aire), `Seguir = true`, `Transicion` (segundos), `Acercar` (studs) + `TiempoAcercar` (zoom lento), `FOV`, `Marca` (para `Fija`).

---

## 6. Añadir y modificar recursos

### Nueva escena
1. En `StoryTemplate > Escenas`, selecciona `_PlantillaEscena` y pulsa **Ctrl+D**. Renómbrala (p. ej. `Historia01_Escena1`).
2. Edita `Entorno`, `Reparto`, `Posiciones`, `Objetos` y `Pasos`.
3. En `StoryTemplate > Config` pon `Config.EscenaActiva = "Historia01_Escena1"`.
4. **Play**. Si algo falla, el Output dice qué paso y por qué (la escena continúa con el siguiente).

Consejo: una escena por bloque de narración (10–30 s). Es más fácil de repetir y montar.

### Mover posiciones o cámaras de un entorno
1. Arrastra el entorno (p. ej. `Calle`) de `StoryTemplate > Entornos` a `Workspace` para verlo.
2. Mueve/gira las partes de su carpeta `Marcas`. Las marcas de personaje tienen escrito **FRENTE** en el lado hacia el que mirará el personaje. Las de cámara (`Cam_…`) miran con su cara frontal (usa la herramienta *Rotate*).
3. Puedes añadir marcas nuevas: duplica una (Ctrl+D) y renómbrala (p. ej. `Pos_E`, `Cam_Ventana`).
4. Devuelve el entorno a `StoryTemplate > Entornos`.

### Nuevo entorno
- Rápido: duplica uno existente en `StoryTemplate > Entornos`, renómbralo y cambia su `Geometria`. Mantén la carpeta `Marcas` con los mismos nombres para que las escenas sirvan tal cual.
- Iluminación: atributos del Model `Hora`, `Brillo`, `Ambiente`, `AmbienteExterior`.
- Usa Parts con material *SmoothPlastic*, sin texturas, `CanCollide` desactivado y pocas piezas.

### Nuevo personaje
- **Por código (recomendado):** copia una entrada en `Modulos > DefPersonajes`, cámbiale el nombre y elige piel, `Cuerpo` (escalas), `Cara`, `Pelo`, `Superior`, `Inferior`, `Calzado` y `Accesorios` (ver catálogo de Atuendos). Pulsa Play: `StoryServer` crea automáticamente los que falten (solo durante esa prueba). Para guardarlos en el lugar (o reconstruir los existentes tras cambiar su aspecto), ejecuta en la barra de comandos:
  ```lua
  local m = game.ReplicatedStorage.StoryTemplate.Modulos:Clone(); require(m.FabricaPersonajes).ConstruirTodos(game.ReplicatedStorage.StoryTemplate.Personajes); m:Destroy()
  ```
  (Se clona la carpeta para que Studio no use versiones antiguas de los módulos en caché. Reconstruye **todos** los personajes de `DefPersonajes`.)
- **Variantes de ropa:** para un pijama, uniforme, etc., copia la entrada con otro nombre (`Protagonista_Pijama`) y cambia solo la ropa. En la escena: `Reparto = { Protagonista = "Protagonista_Pijama" }`.
- **Nuevas piezas de atuendo:** en `Modulos > Atuendos`, añade una función a `PIEZAS` (Parts soldadas a una parte del cuerpo) o una entrada a `Caras`, `Superiores` o `Inferiores`.
- **A mano:** cualquier rig **R15** con `Humanoid` y `HumanoidRootPart` sirve (p. ej. *Avatar > Rig Builder*). Ponlo en `StoryTemplate > Personajes` con el nombre que quieras.

### Nuevo objeto
Pon cualquier `Model` en `StoryTemplate > Objetos`. Si tiene `PrimaryPart`, se agarra por ella. El atributo `OffsetAgarre` (CFrame) ajusta cómo queda en la mano.

### Nuevo gesto
En `Modulos > Animaciones`, copia un gesto de `Gestos` y cambia los ángulos (la guía de ejes está al principio del archivo). Se usa con `{ Accion = "Gesto", Actor = "…", Gesto = "MiGesto" }`.

### Nueva animación subida
Sube tu animación (Animation Editor > Publish) y añade en `Animaciones.Clips`: `MiClip = "rbxassetid://ID"`. Se usa con la acción `Animacion`.

### Nuevo plano de cámara
Añade una entrada en `Camaras.Planos`, por ejemplo:
`Contrapicado = { Tipo = "Individual", Encuadre = "Medio", Inclinacion = -12, Angulo = 0 }`
(`Tipo`: `Grupo`, `Individual`, `Pareja` o `Marca`).

### Regenerar escenarios u objetos de fábrica
```lua
local h = game.ReplicatedStorage.StoryTemplate.Herramientas; require(h.ConstructorEntornos:Clone()).Calle(game.ReplicatedStorage.StoryTemplate.Entornos)
```
Cambia `Calle` por `Habitacion`, `Exterior`, `Neutro` o `ConstruirTodos`. **Ojo:** sustituye el entorno y pierdes los cambios que hayas hecho a mano en él.

---

## 7. Grabar en vertical 9:16

1. En `Config`: `MostrarGuias = false` (quita el recuadro verde). Deja `BandasNegras = true`.
2. Opción recomendada — **emulador de dispositivo**: pestaña *Test* > *Device* > *Manage Devices* > añade uno de 1080 × 1920 (vertical) y selecciónalo. La vista de Play será exactamente 9:16 y no habrá bandas.
3. Opción alternativa: graba la ventana normal; la imagen útil es la franja central entre las bandas negras. Recórtala a 9:16 en el editor de vídeo.
4. `Config.RetrasoInicio` (2 s por defecto) te da margen para empezar a grabar tras pulsar Play.
5. Graba con la grabadora de Roblox (menú de Roblox > Record) o con OBS / Xbox Game Bar (Win+Alt+R). Guarda los vídeos en `Videos/`.

La composición es idéntica con cualquier tamaño de ventana: la cámara se calcula para el área 9:16 y el campo de visión se ajusta solo. La zona segura deja libre el 14 % inferior para subtítulos y los márgenes laterales.

---

## 8. Optimización (qué hace la plantilla y qué evitar)

- **Sin física:** la raíz de cada personaje está anclada y todo tiene `CanCollide`, `CanTouch` y `CanQuery` desactivados. El `Humanoid` no evalúa estados.
- **Movimiento con Tweens** del motor (no bucles de script). Una sola conexión por fotograma: la cámara.
- **Todo local:** el Director corre en el cliente; no hay red ni replicación durante la escena.
- **Un solo entorno cargado** a la vez; los demás esperan en `ReplicatedStorage` sin dibujarse.
- **Sin luces dinámicas ni texturas:** solo el sol, iluminación `Voxel`, Parts *SmoothPlastic*. Las farolas y la lámpara usan Neon, sin luz real.
- **Gestos procedurales:** no hay que subir animaciones y no ocupan memoria.
- Evita: mallas importadas pesadas, `PointLight`/`SpotLight`, partículas, `Texture`/`Decal` grandes, `Terrain` extenso, scripts dentro de los modelos y objetos que no salgan en plano.

---

## 9. Solución de problemas

| Síntoma | Causa / solución |
|---|---|
| `Paso N llega X s tarde` | Un paso con `T` se ejecutó más tarde de lo previsto, normalmente porque un paso sin `T` lo bloqueó antes. En las escenas con línea de tiempo pon `T` en todos los pasos. |
| La voz no suena | Su `Id` está vacío en `Audio/voces.json`. La escena mantiene los tiempos igualmente. |
| `No existe la escena 'X'` | El nombre en `Config.EscenaActiva` no coincide con el ModuleScript de `Escenas`. |
| `El actor 'X' todavía no está en escena` | Falta un `Colocar` (o `Posiciones`, o `Caminar` con `Desde`) antes. |
| `No encuentro 'X'` | Marca, actor u objeto mal escrito (distingue mayúsculas). |
| Los tres personajes tienen la misma altura/anchura | Tu versión de Studio limita las escalas del cuerpo; la personalidad se mantiene por cara, ropa, `Barriga` y colores. |
| Personajes sin crear tras instalar | Studio a veces no permite crearlos en modo edición; se crean solos al pulsar Play. Para guardarlos usa el comando de "Nuevo personaje". |
| No suena el audio | El `Sound` de `Audio` tiene `SoundId` vacío o el audio no tiene permisos para tu experiencia. |
| Los pies "patinan" | Ajusta `Config.VelocidadCaminar/Correr` o `VelocidadReferencia` en `Animaciones.Base`. |
| Los cambios en un módulo no se aplican desde la barra de comandos | Studio cachea `require`; usa `require(modulo:Clone())`. En Play siempre se usa la versión actual. |
| Se ve la barra superior de Roblox | Algunas versiones no permiten ocultarla; usa el emulador de dispositivo o recórtala al editar. |

---

## 10. Historia del Post-it (`Historia_PostIt`)

Adaptación de [Guion.md](Guion.md) en 6 escenas, ~47 s, formato 9:16.

### Personajes
| Rol / modelo | Aspecto | Personalidad |
|---|---|---|
| `Spencer` | delgado, bata blanca de laboratorio con bolsillo y bolígrafos, camisa azul claro, corbata granate, gafas de pasta negras, pelo castaño peinado de lado | químico entusiasta y orgulloso de su «pegamento raro» (cara `Entusiasta`) |
| `Art` | algo más alto, chaleco mostaza sobre camisa crema, pantalón de pana marrón, entradas canosas y bigote | ingeniero curioso y práctico, canta en el coro; es el narrador (cara `Curioso`) |

Están en `Modulos > DefPersonajes` junto a los tres personajes de la plantilla.

### Escenarios
| Entorno | Contenido | Marcas propias |
|---|---|---|
| `Laboratorio` | suelo de baldosas, zócalo verde menta, cartel «LABORATORIO DE ADHESIVOS», tablón de corcho con hojas clavadas, pizarra con fórmulas, mesa central de encimera negra con folios y probetas, banco de química con microscopio, matraces y frascos, armario de vidrio, ventana, reloj, taburetes y papelera con intentos fallidos | `Pos_TrasMesa`, `Pared_1` (corcho), `Pared_2` (pizarra), `Nota_1`…`Nota_6`, `Obj_1`…`Obj_4`, `Suelo_1`, `Cam_Tablon`, `Cam_Mesa` |
| `SalaEnsayo` | tarima, friso de madera, vidrieras de colores, tablero de himnos, cartel «ENSAYO DEL CORO», gradas con sillas, atriles, piano vertical con banqueta, planta, y en primer término la mesa y la silla de Art con cancioneros, lámpara y papeles sueltos | `Silla_1`, `Obj_Libro`, `Obj_Papeles`, `Obj_Nota`, `Suelo_Libro`, `Cam_Mesa` |

### Objetos nuevos
`Papel`, `PapelAdhesivo` (la muestra de Spencer), `NotaAmarilla` (admite `Color` y `Texto` escrito a mano), `Marcapaginas`, `BlocNotas`, `Cancionero`, `CancioneroAbierto`, `Pegamento` (bote con pincel), `CajaNotas`.

### Escenas del guion
| # | Escenario | Qué se ve |
|---|---|---|
| 1 | Laboratorio | Art abre a cámara; Spencer pega su papel en el corcho y se despega; Art observa |
| 2 | Laboratorio | Spencer presume y le da el papel a Art; Art lo pega y despega en la pizarra; «¿Y para qué sirve eso?»; Spencer se encoge de hombros |
| 3 | Sala de ensayo (1974) | Art sentado abre el cancionero, pone un marcapáginas y se cae al suelo; «¡Otra vez no!» |
| 4 | Sala + recuerdo | flashback en sepia de Spencer; 💡; Art pega la muestra en la página como marcapáginas |
| 5 | Laboratorio | «¡Funciona!»; Spencer lo quita y lo vuelve a pegar; el tablón se llena de notas de colores |
| 6 | Laboratorio (1980) | cajas de producto; Art presenta el bloc; Spencer se acerca; «¡Al final sí que servía para algo!»; título final |

### Audio
- `Audio/postit1…11.WAV`: los originales.
- `Audio/voces.json`: qué dice cada audio, quién y en qué escena, y su `Id` de Roblox (vacío hasta que los subas).
- `Audio/analizar_audio.py`: mide duración, tramos de voz y la curva de volumen para los labios, y genera `Audio/Voces.lua` (= `Modulos > Voces`).
- `Audio/Sincronizacion.md`: segundo exacto en que empieza cada audio y cada acción importante.

Para cambiar un audio o añadir los `Id`: edita `voces.json` o sustituye el WAV, luego ejecuta `python Audio/analizar_audio.py` y `node build.js`, y reinstala.
