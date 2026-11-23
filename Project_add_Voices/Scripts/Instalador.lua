--[[
	INSTALADOR · Plantilla de historias para Roblox Studio
	Generado por build.js a partir de las carpetas del proyecto. No lo edites a mano:
	edita los .lua de origen y vuelve a ejecutar  node build.js

	USO (elige una):
	  A) Barra de comandos: abre un lugar nuevo (plantilla Baseplate),
	     menú Ver/View > Barra de comandos/Command Bar, pega TODO este
	     archivo y pulsa Enter.
	  B) Plugin local: copia este archivo a la carpeta de plugins de Studio
	     (Plugins > Carpeta de plugins). Aparecerá el botón "Instalar plantilla".

	Si la plantilla ya existe, la anterior se guarda en
	ServerStorage > StoryTemplate_Copias antes de reinstalar.
]]

local FUENTES = {} --@@FUENTES@@

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local StarterPlayer = game:GetService("StarterPlayer")
local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")
local ChangeHistoryService = game:GetService("ChangeHistoryService")

local function carpeta(padre, nombre)
	local f = padre:FindFirstChild(nombre)
	if not f then
		f = Instance.new("Folder")
		f.Name = nombre
		f.Parent = padre
	end
	return f
end

local function instalar()
	if RunService:IsRunning() then
		warn("[Plantilla] Detén la prueba (Stop) antes de instalar.")
		return
	end
	print("[Plantilla] Instalando...")

	-- Copia de seguridad de una instalación anterior
	local copias = nil
	local function guardarCopia(inst)
		if not inst then
			return
		end
		if not copias then
			copias = carpeta(carpeta(ServerStorage, "StoryTemplate_Copias"), os.date("%Y-%m-%d_%H-%M-%S"))
		end
		inst.Parent = copias
	end
	local scriptsJugador = StarterPlayer:FindFirstChildOfClass("StarterPlayerScripts")
	guardarCopia(ReplicatedStorage:FindFirstChild("StoryTemplate"))
	guardarCopia(scriptsJugador:FindFirstChild("StoryRunner"))
	guardarCopia(ServerScriptService:FindFirstChild("StoryServer"))

	-- Estructura
	local raiz = Instance.new("Folder")
	raiz.Name = "StoryTemplate"
	for _, nombre in ipairs({ "Personajes", "Entornos", "Objetos", "Audio", "Escenas", "Modulos", "Herramientas" }) do
		carpeta(raiz, nombre)
	end
	raiz.Parent = ReplicatedStorage

	local destinos = {
		StoryTemplate = raiz,
		StarterPlayerScripts = scriptsJugador,
		ServerScriptService = ServerScriptService,
	}
	for _, f in ipairs(FUENTES) do
		local partes = string.split(f.Ruta, "/")
		local padre = destinos[partes[1]]
		for i = 2, #partes do
			padre = carpeta(padre, partes[i])
		end
		local s = Instance.new(f.Clase)
		s.Name = f.Nombre
		s.Source = f.Fuente
		s.Parent = padre
	end

	-- Escenarios y objetos
	require(raiz.Herramientas.ConstructorEntornos).ConstruirTodos(raiz.Entornos)
	require(raiz.Herramientas.ConstructorObjetos).ConstruirTodos(raiz.Objetos)

	-- Sonidos de ejemplo (vacíos: pon tu SoundId en cada uno)
	for _, nombre in ipairs({ "Musica", "Narracion", "Efecto" }) do
		local s = Instance.new("Sound")
		s.Name = nombre
		s.SoundId = ""
		s.Volume = 0.5
		s.Parent = raiz.Audio
	end

	-- Personajes
	require(raiz.Modulos.FabricaPersonajes).ConstruirTodos(raiz.Personajes)
	if #raiz.Personajes:GetChildren() == 0 then
		warn("[Plantilla] Los personajes no se pudieron crear en modo edición; se crearán al pulsar Play.")
	end

	-- Ajustes del lugar para grabar con poco consumo
	pcall(function()
		Players.CharacterAutoLoads = false
	end)
	pcall(function()
		workspace.StreamingEnabled = false
	end)
	pcall(function()
		Lighting.Technology = Enum.Technology.Voxel
	end)
	Lighting.GlobalShadows = true
	for _, efecto in ipairs(Lighting:GetChildren()) do
		if efecto:IsA("SunRaysEffect") or efecto:IsA("DepthOfFieldEffect") or efecto:IsA("BlurEffect") then
			efecto.Enabled = false
		end
	end

	-- Objetos que no se usan: se apartan (no se borran)
	for _, nombre in ipairs({ "Baseplate", "SpawnLocation" }) do
		local x = workspace:FindFirstChild(nombre)
		if x then
			x.Parent = carpeta(ServerStorage, "StoryTemplate_Sobrantes")
		end
	end

	pcall(function()
		ChangeHistoryService:SetWaypoint("Instalar plantilla de historias")
	end)
	print("[Plantilla] Instalada. Pulsa Play (F5) para ver la escena de prueba.")
end

if plugin then
	local barra = plugin:CreateToolbar("Plantilla Historias")
	local boton = barra:CreateButton("Instalar plantilla", "Instala o reinstala la plantilla de historias", "")
	boton.ClickableWhenViewportHidden = true
	boton.Click:Connect(function()
		local ok, err = pcall(instalar)
		if not ok then
			warn("[Plantilla] Error al instalar: " .. tostring(err))
		end
	end)
else
	instalar()
end
