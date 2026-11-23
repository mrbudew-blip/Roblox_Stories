// Genera Build/InstalarPlantilla.lua juntando todos los scripts del proyecto.
// Uso:  node build.js            → genera el instalador
//       node build.js --plugin   → además lo copia a la carpeta de plugins de Roblox Studio
const fs = require("fs");
const path = require("path");

const RAIZ = __dirname;

// [archivo de origen, ruta en Studio, nombre, clase]
const ENTRADAS = [
  ["Scripts/Config.lua", "StoryTemplate", "Config", "ModuleScript"],
  ["Scripts/Director.lua", "StoryTemplate/Modulos", "Director", "ModuleScript"],
  ["Scripts/Actor.lua", "StoryTemplate/Modulos", "Actor", "ModuleScript"],
  ["Animations/Animaciones.lua", "StoryTemplate/Modulos", "Animaciones", "ModuleScript"],
  ["Cameras/Camaras.lua", "StoryTemplate/Modulos", "Camaras", "ModuleScript"],
  ["Cameras/Guias.lua", "StoryTemplate/Modulos", "Guias", "ModuleScript"],
  ["Characters/DefPersonajes.lua", "StoryTemplate/Modulos", "DefPersonajes", "ModuleScript"],
  ["Characters/Atuendos.lua", "StoryTemplate/Modulos", "Atuendos", "ModuleScript"],
  ["Characters/FabricaPersonajes.lua", "StoryTemplate/Modulos", "FabricaPersonajes", "ModuleScript"],
  ["Enviroments/ConstructorEntornos.lua", "StoryTemplate/Herramientas", "ConstructorEntornos", "ModuleScript"],
  ["Props/ConstructorObjetos.lua", "StoryTemplate/Herramientas", "ConstructorObjetos", "ModuleScript"],
  ["Scenes/_PlantillaEscena.lua", "StoryTemplate/Escenas", "_PlantillaEscena", "ModuleScript"],
  ["Scenes/Prueba_Plantilla.lua", "StoryTemplate/Escenas", "Prueba_Plantilla", "ModuleScript"],
  ["Scenes/Prueba_Caras.lua", "StoryTemplate/Escenas", "Prueba_Caras", "ModuleScript"],
  ["Scripts/StoryRunner.client.lua", "StarterPlayerScripts", "StoryRunner", "LocalScript"],
  ["Scripts/StoryServer.server.lua", "ServerScriptService", "StoryServer", "Script"],
];

const NIVEL = "=======";
const leer = (f) => fs.readFileSync(path.join(RAIZ, f), "utf8").replace(/\r\n/g, "\n");

let tabla = "{\n";
for (const [archivo, ruta, nombre, clase] of ENTRADAS) {
  const fuente = leer(archivo);
  if (fuente.includes(`]${NIVEL}]`)) throw new Error(`${archivo} contiene ]${NIVEL}]`);
  tabla += `\t{ Ruta = "${ruta}", Nombre = "${nombre}", Clase = "${clase}", Fuente = [${NIVEL}[\n${fuente}]${NIVEL}] },\n`;
}
tabla += "}";

const plantilla = leer("Scripts/Instalador.lua");
const MARCA = "{} --@@FUENTES@@";
if (!plantilla.includes(MARCA)) throw new Error("No encuentro la marca @@FUENTES@@ en Scripts/Instalador.lua");
const salida = plantilla.replace(MARCA, () => tabla);

fs.mkdirSync(path.join(RAIZ, "Build"), { recursive: true });
const destino = path.join(RAIZ, "Build", "InstalarPlantilla.lua");
fs.writeFileSync(destino, salida);
console.log(`Generado ${path.relative(RAIZ, destino)} (${(salida.length / 1024).toFixed(1)} KB, ${ENTRADAS.length} scripts)`);

if (process.argv.includes("--plugin")) {
  const base = process.env.LOCALAPPDATA;
  if (!base) throw new Error("No encuentro LOCALAPPDATA (¿no es Windows?)");
  const plugins = path.join(base, "Roblox", "Plugins");
  fs.mkdirSync(plugins, { recursive: true });
  fs.copyFileSync(destino, path.join(plugins, "InstalarPlantillaHistorias.lua"));
  console.log(`Copiado a ${plugins} — reinicia Roblox Studio para ver el botón "Instalar plantilla".`);
}
