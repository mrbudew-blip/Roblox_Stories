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

local FUENTES = {
	{ Ruta = "StoryTemplate", Nombre = "Config", Clase = "ModuleScript", Fuente = [=======[
--[[
	CONFIG · Ajustes generales de la plantilla
	Studio: ReplicatedStorage > StoryTemplate > Config

	Es el único archivo que hace falta tocar para elegir qué escena se
	reproduce al pulsar Play y cómo se comporta la grabación.
]]

local Config = {}

-- Escena que se reproduce al pulsar Play.
-- Es el nombre de un ModuleScript dentro de StoryTemplate > Escenas.
Config.EscenaActiva = "Historia_PostIt"

-- FORMATO VERTICAL ---------------------------------------------------------
Config.Aspecto = 9 / 16 -- proporción del vídeo (ancho / alto)
Config.BandasNegras = true -- tapa en negro todo lo que queda fuera del 9:16
Config.MostrarGuias = false -- dibuja la zona segura y el reloj t=. Ponlo en true para revisar el encuadre
Config.CampoVision = 40 -- campo de visión vertical de la cámara (grados)
Config.TransicionCamara = 0 -- transición por defecto entre planos (0 = corte)

-- REPRODUCCIÓN -------------------------------------------------------------
Config.RetrasoInicio = 2 -- segundos de espera antes del primer paso (para empezar a grabar)
Config.Repetir = false -- vuelve a empezar la escena al terminar
Config.OcultarInterfazRoblox = true -- oculta chat, lista de jugadores, etc.
Config.OcultarRaton = true -- oculta el cursor dentro del juego
Config.CuentaAtras = false -- muestra 3-2-1 antes del primer paso (referencia para montar el audio)

-- AUDIO --------------------------------------------------------------------
Config.Subtitulos = false -- muestra el texto de cada voz (Modulos > Voces) abajo, en la zona segura

-- MOVIMIENTO ---------------------------------------------------------------
Config.VelocidadCaminar = 7 -- studs por segundo
Config.VelocidadCorrer = 16

return Config
]=======] },
	{ Ruta = "StoryTemplate/Modulos", Nombre = "Director", Clase = "ModuleScript", Fuente = [=======[
--[[
	DIRECTOR · Reproduce una escena paso a paso
	Studio: ReplicatedStorage > StoryTemplate > Modulos > Director

	Lo arranca el LocalScript StarterPlayerScripts > StoryRunner.
	Todo ocurre en el cliente: personajes, objetos y escenario son copias
	locales, sin física ni red, para que el coste sea mínimo.

	Dos formas de ordenar los pasos (se pueden mezclar):
	  · Secuencial: cada paso espera a que termine el anterior (Paralelo = true para no esperar).
	  · Línea de tiempo: un paso con  T = segundos  se ejecuta exactamente en ese segundo
	    de la escena (contado desde el primer paso) y no bloquea a los siguientes.
	    Es la forma recomendada para sincronizar con audio: los tiempos no se desvían.

	La lista completa de acciones está en README.md. No hace falta editar este
	archivo para crear escenas nuevas.
]]

local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local SoundService = game:GetService("SoundService")
local StarterGui = game:GetService("StarterGui")
local UserInputService = game:GetService("UserInputService")
local ContentProvider = game:GetService("ContentProvider")

local Modulos = script.Parent
local Raiz = Modulos.Parent
local Config = require(Raiz:WaitForChild("Config"))
local Actor = require(Modulos:WaitForChild("Actor"))
local Camaras = require(Modulos:WaitForChild("Camaras"))
local Guias = require(Modulos:WaitForChild("Guias"))
local Efectos = require(Modulos:WaitForChild("Efectos"))

local Voces = nil
do
	local m = Modulos:FindFirstChild("Voces")
	if m then
		local ok, res = pcall(require, m)
		if ok then
			Voces = res
		else
			warn("[Historia] Error al leer Modulos > Voces: " .. tostring(res))
		end
	end
end

local NOMBRE_RENDER = "CamaraHistoria"

local LUZ_ORIGINAL = {
	ClockTime = Lighting.ClockTime,
	Brightness = Lighting.Brightness,
	Ambient = Lighting.Ambient,
	OutdoorAmbient = Lighting.OutdoorAmbient,
}

local Director = {}

local function plano(v)
	local p = Vector3.new(v.X, 0, v.Z)
	if p.Magnitude < 1e-3 then
		return Vector3.new(0, 0, -1)
	end
	return p.Unit
end

local function suavizar(a)
	return a * a * (3 - 2 * a)
end

local function fijarObjeto(objeto, anclado)
	for _, d in ipairs(objeto:GetDescendants()) do
		if d:IsA("BasePart") then
			d.Anchored = anclado
			d.CanCollide = false
			d.CanTouch = false
			d.CanQuery = false
		end
	end
end

-- Gesto adecuado para alcanzar algo según su altura respecto al personaje.
local function gestoPorAltura(actor, y)
	local d = y - actor.Raiz.Position.Y
	if d > 1 then
		return "Pegar"
	elseif d > -1.9 then
		return "AlcanzarMesa"
	end
	return "Agacharse"
end

--==============================================================================
-- CONTEXTO: estado de la escena en reproducción
--==============================================================================

local Contexto = {}
Contexto.__index = Contexto

function Contexto.new(escena)
	local self = setmetatable({}, Contexto)
	self.Escena = escena
	self.Actores = {} -- rol -> Actor
	self.Orden = {} -- roles en orden de aparición
	self.Objetos = {} -- nombre -> Model
	self.EntornoObj = {} -- Model -> nombre del entorno donde está colocado
	self.Memoria = {} -- entorno -> { Actores, Objetos } al salir de él
	self.Sonidos = {}
	self.SonidosVoz = {}
	self.Inicio = nil
	local viejo = workspace:FindFirstChild("Escenario")
	if viejo then
		viejo:Destroy()
	end
	self.Carpeta = Instance.new("Folder")
	self.Carpeta.Name = "Escenario"
	self.Carpeta.Parent = workspace
	return self
end

-- Segundos desde el primer paso de la escena.
function Contexto:Reloj()
	if not self.Inicio then
		return 0
	end
	return os.clock() - self.Inicio
end

-- ENTORNO ----------------------------------------------------------------------

function Contexto:EnMano(objeto)
	for _, a in pairs(self.Actores) do
		if a.Objeto == objeto then
			return a
		end
	end
	return nil
end

--[[
	Cambia de escenario. Cada entorno "recuerda" quién y qué había al salir:
	al volver, los personajes y objetos aparecen donde estaban (útil para
	flashbacks y para alternar escenarios). Al entrar en un entorno nuevo no
	hay nadie: coloca a los personajes con Colocar / Caminar / Sentar.
]]
function Contexto:CargarEntorno(nombre)
	local plantilla = Raiz.Entornos:FindFirstChild(tostring(nombre))
	if not plantilla then
		error(("No existe el entorno '%s' en StoryTemplate > Entornos"):format(tostring(nombre)), 0)
	end
	if self.Entorno then
		local mem = { Actores = {}, Objetos = {} }
		for _, a in pairs(self.Actores) do
			if a.Modelo.Parent then
				mem.Actores[a] = { CFrame = a.Raiz.CFrame, Piernas = a.PosturaPiernas }
				self:OcultarActor(a)
			end
		end
		for _, objeto in pairs(self.Objetos) do
			if objeto.Parent and not self:EnMano(objeto) then
				mem.Objetos[objeto] = true
				objeto.Parent = nil
			end
		end
		self.Memoria[self.Entorno.Name] = mem
		self.Entorno:Destroy()
	end

	local entorno = plantilla:Clone()
	local marcas = entorno:FindFirstChild("Marcas")
	if marcas then
		for _, d in ipairs(marcas:GetDescendants()) do
			if d:IsA("BasePart") then
				d.Transparency = 1
				d.CastShadow = false
			elseif d:IsA("LayerCollector") then
				d.Enabled = false
			end
		end
	end
	entorno.Parent = self.Carpeta
	self.Entorno = entorno

	-- Iluminación y tono del entorno (atributos del Model)
	Lighting.ClockTime = entorno:GetAttribute("Hora") or LUZ_ORIGINAL.ClockTime
	Lighting.Brightness = entorno:GetAttribute("Brillo") or LUZ_ORIGINAL.Brightness
	Lighting.Ambient = entorno:GetAttribute("Ambiente") or LUZ_ORIGINAL.Ambient
	Lighting.OutdoorAmbient = entorno:GetAttribute("AmbienteExterior") or LUZ_ORIGINAL.OutdoorAmbient
	Efectos.TonoEntorno(entorno:GetAttribute("Tinte"), entorno:GetAttribute("Saturacion"))

	local audiencia = self:Marca("Audiencia")
	self.Audiencia = audiencia and audiencia.Position or nil

	-- Restaura lo que había la última vez que se estuvo aquí
	local mem = self.Memoria[entorno.Name]
	if mem then
		for a, estado in pairs(mem.Actores) do
			if not a.Modelo.Parent then
				a:_cancelarMovimiento()
				a.Raiz.CFrame = estado.CFrame
				a.PosturaPiernas = estado.Piernas
				self:Mostrar(a)
				a:_postura(nil)
				a:_aplicar(0)
			end
		end
		for objeto in pairs(mem.Objetos) do
			if not objeto.Parent and self.EntornoObj[objeto] == entorno.Name then
				objeto.Parent = self.Carpeta
			end
		end
	end
end

function Contexto:Marca(nombre)
	local marcas = self.Entorno and self.Entorno:FindFirstChild("Marcas")
	return marcas and marcas:FindFirstChild(tostring(nombre)) or nil
end

-- ACTORES ----------------------------------------------------------------------

function Contexto:ObtenerActor(rol)
	local actor = self.Actores[rol]
	if actor then
		return actor
	end
	local reparto = self.Escena.Reparto or {}
	local nombreModelo = reparto[rol] or rol
	local plantilla = Raiz.Personajes:FindFirstChild(tostring(nombreModelo))
	if not plantilla then
		error(("No existe el personaje '%s' (rol '%s') en StoryTemplate > Personajes"):format(tostring(nombreModelo), tostring(rol)), 0)
	end
	local modelo = plantilla:Clone()
	modelo.Name = rol
	modelo.Parent = self.Carpeta
	actor = Actor.new(modelo, rol)
	self.Actores[rol] = actor
	table.insert(self.Orden, rol)
	return actor
end

function Contexto:ActorVisible(rol)
	local actor = self.Actores[rol]
	if not actor then
		error(("El actor '%s' todavía no está en escena: usa Colocar (o Posiciones) antes"):format(tostring(rol)), 0)
	end
	if not actor.Modelo.Parent then
		error(("El actor '%s' está oculto: usa Colocar para que vuelva"):format(tostring(rol)), 0)
	end
	return actor
end

function Contexto:ActoresVisibles()
	local lista = {}
	for _, rol in ipairs(self.Orden) do
		local a = self.Actores[rol]
		if a.Modelo.Parent then
			table.insert(lista, a)
		end
	end
	return lista
end

function Contexto:Mostrar(actor)
	if not actor.Modelo.Parent then
		actor.Modelo.Parent = self.Carpeta
		if actor.Objeto then
			actor.Objeto.Parent = self.Carpeta
		end
		actor:Reanudar()
	end
end

function Contexto:OcultarActor(actor)
	actor.Modelo.Parent = nil
	if actor.Objeto then
		actor.Objeto.Parent = nil
	end
end

-- POSICIONES -------------------------------------------------------------------

--[[
	Convierte un destino en un punto. "valor" puede ser:
	  · nombre de marca del entorno ("Pos_A", "Entrada_Izq", "Obj_1"...) → su base
	  · rol de un actor visible → se queda a "distancia" de él (3 por defecto)
	  · nombre de un objeto en escena → su cara de arriba (o a "distancia" si se camina hacia él)
	  · un Vector3
	Devuelve: posición, marca (si era una marca)
]]
function Contexto:Pos(valor, desde, distancia)
	if typeof(valor) == "Vector3" then
		return valor, nil
	end
	local nombre = tostring(valor)
	local actor = self.Actores[nombre]
	if actor and actor.Modelo.Parent then
		local p = actor:PosicionSuelo()
		if desde then
			return p + plano(desde - p) * (distancia or 3), nil
		end
		return p, nil
	end
	local objeto = self.Objetos[nombre]
	if objeto and objeto.Parent then
		local cf, tam = objeto:GetBoundingBox()
		if desde then
			local suelo = Vector3.new(cf.X, desde.Y, cf.Z)
			return suelo + plano(desde - suelo) * (distancia or 1.6), nil
		end
		return cf.Position + Vector3.new(0, tam.Y / 2, 0), nil
	end
	local marca = self:Marca(nombre)
	if marca then
		if marca:GetAttribute("Pared") then
			-- Para caminar hacia una marca de pared: un punto del suelo delante de ella
			local n = plano(marca.CFrame.LookVector)
			local y = desde and desde.Y or 0
			return Vector3.new(marca.Position.X, y, marca.Position.Z) + n * (distancia or 1.4), marca
		end
		return marca.Position - Vector3.new(0, marca.Size.Y / 2, 0), marca
	end
	error(
		("No encuentro '%s': no es una marca del entorno '%s', ni un actor visible, ni un objeto en escena"):format(
			nombre,
			self.Entorno and self.Entorno.Name or "?"
		),
		0
	)
end

-- Punto al que mirar: "Camara", un actor (su cabeza), una marca, un objeto o un Vector3.
function Contexto:PuntoMirada(valor)
	if valor == "Camara" then
		local e = self.EstadoCamara
		local ok, cf = pcall(function()
			return e.Calcular()
		end)
		if ok and typeof(cf) == "CFrame" then
			return cf.Position
		end
		return workspace.CurrentCamera.CFrame.Position
	end
	local actor = type(valor) == "string" and self.Actores[valor]
	if actor and actor.Modelo.Parent then
		return actor.Raiz.Position + Vector3.new(0, actor.AlturaCabeza, 0)
	end
	local objeto = type(valor) == "string" and self.Objetos[valor]
	if objeto and objeto.Parent then
		return objeto:GetBoundingBox().Position
	end
	local pos, marca = self:Pos(valor)
	if marca then
		return marca.Position
	end
	return pos
end

--[[
	Superficie sobre la que pegar o apoyar algo. Devuelve punto y normal:
	  · marca de pared (atributo Pared) → su centro y su cara frontal
	  · marca normal / Vector3          → hacia arriba
	  · objeto en escena                → su cara de arriba
]]
function Contexto:Superficie(destino, desplazamiento)
	local punto, normal
	if typeof(destino) == "Vector3" then
		punto, normal = destino, Vector3.yAxis
	else
		local nombre = tostring(destino)
		local objeto = self.Objetos[nombre]
		local marca = self:Marca(nombre)
		if objeto and objeto.Parent then
			local cf, tam = objeto:GetBoundingBox()
			punto, normal = cf.Position + Vector3.new(0, tam.Y / 2, 0), Vector3.yAxis
		elseif marca and marca:GetAttribute("Pared") then
			normal = marca.CFrame.LookVector
			punto = marca.Position - normal * (marca.Size.Z / 2)
		elseif marca then
			punto, normal = marca.Position - Vector3.new(0, marca.Size.Y / 2, 0), Vector3.yAxis
		else
			punto, normal = self:Pos(destino), Vector3.yAxis
		end
	end
	if typeof(desplazamiento) == "Vector3" then
		punto = punto + desplazamiento
	end
	return punto, normal
end

-- OBJETOS ----------------------------------------------------------------------

function Contexto:ObtenerObjeto(nombre)
	if self.Objetos[nombre] then
		return self.Objetos[nombre]
	end
	local def = (self.Escena.Objetos or {})[nombre]
	if type(def) ~= "table" then
		def = {}
	end
	local nombreModelo = def.Modelo or nombre
	local plantilla = Raiz.Objetos:FindFirstChild(tostring(nombreModelo))
	if not plantilla then
		error(("No existe el objeto '%s' en StoryTemplate > Objetos"):format(tostring(nombreModelo)), 0)
	end
	local objeto = plantilla:Clone()
	objeto.Name = nombre
	if not objeto.PrimaryPart then
		objeto.PrimaryPart = objeto:FindFirstChildWhichIsA("BasePart", true)
	end
	for _, d in ipairs(objeto:GetDescendants()) do
		if d:IsA("BasePart") and d ~= objeto.PrimaryPart then
			local w = Instance.new("WeldConstraint")
			w.Part0 = objeto.PrimaryPart
			w.Part1 = d
			w.Parent = d
		end
	end
	if typeof(def.Color) == "Color3" then
		objeto.PrimaryPart.Color = def.Color
		local franja = objeto:FindFirstChild("Franja")
		if franja and franja:IsA("BasePart") then
			franja.Color = def.Color:Lerp(Color3.new(0, 0, 0), 0.08)
		end
	end
	-- Texto escrito a mano en la cara frontal (notas, carteles...)
	if def.Texto then
		local sg = Instance.new("SurfaceGui")
		sg.Name = "Escrito"
		sg.Face = Enum.NormalId.Front
		sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		sg.PixelsPerStud = 150
		sg.LightInfluence = 1
		local l = Instance.new("TextLabel")
		l.BackgroundTransparency = 1
		l.Size = UDim2.fromScale(0.84, 0.74)
		l.Position = UDim2.fromScale(0.08, 0.16)
		l.Font = Enum.Font.PermanentMarker
		l.TextScaled = true
		l.TextWrapped = true
		l.TextColor3 = def.ColorTexto or Color3.fromRGB(30, 40, 110)
		l.Text = def.Texto
		l.Parent = sg
		sg.Parent = objeto.PrimaryPart
	end
	fijarObjeto(objeto, true)
	self.Objetos[nombre] = objeto
	return objeto
end

function Contexto:QuitarDeManos(objeto)
	for _, a in pairs(self.Actores) do
		if a.Objeto == objeto then
			a:Soltar()
		end
	end
end

--[[
	Coloca un objeto en una superficie.
	  · Pared: la cara frontal del objeto queda hacia fuera.
	  · Horizontal y objeto "Plano" (hojas, notas): tumbado, con el texto legible desde la cámara.
	  · Horizontal y objeto normal: de pie, mirando hacia "direccion".
]]
function Contexto:FijarEnSuperficie(objeto, punto, normal, direccion)
	self:QuitarDeManos(objeto)
	fijarObjeto(objeto, true)
	local tam = objeto:GetExtentsSize()
	local esPlano = objeto:GetAttribute("Plano") == true
	if math.abs(normal.Y) < 0.7 then
		objeto:PivotTo(CFrame.lookAt(punto, punto + normal) + normal * (tam.Z / 2 + 0.01))
	elseif esPlano then
		local arriba = direccion and -plano(direccion) or Vector3.new(0, 0, -1)
		objeto:PivotTo(CFrame.lookAt(punto, punto + Vector3.yAxis, arriba) + Vector3.new(0, tam.Z / 2 + 0.01, 0))
	else
		local dir = direccion and plano(direccion) or Vector3.new(0, 0, -1)
		objeto:PivotTo(CFrame.lookAt(punto, punto + dir))
		local cf, t = objeto:GetBoundingBox()
		objeto:PivotTo(objeto:GetPivot() + Vector3.new(0, punto.Y - (cf.Position.Y - t.Y / 2), 0))
	end
	objeto.Parent = self.Carpeta
	self.EntornoObj[objeto] = self.Entorno and self.Entorno.Name
end

function Contexto:ColocarObjeto(nombre, donde, desplazamiento)
	local objeto = self:ObtenerObjeto(nombre)
	local punto, normal = self:Superficie(donde, desplazamiento)
	local marca = type(donde) == "string" and self:Marca(donde)
	self:FijarEnSuperficie(objeto, punto, normal, marca and marca.CFrame.LookVector or nil)
	return objeto
end

function Contexto:DarObjeto(nombre, actor)
	local objeto = self:ObtenerObjeto(nombre)
	self:QuitarDeManos(objeto)
	objeto.Parent = self.Carpeta
	actor:Sostener(objeto)
	return objeto
end

-- Hace caer un objeto hasta el suelo (o hasta "destino") con vaivén de papel.
function Contexto:Caer(objeto, destino, tiempo)
	self:QuitarDeManos(objeto)
	fijarObjeto(objeto, true)
	objeto.Parent = self.Carpeta
	local azar = Random.new()
	local inicio = objeto:GetPivot()
	local punto
	if destino then
		punto = self:Superficie(destino)
	else
		punto = Vector3.new(inicio.X + azar:NextNumber(-0.5, 0.5), 0, inicio.Z + azar:NextNumber(0.4, 0.9))
	end
	local tam = objeto:GetExtentsSize()
	local giro = math.rad(azar:NextNumber(-35, 35))
	local final
	if objeto:GetAttribute("Plano") then
		local arriba = CFrame.Angles(0, giro, 0):VectorToWorldSpace(Vector3.new(0, 0, -1))
		final = CFrame.lookAt(punto, punto + Vector3.yAxis, arriba) + Vector3.new(0, tam.Z / 2 + 0.01, 0)
	else
		final = CFrame.new(punto + Vector3.new(0, tam.Y / 2, 0)) * CFrame.Angles(0, giro, 0)
	end
	tiempo = tiempo or 0.9
	self.EntornoObj[objeto] = self.Entorno and self.Entorno.Name
	task.spawn(function()
		local t0 = os.clock()
		while objeto.Parent do
			local a = math.min((os.clock() - t0) / tiempo, 1)
			local pos = inicio.Position:Lerp(final.Position, a)
			pos = Vector3.new(pos.X, inicio.Y + (final.Y - inicio.Y) * a * a, pos.Z)
			local vaiven = math.sin(a * math.pi * 3) * 0.35 * (1 - a)
			local rot = inicio.Rotation:Lerp(final.Rotation, math.min(1, a * 1.3))
			objeto:PivotTo(CFrame.new(pos + Vector3.new(vaiven, 0, 0)) * rot * CFrame.Angles(vaiven * 0.8, 0, vaiven))
			if a >= 1 then
				break
			end
			RunService.Heartbeat:Wait()
		end
		objeto:PivotTo(final)
	end)
	return tiempo
end

-- Aparece un objeto con un pequeño rebote (ideal para notas que "brotan").
function Contexto:Aparecer(nombre, donde, desplazamiento)
	local objeto = self:ColocarObjeto(nombre, donde, desplazamiento)
	local ok = pcall(function()
		objeto:ScaleTo(0.05)
	end)
	if ok then
		task.spawn(function()
			local t0 = os.clock()
			while objeto.Parent do
				local a = math.min((os.clock() - t0) / 0.28, 1)
				local e = a < 0.7 and (a / 0.7) * 1.15 or 1.15 - (a - 0.7) / 0.3 * 0.15
				objeto:ScaleTo(math.max(0.05, e))
				if a >= 1 then
					break
				end
				RunService.Heartbeat:Wait()
			end
			objeto:ScaleTo(1)
		end)
	end
	return objeto
end

-- SONIDO -----------------------------------------------------------------------

-- "nombre" puede ser un Sound de StoryTemplate > Audio, un id numérico o "rbxassetid://...".
function Contexto:Sonido(nombre, volumen, bucle)
	local plantilla = Raiz.Audio:FindFirstChild(tostring(nombre))
	local s
	if plantilla and plantilla:IsA("Sound") then
		s = plantilla:Clone()
	else
		s = Instance.new("Sound")
		local id = tostring(nombre)
		if id:match("^%d+$") then
			id = "rbxassetid://" .. id
		end
		s.SoundId = id
	end
	if s.SoundId == "" or not s.SoundId:match("%d") then
		warn(("[Historia] El sonido '%s' no tiene un SoundId válido; se omite"):format(tostring(nombre)))
		s:Destroy()
		return nil
	end
	if volumen then
		s.Volume = volumen
	end
	if bucle ~= nil then
		s.Looped = bucle
	end
	s.Parent = SoundService
	table.insert(self.Sonidos, s)
	return s
end

function Contexto:Duracion(sonido)
	local t = 0
	while not sonido.IsLoaded and t < 5 do
		t = t + task.wait(0.05)
	end
	return sonido.TimeLength / math.max(sonido.PlaybackSpeed, 0.01)
end

-- Sonido de una voz de Modulos > Voces (se precarga al empezar la escena).
function Contexto:SonidoVoz(nombre)
	if self.SonidosVoz[nombre] then
		return self.SonidosVoz[nombre]
	end
	local datos = Voces and Voces[nombre]
	if not datos or not datos.Id or datos.Id == "" then
		return nil
	end
	local s = Instance.new("Sound")
	s.Name = "Voz_" .. nombre
	s.SoundId = datos.Id
	s.Volume = 1
	s.Parent = SoundService
	self.SonidosVoz[nombre] = s
	table.insert(self.Sonidos, s)
	return s
end

function Contexto:PrecargarVoces()
	if not Voces then
		return
	end
	local lista = {}
	for nombre, datos in pairs(Voces) do
		if type(datos) == "table" then
			local s = self:SonidoVoz(nombre)
			if s then
				table.insert(lista, s)
			end
		end
	end
	if #lista > 0 then
		task.spawn(function()
			pcall(function()
				ContentProvider:PreloadAsync(lista)
			end)
		end)
	end
end

-- CÁMARA -----------------------------------------------------------------------

function Contexto:IniciarCamara()
	local camara = workspace.CurrentCamera
	camara.CameraType = Enum.CameraType.Scriptable
	self.EstadoCamara = {
		Calcular = function()
			return camara.CFrame
		end,
		Inicio = os.clock(),
	}
	RunService:UnbindFromRenderStep(NOMBRE_RENDER)
	RunService:BindToRenderStep(NOMBRE_RENDER, Enum.RenderPriority.Camera.Value + 1, function()
		if self.Inicio then
			Guias.Tiempo(self:Reloj(), self.Etiqueta)
		end
		local e = self.EstadoCamara
		local ok, objetivo = pcall(e.Calcular)
		if not ok or typeof(objetivo) ~= "CFrame" then
			return
		end
		local ahora = os.clock()
		if e.Acercar and e.Acercar ~= 0 then
			local p = math.clamp((ahora - e.Inicio) / e.TiempoAcercar, 0, 1)
			objetivo = objetivo * CFrame.new(0, 0, -e.Acercar * suavizar(p))
		end
		if e.Desde then
			local a = (ahora - e.Inicio) / e.Transicion
			if a >= 1 then
				e.Desde = nil
			else
				objetivo = e.Desde:Lerp(objetivo, suavizar(a))
			end
		end
		camara.CameraType = Enum.CameraType.Scriptable
		camara.CFrame = objetivo
		camara.FieldOfView = Guias.FOVReal(camara, e.FOV or Config.CampoVision, Config.Aspecto)
	end)
end

function Contexto:Camara(p)
	local fov = p.FOV or Config.CampoVision
	local calcular = Camaras.Preparar(p, self, fov, Config.Aspecto)
	local camara = workspace.CurrentCamera
	local estado = {
		Calcular = calcular,
		Inicio = os.clock(),
		FOV = fov,
		Acercar = p.Acercar,
		TiempoAcercar = p.TiempoAcercar or 4,
	}
	local transicion = p.Transicion or Config.TransicionCamara or 0
	if transicion > 0 then
		estado.Desde = camara.CFrame
		estado.Transicion = transicion
	end
	self.EstadoCamara = estado
end

function Contexto:Destruir()
	RunService:UnbindFromRenderStep(NOMBRE_RENDER)
	for _, s in ipairs(self.Sonidos) do
		s:Destroy()
	end
	Efectos.Filtro(nil)
	Efectos.TonoEntorno(nil)
	Efectos.Limpiar()
	self.Carpeta:Destroy()
end

--==============================================================================
-- ACCIONES: cada una devuelve los segundos que dura (el Director espera ese
-- tiempo salvo que el paso tenga Paralelo = true o T = segundos).
--==============================================================================

local Acciones = {}

Acciones.Esperar = function(_, p)
	return p.Tiempo or p[2] or 1
end

-- Espera hasta el segundo "Tiempo" de la escena (contado desde el primer paso).
Acciones.EsperarHasta = function(ctx, p)
	return math.max(0, (p.Tiempo or p[2] or 0) - ctx:Reloj())
end

Acciones.Colocar = function(ctx, p)
	local actor = ctx:ObtenerActor(p.Actor)
	local pos, marca = ctx:Pos(p.En or p.Marca)
	ctx:Mostrar(actor)
	actor:Colocar(pos, marca and marca.CFrame.LookVector or nil)
	if p.MirarA then
		actor:MirarHacia(ctx:PuntoMirada(p.MirarA), 0)
	end
	return 0
end

Acciones.Ocultar = function(ctx, p)
	local actor = ctx.Actores[p.Actor]
	if actor then
		ctx:OcultarActor(actor)
	end
	return 0
end

-- Sienta a un actor en una marca de asiento (Silla_...).
Acciones.Sentar = function(ctx, p)
	local actor = ctx:ObtenerActor(p.Actor)
	local punto = ctx:Superficie(p.En or p.Marca)
	local marca = ctx:Marca(p.En or p.Marca)
	ctx:Mostrar(actor)
	actor:Sentar(punto, marca and marca.CFrame.LookVector or nil)
	return 0
end

-- Levanta a un actor sentado y lo deja de pie en "En" (o justo delante del asiento).
Acciones.Levantar = function(ctx, p)
	local actor = ctx:ActorVisible(p.Actor)
	local pos, marca
	if p.En then
		pos, marca = ctx:Pos(p.En)
	else
		local r = actor.Raiz.Position
		pos = Vector3.new(r.X, 0, r.Z) + plano(actor.Raiz.CFrame.LookVector) * 1.4
	end
	actor:Colocar(pos, marca and marca.CFrame.LookVector or actor.Raiz.CFrame.LookVector)
	return 0
end

local function desplazar(ctx, p, base, velocidad)
	local actor
	if p.Desde then
		actor = ctx:ObtenerActor(p.Actor)
		local pos0, marca0 = ctx:Pos(p.Desde)
		ctx:Mostrar(actor)
		actor:Colocar(pos0, marca0 and marca0.CFrame.LookVector or nil)
	else
		actor = ctx:ActorVisible(p.Actor)
	end
	local destino = ctx:Pos(p.Hasta, actor:PosicionSuelo(), p.Distancia)
	local duracion = actor:Mover(destino, p.Velocidad or velocidad, base)
	if p.MirarA then
		local objetivo = p.MirarA
		task.delay(duracion, function()
			if actor.Modelo.Parent then
				actor:MirarHacia(ctx:PuntoMirada(objetivo))
			end
		end)
		duracion = duracion + 0.35
	end
	return duracion
end

Acciones.Caminar = function(ctx, p)
	return desplazar(ctx, p, "Caminar", Config.VelocidadCaminar)
end

Acciones.Correr = function(ctx, p)
	return desplazar(ctx, p, "Correr", Config.VelocidadCorrer)
end

Acciones.Mirar = function(ctx, p)
	local actor = ctx:ActorVisible(p.Actor)
	if p.SoloCabeza then
		actor:MirarCabeza(p.A and ctx:PuntoMirada(p.A) or nil, p.Tiempo)
		return p.Tiempo or 0.3
	end
	actor:MirarCabeza(nil, 0.3)
	return actor:MirarHacia(ctx:PuntoMirada(p.A), p.Tiempo)
end

Acciones.Gesto = function(ctx, p)
	return ctx:ActorVisible(p.Actor):Gesto(p.Gesto, p.Duracion, p.Mantener)
end

-- Gesto de reposo que se mantiene debajo de los demás ("Ninguna" para quitarlo).
Acciones.Postura = function(ctx, p)
	local nombre = p.Postura
	if nombre == "Ninguna" then
		nombre = nil
	end
	ctx:ActorVisible(p.Actor):FijarPostura(nombre)
	return 0
end

Acciones.Expresion = function(ctx, p)
	local nombre = p.Expresion
	if nombre == "Ninguna" then
		nombre = nil
	end
	ctx:ActorVisible(p.Actor):Expresion(nombre, p.Duracion)
	return 0
end

Acciones.Hablar = function(ctx, p)
	local actor = ctx:ActorVisible(p.Actor)
	local duracion = p.Duracion
	if p.Sonido then
		local s = ctx:Sonido(p.Sonido, p.Volumen, false)
		if s then
			s:Play()
			duracion = duracion or ctx:Duracion(s)
		end
	end
	duracion = duracion or 2
	actor:MoverBoca(duracion)
	if p.SoloBoca then
		return duracion
	end
	return actor:Gesto("Hablar", duracion)
end

--[[
	Reproduce una voz de Modulos > Voces y sincroniza los labios con su volumen.
	  Voz         = nombre de la voz ("postit1")
	  Actor       = rol que habla (por defecto, el Personaje de la voz si es Dialogo)
	  Labios      = mover la boca (por defecto: sí en Dialogo, no en Narrador)
	  LabiosHasta = segundos de labios (p. ej. solo la primera frase)
	  Gestos      = true → además gesticula con las manos
]]
Acciones.Voz = function(ctx, p)
	local nombre = p.Voz
	local datos = Voces and Voces[nombre]
	if type(datos) ~= "table" then
		error(("No existe la voz '%s' en Modulos > Voces"):format(tostring(nombre)), 0)
	end
	local duracion = datos.Duracion
	local s = ctx:SonidoVoz(nombre)
	if s then
		if p.Volumen then
			s.Volume = p.Volumen
		end
		s.TimePosition = 0
		s:Play()
	end
	local rol = p.Actor
	if rol == nil and datos.Tipo ~= "Narrador" then
		rol = datos.Personaje
	end
	local labios = p.Labios
	if labios == nil then
		labios = datos.Tipo ~= "Narrador"
	end
	if rol and labios then
		local actor = ctx.Actores[rol]
		if actor and actor.Modelo.Parent then
			actor:MoverBocaEnvolvente(datos.Envolvente, Voces.Paso, p.LabiosHasta)
			if p.Gestos then
				actor:Gesto("Hablar", p.LabiosHasta or duracion)
			end
		end
	end
	if Config.Subtitulos and datos.Texto and datos.Texto ~= "" then
		Efectos.Texto(datos.Texto, "Subtitulo", duracion)
	end
	ctx.Etiqueta = nombre
	print(("[Historia] t = %6.2f s  ▶ %s (%.2f s) %s"):format(ctx:Reloj(), nombre, duracion, s and "" or "[sin Id: silencio]"))
	return duracion
end

Acciones.Senalar = function(ctx, p)
	local actor = ctx:ActorVisible(p.Actor)
	local giro = 0
	if p.A then
		if actor.PosturaPiernas then
			actor:MirarCabeza(ctx:PuntoMirada(p.A))
		else
			giro = actor:MirarHacia(ctx:PuntoMirada(p.A))
		end
	end
	local duracion = p.Duracion or 1.5
	task.delay(giro, function()
		actor:Gesto("Senalar", duracion, p.Mantener)
	end)
	return giro + duracion
end

Acciones.Sorpresa = function(ctx, p)
	local actor = ctx:ActorVisible(p.Actor)
	local duracion = actor:Gesto("Sorpresa", p.Duracion, p.Mantener)
	actor:Expresion("Sorpresa", (not p.Mantener) and duracion + 0.3 or nil)
	return duracion
end

Acciones.Animacion = function(ctx, p)
	return ctx:ActorVisible(p.Actor):Clip(p.Clip or p.Animacion)
end

Acciones.Entregar = function(ctx, p)
	local de = ctx:ActorVisible(p.De)
	local para = ctx:ActorVisible(p.A)
	local objeto
	if p.Objeto then
		objeto = ctx:ObtenerObjeto(p.Objeto)
		if de.Objeto ~= objeto then
			ctx:DarObjeto(p.Objeto, de)
		end
	else
		objeto = de.Objeto
	end
	if not objeto then
		error(("Entregar: '%s' no lleva ningún objeto; indica Objeto = \"...\""):format(tostring(p.De)), 0)
	end
	task.spawn(function()
		de:MirarHacia(para.Raiz.Position)
		para:MirarHacia(de.Raiz.Position)
		task.wait(0.35)
		de:Gesto("Entregar", 1)
		task.wait(0.35)
		para:Gesto("Recibir", 0.7)
		task.wait(0.4)
		if de.Objeto == objeto then
			de:Soltar(true)
			para:Sostener(objeto)
		end
	end)
	return 2
end

-- Coge un objeto (del suelo, de una mesa o de una pared: elige el gesto según la altura).
Acciones.Recoger = function(ctx, p)
	local actor = ctx:ActorVisible(p.Actor)
	local objeto = ctx:ObtenerObjeto(p.Objeto)
	local giro = 0
	local gesto = p.Gesto
	if objeto.Parent then
		local pos = objeto:GetBoundingBox().Position
		gesto = gesto or gestoPorAltura(actor, pos.Y)
		if not actor.PosturaPiernas then
			giro = actor:MirarHacia(pos)
		end
	end
	gesto = gesto or "Agacharse"
	task.spawn(function()
		task.wait(giro)
		actor:Gesto(gesto, 0.8)
		task.wait(0.45)
		ctx:DarObjeto(p.Objeto, actor)
	end)
	return giro + 1.1
end

-- Deja lo que lleva en la mano en "En" (o lo hace desaparecer si no hay En).
Acciones.Soltar = function(ctx, p)
	local actor = ctx:ActorVisible(p.Actor)
	local objeto = actor.Objeto
	if not objeto then
		return 0
	end
	if p.En then
		local donde, desp = p.En, p.Desplazamiento
		local punto = ctx:Superficie(donde, desp)
		local gesto = p.Gesto or gestoPorAltura(actor, punto.Y)
		task.spawn(function()
			actor:Gesto(gesto, 0.7)
			task.wait(0.45)
			ctx:ColocarObjeto(objeto.Name, donde, desp)
		end)
		return 1
	end
	actor:Soltar()
	objeto.Parent = nil
	return 0
end

-- Pega lo que lleva en la mano (u Objeto) en una pared o encima de otro objeto.
Acciones.Pegar = function(ctx, p)
	local actor = ctx:ActorVisible(p.Actor)
	local objeto
	if p.Objeto then
		objeto = ctx:ObtenerObjeto(p.Objeto)
		if actor.Objeto ~= objeto then
			ctx:DarObjeto(p.Objeto, actor)
		end
	else
		objeto = actor.Objeto
	end
	if not objeto then
		error(("Pegar: '%s' no lleva nada en la mano; indica Objeto = \"...\""):format(tostring(p.Actor)), 0)
	end
	local punto, normal = ctx:Superficie(p.En, p.Desplazamiento)
	local giro = 0
	if not actor.PosturaPiernas then
		giro = actor:MirarHacia(punto)
	end
	local gesto = p.Gesto or gestoPorAltura(actor, punto.Y)
	task.spawn(function()
		task.wait(giro)
		actor:Gesto(gesto, 0.8)
		task.wait(0.45)
		ctx:FijarEnSuperficie(objeto, punto, normal, actor.Raiz.CFrame.LookVector * -1)
	end)
	return giro + 1
end

-- Un objeto cae al suelo (o a "Hasta") balanceándose como un papel.
Acciones.Caer = function(ctx, p)
	local objeto = ctx:ObtenerObjeto(p.Objeto)
	return ctx:Caer(objeto, p.Hasta, p.Tiempo)
end

-- Un objeto aparece de golpe con un rebote en "En".
Acciones.Aparecer = function(ctx, p)
	ctx:Aparecer(p.Objeto, p.En or p.Marca, p.Desplazamiento)
	return 0.3
end

Acciones.Objeto = function(ctx, p)
	if p.Visible == false then
		local objeto = ctx.Objetos[p.Objeto]
		if objeto then
			ctx:QuitarDeManos(objeto)
			objeto.Parent = nil
		end
		return 0
	end
	if p.EnManoDe then
		ctx:DarObjeto(p.Objeto, ctx:ActorVisible(p.EnManoDe))
		return 0
	end
	ctx:ColocarObjeto(p.Objeto, p.En or p.Marca, p.Desplazamiento)
	return 0
end

Acciones.Camara = function(ctx, p)
	ctx:Camara(p)
	return 0
end

Acciones.Texto = function(_, p)
	Efectos.Texto(p.Texto, p.Estilo, p.Duracion, {
		Posicion = p.Posicion,
		Tamano = p.Tamano,
		Color = p.Color,
		Giro = p.Giro,
	})
	return 0
end

-- Fundido a negro (o Color = "Blanco"). Devuelve el tiempo hasta cubrir la pantalla.
Acciones.Fundido = function(_, p)
	return Efectos.Fundido(p.Color, p.Entrada, p.Mantener, p.Salida)
end

Acciones.Filtro = function(_, p)
	Efectos.Filtro(p.Filtro)
	return 0
end

Acciones.Sonido = function(ctx, p)
	local s = ctx:Sonido(p.Sonido, p.Volumen, false)
	if not s then
		return 0
	end
	s:Play()
	return ctx:Duracion(s)
end

Acciones.Musica = function(ctx, p)
	if ctx.Musica then
		ctx.Musica:Stop()
		ctx.Musica:Destroy()
		ctx.Musica = nil
	end
	if p.Parar then
		return 0
	end
	local s = ctx:Sonido(p.Sonido, p.Volumen or 0.3, true)
	if s then
		s:Play()
		ctx.Musica = s
	end
	return 0
end

Acciones.Entorno = function(ctx, p)
	ctx:CargarEntorno(p.Nombre or p.Entorno)
	return 0
end

Acciones.Ejecutar = function(ctx, p)
	return p.Funcion(ctx) or 0
end

Director.Acciones = Acciones

--==============================================================================
-- REPRODUCCIÓN
--==============================================================================

local function ejecutarPaso(ctx, paso, i)
	local nombre = paso.Accion or paso[1]
	local accion = Acciones[nombre]
	if not accion then
		warn(("[Historia] Paso %d: acción desconocida '%s'"):format(i, tostring(nombre)))
		return
	end
	if type(paso.T) == "number" and ctx.Inicio then
		local espera = paso.T - ctx:Reloj()
		if espera > 0 then
			task.wait(espera)
		elseif espera < -0.15 then
			warn(("[Historia] Paso %d (%s) llega %.2f s tarde: T = %.2f"):format(i, tostring(nombre), -espera, paso.T))
		end
	end
	local ok, duracion = pcall(accion, ctx, paso)
	if not ok then
		warn(("[Historia] Paso %d (%s): %s"):format(i, tostring(nombre), tostring(duracion)))
		return
	end
	local bloquea = not paso.Paralelo and (paso.T == nil or paso.Esperar == true)
	if bloquea and type(duracion) == "number" and duracion > 0 then
		task.wait(duracion)
	end
	if type(paso.Pausa) == "number" and paso.Pausa > 0 then
		task.wait(paso.Pausa)
	end
end

local function preparar(ctx, escena)
	ctx:CargarEntorno(escena.Entorno or "Neutro")
	ctx:IniciarCamara()

	local posiciones = escena.Posiciones or {}
	for rol, def in pairs(posiciones) do
		local d = type(def) == "table" and def or { Marca = def }
		if d.Sentado then
			Acciones.Sentar(ctx, { Actor = rol, En = d.Sentado })
		else
			Acciones.Colocar(ctx, { Actor = rol, En = d.Marca or d.En })
		end
	end

	ctx:Camara(escena.Camara or { Plano = "General" })

	for rol, def in pairs(posiciones) do
		if type(def) == "table" and def.MirarA then
			ctx:ActorVisible(rol):MirarHacia(ctx:PuntoMirada(def.MirarA), 0)
		end
		if type(def) == "table" and def.Expresion then
			ctx:ActorVisible(rol):Expresion(def.Expresion)
		end
	end

	for nombre, def in pairs(escena.Objetos or {}) do
		local d = type(def) == "table" and def or { En = def }
		if d.EnManoDe then
			ctx:DarObjeto(nombre, ctx:ActorVisible(d.EnManoDe))
		elseif d.En or d.Marca then
			ctx:ColocarObjeto(nombre, d.En or d.Marca, d.Desplazamiento)
		end
	end
	ctx:PrecargarVoces()
end

local function esperarPersonajes()
	local t = 0
	while not Raiz:GetAttribute("PersonajesListos") and t < 20 do
		t = t + task.wait(0.1)
	end
end

local interfazPreparada = false
local function prepararInterfaz()
	if interfazPreparada then
		return
	end
	interfazPreparada = true
	Guias.Crear(Config, Camaras.Margenes)
	if Config.OcultarRaton then
		UserInputService.MouseIconEnabled = false
	end
	if Config.OcultarInterfazRoblox then
		pcall(function()
			StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.All, false)
		end)
		task.spawn(function()
			for _ = 1, 10 do
				if pcall(function()
					StarterGui:SetCore("TopbarEnabled", false)
				end) then
					return
				end
				task.wait(0.5)
			end
		end)
	end
end

-- Cuenta atrás 3-2-1 antes del primer paso (referencia para montar el audio).
local function cuentaAtras(retraso)
	local n = math.min(3, math.floor(retraso))
	if not Config.CuentaAtras or n < 1 then
		task.wait(retraso)
		return
	end
	task.wait(retraso - n)
	for k = n, 1, -1 do
		Efectos.Texto(tostring(k), "Icono", 0.8, { Posicion = Vector2.new(0.5, 0.45), Tamano = Vector2.new(0.4, 0.25) })
		task.wait(1)
	end
end

function Director.Reproducir(nombreEscena)
	esperarPersonajes()
	local modulo = Raiz.Escenas:FindFirstChild(tostring(nombreEscena))
	if not modulo then
		local disponibles = {}
		for _, m in ipairs(Raiz.Escenas:GetChildren()) do
			table.insert(disponibles, m.Name)
		end
		warn(
			("[Historia] No existe la escena '%s'. Escenas disponibles: %s"):format(
				tostring(nombreEscena),
				table.concat(disponibles, ", ")
			)
		)
		return
	end
	local okEscena, escena = pcall(require, modulo)
	if not okEscena or type(escena) ~= "table" then
		warn(("[Historia] Error al leer la escena '%s': %s"):format(modulo.Name, tostring(escena)))
		return
	end

	prepararInterfaz()

	repeat
		local ctx = Contexto.new(escena)
		local ok, err = pcall(preparar, ctx, escena)
		if not ok then
			warn("[Historia] Error preparando la escena: " .. tostring(err))
		end
		print(("[Historia] Escena '%s' lista. Empieza en %s s"):format(modulo.Name, tostring(Config.RetrasoInicio)))
		cuentaAtras(Config.RetrasoInicio or 0)

		ctx.Inicio = os.clock()
		if escena.Musica then
			local paso = { Accion = "Musica" }
			for k, v in pairs(escena.Musica) do
				paso[k] = v
			end
			ejecutarPaso(ctx, paso, 0)
		end
		for i, paso in ipairs(escena.Pasos or {}) do
			ejecutarPaso(ctx, paso, i)
		end
		print(("[Historia] Escena '%s' terminada (%.2f s)"):format(modulo.Name, ctx:Reloj()))

		if Config.Repetir then
			task.wait(2)
			ctx:Destruir()
		end
	until not Config.Repetir
end

return Director
]=======] },
	{ Ruta = "StoryTemplate/Modulos", Nombre = "Actor", Clase = "ModuleScript", Fuente = [=======[
--[[
	ACTOR · Controla un personaje dentro de una escena
	Studio: ReplicatedStorage > StoryTemplate > Modulos > Actor

	Optimización:
	  · La raíz (HumanoidRootPart) queda anclada: no hay física ni colisiones.
	  · El Humanoid no evalúa estados (EvaluateStateMachine = false).
	  · El movimiento se hace con Tweens (motor nativo), no con bucles de script.
	  · Los gestos giran los Motor6D con Tweens encima de la animación base.

	No hace falta editar este archivo para crear escenas.
]]

local TweenService = game:GetService("TweenService")
local Animaciones = require(script.Parent:WaitForChild("Animaciones"))

local Actor = {}
Actor.__index = Actor

local ARTICULACIONES = {
	Neck = true,
	Waist = true,
	RightShoulder = true,
	RightElbow = true,
	RightWrist = true,
	LeftShoulder = true,
	LeftElbow = true,
	LeftWrist = true,
	RightHip = true,
	LeftHip = true,
	RightKnee = true,
	LeftKnee = true,
}

-- Atuendos se carga al usarse (expresiones de la cara)
local cacheAtuendos = nil
local function Atuendos()
	if not cacheAtuendos then
		local m = script.Parent:FindFirstChild("Atuendos")
		cacheAtuendos = m and require(m) or false
	end
	return cacheAtuendos or nil
end

local function plano(v)
	local p = Vector3.new(v.X, 0, v.Z)
	if p.Magnitude < 1e-3 then
		return Vector3.new(0, 0, -1)
	end
	return p.Unit
end

local function aVector(t)
	if typeof(t) == "Vector3" then
		return t
	end
	return Vector3.new(t[1] or 0, t[2] or 0, t[3] or 0)
end

local function cargarPista(animator, id, prioridad, bucle)
	local anim = Instance.new("Animation")
	anim.AnimationId = id
	local ok, pista = pcall(function()
		return animator:LoadAnimation(anim)
	end)
	if not ok then
		warn("[Actor] No se pudo cargar la animación " .. id .. ": " .. tostring(pista))
		return nil
	end
	pista.Priority = prioridad
	pista.Looped = bucle
	return pista
end

-- El modelo ya debe estar dentro de workspace (necesario para cargar animaciones).
function Actor.new(modelo, rol)
	local humanoid = modelo:FindFirstChildOfClass("Humanoid")
	local raiz = modelo:FindFirstChild("HumanoidRootPart")
	if not humanoid or not raiz then
		error(("El personaje '%s' necesita un Humanoid y un HumanoidRootPart"):format(modelo.Name), 0)
	end

	local self = setmetatable({}, Actor)
	self.Modelo = modelo
	self.Rol = rol or modelo.Name
	self.Humanoid = humanoid
	self.Raiz = raiz
	self.Motores = {}
	self.C0Base = {}
	self.Rotaciones = {}
	self.GiroCabeza = 0
	self.Postura = nil -- gesto de reposo (p. ej. "Sostener" cuando lleva algo)
	self.PosturaManual = nil -- gesto de reposo fijado desde la escena (acción "Postura")
	self.PosturaPiernas = nil -- postura de piernas ("Sentado")
	self.TokenGesto = 0
	self.TokenMovimiento = 0
	self.Objeto = nil

	for _, d in ipairs(modelo:GetDescendants()) do
		if d:IsA("BasePart") then
			d.Anchored = false
			d.CanCollide = false
			d.CanTouch = false
			d.CanQuery = false
		elseif d:IsA("LuaSourceContainer") then
			d:Destroy()
		elseif d:IsA("Motor6D") and ARTICULACIONES[d.Name] then
			self.Motores[d.Name] = d
			self.C0Base[d.Name] = d.C0
		end
	end
	raiz.Anchored = true

	humanoid.EvaluateStateMachine = false
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	humanoid.BreakJointsOnDeath = false

	-- Altura de la raíz sobre el suelo y de la cabeza sobre la raíz
	local cadera = humanoid.HipHeight
	if humanoid.RigType ~= Enum.HumanoidRigType.R15 or cadera <= 0 then
		cadera = 2
	end
	self.AlturaRaiz = cadera + raiz.Size.Y / 2
	local cabeza = modelo:FindFirstChild("Head")
	local alturaCabeza = cabeza and (cabeza.Position.Y - raiz.Position.Y) or 1.6
	if alturaCabeza < 0.5 or alturaCabeza > 4 then
		alturaCabeza = 1.6
	end
	self.AlturaCabeza = alturaCabeza
	self.TamanoCabeza = cabeza and cabeza.Size.Y or 1.2
	-- Anchura relativa al R15 estándar (torso de 2 studs): la usan las cámaras
	local torso = modelo:FindFirstChild("UpperTorso")
	self.EscalaAncho = torso and math.max(torso.Size.X / 2, 0.5) or 1
	-- Altura de la cadera respecto a la raíz y grosor del muslo (para sentarse)
	local cadera3d = self.Motores.RightHip
	if cadera3d and cadera3d.Part0 then
		self.AlturaCadera = (cadera3d.Part0.CFrame * cadera3d.C0).Position.Y - raiz.Position.Y
	end
	if not self.AlturaCadera or self.AlturaCadera > 0 or self.AlturaCadera < -2.5 then
		self.AlturaCadera = -self.AlturaRaiz / 3
	end
	local muslo = modelo:FindFirstChild("RightUpperLeg")
	self.GrosorMuslo = muslo and muslo.Size.Z or 1

	-- Animaciones
	local animator = humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		animator = Instance.new("Animator")
		animator.Parent = humanoid
	end
	self.Animator = animator
	self.Pistas = {}
	for nombre, def in pairs(Animaciones.Base) do
		local prioridad = (nombre == "Quieto") and Enum.AnimationPriority.Idle or Enum.AnimationPriority.Movement
		self.Pistas[nombre] = cargarPista(animator, def.Id, prioridad, true)
	end
	self.Clips = {}
	for nombre, id in pairs(Animaciones.Clips) do
		self.Clips[nombre] = cargarPista(animator, id, Enum.AnimationPriority.Action, false)
	end

	self:Base("Quieto")
	self:_iniciarCara()
	return self
end

-- CARA: PARPADEO Y BOCA --------------------------------------------------------
-- Funciona con las caras creadas por Atuendos (SurfaceGui "Cara" en la cabeza).

local azar = Random.new()

function Actor:_iniciarCara()
	local cabeza = self.Modelo:FindFirstChild("Head")
	local cara = cabeza and cabeza:FindFirstChild("Cara")
	if not cara then
		return
	end
	self.Cara = cara
	self.TokenBoca = 0
	self.Parpados = {}
	for _, nombre in ipairs({ "OjoIzq", "OjoDer" }) do
		local ojo = cara:FindFirstChild(nombre)
		local parpado = ojo and ojo:FindFirstChild("Parpado")
		if parpado then
			table.insert(self.Parpados, parpado)
		end
	end
	if #self.Parpados == 0 then
		return
	end
	-- Parpadeo automático cada 2-5 s (a veces doble). Termina al destruir el modelo.
	task.spawn(function()
		task.wait(azar:NextNumber(0.3, 2))
		while cara.Parent do
			self:Parpadear()
			if azar:NextNumber() < 0.15 then
				task.wait(0.28)
				self:Parpadear()
			end
			task.wait(azar:NextNumber(2, 5))
		end
	end)
end

function Actor:Parpadear()
	for _, parpado in ipairs(self.Parpados or {}) do
		local abierto = UDim2.fromScale(1.2, parpado:GetAttribute("Alto") or 0.06)
		local cierra = TweenService:Create(parpado, TweenInfo.new(0.07, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			Size = UDim2.fromScale(1.2, 1.05),
		})
		cierra.Completed:Connect(function()
			task.wait(0.04)
			TweenService:Create(parpado, TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				Size = abierto,
			}):Play()
		end)
		cierra:Play()
	end
end

-- Abre y cierra la boca durante "duracion" segundos (no bloquea).
function Actor:MoverBoca(duracion)
	local cara = self.Cara
	local reposo = cara and cara:FindFirstChild("BocaReposo")
	local habla = cara and cara:FindFirstChild("BocaHabla")
	if not reposo or not habla then
		return 0
	end
	self.TokenBoca = self.TokenBoca + 1
	local token = self.TokenBoca
	task.spawn(function()
		local fin = os.clock() + duracion
		while os.clock() < fin and self.TokenBoca == token and cara.Parent do
			local abre = azar:NextNumber()
			if abre < 0.25 then
				reposo.Visible = true
				habla.Visible = false
			else
				reposo.Visible = false
				habla.Visible = true
				TweenService:Create(habla, TweenInfo.new(0.06), {
					Size = UDim2.fromScale(0.13 + 0.09 * abre, 0.03 + 0.13 * abre),
				}):Play()
			end
			task.wait(azar:NextNumber(0.09, 0.18))
		end
		if self.TokenBoca == token then
			reposo.Visible = true
			habla.Visible = false
		end
	end)
	return duracion
end

--[[
	Mueve la boca siguiendo la envolvente de volumen de un audio (Modulos > Voces):
	una cadena de cifras 0-9, una cada "paso" segundos. "hasta" limita los segundos
	(por ejemplo, para mover los labios solo en la primera frase).
]]
function Actor:MoverBocaEnvolvente(envolvente, paso, hasta)
	local cara = self.Cara
	local reposo = cara and cara:FindFirstChild("BocaReposo")
	local habla = cara and cara:FindFirstChild("BocaHabla")
	if not reposo or not habla or not envolvente then
		return 0
	end
	paso = paso or 0.05
	local total = #envolvente * paso
	if hasta then
		total = math.min(total, hasta)
	end
	self.TokenBoca = self.TokenBoca + 1
	local token = self.TokenBoca
	task.spawn(function()
		local inicio = os.clock()
		local ultimo = -1
		while self.TokenBoca == token and cara.Parent do
			local t = os.clock() - inicio
			if t >= total then
				break
			end
			local i = math.floor(t / paso) + 1
			if i ~= ultimo then
				ultimo = i
				local v = (tonumber(envolvente:sub(i, i)) or 0) / 9
				if v < 0.3 then
					reposo.Visible = true
					habla.Visible = false
				else
					reposo.Visible = false
					habla.Visible = true
					TweenService:Create(habla, TweenInfo.new(paso), {
						Size = UDim2.fromScale(0.12 + 0.1 * v, 0.03 + 0.14 * v),
					}):Play()
				end
			end
			task.wait()
		end
		if self.TokenBoca == token then
			reposo.Visible = true
			habla.Visible = false
		end
	end)
	return total
end

-- Cambia la expresión de la cara (Atuendos.Expresiones). duracion = nil → se mantiene.
-- nombre = nil → vuelve a la cara base.
function Actor:Expresion(nombre, duracion)
	local A = Atuendos()
	if not self.Cara or not A then
		return 0
	end
	self.TokenExpresion = (self.TokenExpresion or 0) + 1
	local token = self.TokenExpresion
	local parpado = A.Expresar(self.Cara, nombre)
	for _, p in ipairs(self.Parpados or {}) do
		local alto = parpado or p:GetAttribute("AltoBase") or 0.06
		p:SetAttribute("Alto", alto)
		TweenService:Create(p, TweenInfo.new(0.15), { Size = UDim2.fromScale(1.2, alto) }):Play()
	end
	if duracion and nombre then
		task.delay(duracion, function()
			if self.TokenExpresion == token then
				self:Expresion(nil)
			end
		end)
	end
	return 0
end

-- POSICIÓN ---------------------------------------------------------------------

function Actor:PosicionSuelo()
	return self.Raiz.Position - Vector3.new(0, self.AlturaRaiz, 0)
end

function Actor:_tween(cf, info)
	if self.Tween then
		self.Tween:Cancel()
	end
	self.Tween = TweenService:Create(self.Raiz, info, { CFrame = cf })
	self.Tween:Play()
	return self.Tween
end

function Actor:_cancelarMovimiento()
	self.TokenMovimiento = self.TokenMovimiento + 1
	if self.Tween then
		self.Tween:Cancel()
		self.Tween = nil
	end
end

-- Coloca al personaje de pie sobre un punto del suelo, mirando en "direccion".
function Actor:Colocar(posSuelo, direccion)
	self:_cancelarMovimiento()
	-- Colocar deja al personaje de pie y en su postura de reposo
	self.PosturaPiernas = nil
	self.TokenGesto = self.TokenGesto + 1
	self:_postura(nil)
	self:_aplicar(0)
	local pos = posSuelo + Vector3.new(0, self.AlturaRaiz, 0)
	local dir = plano(direccion or self.Raiz.CFrame.LookVector)
	self.Raiz.CFrame = CFrame.lookAt(pos, pos + dir)
	self:Base("Quieto")
end

-- Sienta al personaje: "asiento" es el punto central de la superficie del asiento.
function Actor:Sentar(asiento, direccion)
	self:_cancelarMovimiento()
	local dir = plano(direccion or self.Raiz.CFrame.LookVector)
	local y = asiento.Y - self.AlturaCadera + self.GrosorMuslo / 2
	-- la cadera queda un poco hacia el respaldo
	local pos = Vector3.new(asiento.X, y, asiento.Z) - dir * 0.25
	self.Raiz.CFrame = CFrame.lookAt(pos, pos + dir)
	self.PosturaPiernas = "Sentado"
	self:Base("Quieto")
	self:_postura(nil)
	self:_aplicar(0)
end

-- Fija (o quita con nil) un gesto de reposo que se mantiene debajo de los demás gestos.
function Actor:FijarPostura(nombre, tiempo)
	self.PosturaManual = nombre
	self:_postura(nil)
	self:_aplicar(tiempo or 0.3)
end

-- Gira el cuerpo hacia una dirección horizontal. Devuelve la duración.
function Actor:Girar(direccion, tiempo)
	tiempo = tiempo or 0.35
	local pos = self.Raiz.Position
	local objetivo = CFrame.lookAt(pos, pos + plano(direccion))
	-- Si ya mira hacia ahí (menos de 10 grados), no gasta tiempo en girar
	if tiempo > 0 and self.Raiz.CFrame.LookVector:Dot(objetivo.LookVector) > 0.985 then
		return 0
	end
	if tiempo <= 0 then
		if self.Tween then
			self.Tween:Cancel()
		end
		self.Raiz.CFrame = objetivo
		return 0
	end
	self:_tween(objetivo, TweenInfo.new(tiempo, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut))
	return tiempo
end

function Actor:MirarHacia(posicion, tiempo)
	return self:Girar(posicion - self.Raiz.Position, tiempo)
end

-- Desplaza al personaje hasta un punto del suelo. base = "Caminar" o "Correr".
-- Devuelve la duración total (no bloquea).
function Actor:Mover(posSuelo, velocidad, base)
	self:_cancelarMovimiento()
	local token = self.TokenMovimiento
	local destino = posSuelo + Vector3.new(0, self.AlturaRaiz, 0)
	local delta = destino - self.Raiz.Position
	local distancia = Vector3.new(delta.X, 0, delta.Z).Magnitude
	if distancia < 0.05 then
		return 0
	end
	local dir = plano(delta)
	local giro = 0.2
	local duracion = distancia / math.max(velocidad, 0.1)

	self:Base(base, velocidad)
	self:Girar(dir, giro)
	task.delay(giro, function()
		if self.TokenMovimiento ~= token then
			return
		end
		local tween = self:_tween(CFrame.lookAt(destino, destino + dir), TweenInfo.new(duracion, Enum.EasingStyle.Linear))
		tween.Completed:Wait()
		if self.TokenMovimiento == token then
			self:Base("Quieto")
		end
	end)
	return giro + duracion
end

-- ANIMACIONES BASE Y CLIPS -----------------------------------------------------

function Actor:Base(nombre, velocidad)
	local pista = self.Pistas[nombre]
	if self.BaseActual ~= nombre then
		for n, p in pairs(self.Pistas) do
			if n ~= nombre and p.IsPlaying then
				p:Stop(0.25)
			end
		end
		if pista then
			pista:Play(0.25)
		end
		self.BaseActual = nombre
	end
	local def = Animaciones.Base[nombre]
	if pista and def then
		if velocidad and def.VelocidadReferencia then
			pista:AdjustSpeed(velocidad / def.VelocidadReferencia)
		else
			pista:AdjustSpeed(1)
		end
	end
end

-- Vuelve a lanzar la animación base (tras ocultar y mostrar al personaje).
function Actor:Reanudar()
	local actual = self.BaseActual or "Quieto"
	self.BaseActual = nil
	self:Base(actual)
end

function Actor:Clip(nombre)
	local pista = self.Clips[nombre]
	if not pista then
		warn(("[Actor] No existe el clip '%s' en Animaciones.Clips"):format(tostring(nombre)))
		return 0
	end
	pista:Play(0.2)
	if pista.Length > 0 then
		return pista.Length
	end
	return 2
end

-- GESTOS -----------------------------------------------------------------------

function Actor:_postura(fotograma)
	local rot = {}
	local piernas = self.PosturaPiernas and Animaciones.Piernas and Animaciones.Piernas[self.PosturaPiernas]
	if piernas then
		for k, v in pairs(piernas) do
			rot[k] = aVector(v)
		end
	end
	local nombreReposo = self.PosturaManual or self.Postura
	local reposo = nombreReposo and Animaciones.Gestos[nombreReposo]
	if reposo then
		for k, v in pairs(reposo.Fotogramas[1]) do
			rot[k] = aVector(v)
		end
	end
	if fotograma then
		for k, v in pairs(fotograma) do
			rot[k] = aVector(v)
		end
	end
	self.Rotaciones = rot
end

function Actor:_aplicar(tiempo)
	tiempo = tiempo or 0.3
	local info = TweenInfo.new(math.max(tiempo, 0.01), Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	for nombre, motor in pairs(self.Motores) do
		local r = self.Rotaciones[nombre] or Vector3.zero
		local giro = (nombre == "Neck") and self.GiroCabeza or 0
		local objetivo = self.C0Base[nombre] * CFrame.Angles(math.rad(r.X), math.rad(r.Y + giro), math.rad(r.Z))
		if tiempo <= 0 then
			motor.C0 = objetivo
		else
			TweenService:Create(motor, info, { C0 = objetivo }):Play()
		end
	end
end

-- Reproduce un gesto de Animaciones.Gestos. No bloquea; devuelve su duración.
-- mantener = true → se queda en la postura final hasta el siguiente gesto.
function Actor:Gesto(nombre, duracion, mantener)
	local def = Animaciones.Gestos[nombre]
	if not def then
		warn(("[Actor] No existe el gesto '%s' en Animaciones.Gestos"):format(tostring(nombre)))
		return 0
	end
	self.TokenGesto = self.TokenGesto + 1
	local token = self.TokenGesto
	local transicion = def.Transicion or 0.3
	duracion = duracion or def.Duracion or 1.5
	local fotogramas = def.Fotogramas
	local bucle = def.Bucle and #fotogramas > 1

	task.spawn(function()
		local inicio = os.clock()
		local i = 1
		repeat
			self:_postura(fotogramas[i])
			self:_aplicar(transicion)
			task.wait(transicion + (def.Pausa or 0))
			if self.TokenGesto ~= token then
				return
			end
			i = i % #fotogramas + 1
		until not bucle or (os.clock() - inicio) >= duracion

		local restante = duracion - (os.clock() - inicio)
		if restante > 0 then
			task.wait(restante)
		end
		if mantener or self.TokenGesto ~= token then
			return
		end
		self:_postura(nil)
		self:_aplicar(0.35)
	end)
	return duracion
end

-- Vuelve a la postura de reposo.
function Actor:Neutral(tiempo)
	self.TokenGesto = self.TokenGesto + 1
	self:_postura(nil)
	self:_aplicar(tiempo or 0.3)
end

-- Gira solo la cabeza hacia una posición (nil = mirar al frente).
function Actor:MirarCabeza(posicion, tiempo)
	if posicion then
		local rel = self.Raiz.CFrame:PointToObjectSpace(posicion)
		local angulo = math.deg(math.atan2(-rel.X, -rel.Z))
		self.GiroCabeza = math.clamp(angulo, -70, 70)
	else
		self.GiroCabeza = 0
	end
	self:_aplicar(tiempo or 0.3)
end

-- OBJETOS ----------------------------------------------------------------------

local function fijarObjeto(objeto, anclado)
	for _, d in ipairs(objeto:GetDescendants()) do
		if d:IsA("BasePart") then
			d.Anchored = anclado
			d.CanCollide = false
			d.CanTouch = false
			d.CanQuery = false
		end
	end
end

-- Pone un objeto (Model con PrimaryPart) en la mano derecha.
function Actor:Sostener(objeto)
	if self.Objeto and self.Objeto ~= objeto then
		self:Soltar(true)
	end
	local mano = self.Modelo:FindFirstChild("RightHand") or self.Modelo:FindFirstChild("Right Arm")
	if not mano or not objeto.PrimaryPart then
		warn("[Actor] No se puede sostener el objeto: falta la mano o el PrimaryPart del objeto")
		return
	end
	local agarre = mano:FindFirstChild("RightGripAttachment")
	local base = agarre and agarre.WorldCFrame or (mano.CFrame * CFrame.new(0, -mano.Size.Y / 2, 0))
	local offset = objeto:GetAttribute("OffsetAgarre")
	if typeof(offset) ~= "CFrame" then
		offset = CFrame.new()
	end

	fijarObjeto(objeto, true)
	objeto:PivotTo(base * offset)
	local soldadura = Instance.new("WeldConstraint")
	soldadura.Name = "AgarreHistoria"
	soldadura.Part0 = mano
	soldadura.Part1 = objeto.PrimaryPart
	soldadura.Parent = objeto.PrimaryPart
	fijarObjeto(objeto, false)

	self.Objeto = objeto
	self.Postura = "Sostener"
	self:_postura(nil)
	self:_aplicar(0.3)
end

-- Suelta el objeto que lleva (no lo coloca en ningún sitio). Devuelve el objeto.
function Actor:Soltar(sinAplicar)
	local objeto = self.Objeto
	if not objeto then
		return nil
	end
	local soldadura = objeto.PrimaryPart and objeto.PrimaryPart:FindFirstChild("AgarreHistoria")
	if soldadura then
		soldadura:Destroy()
	end
	fijarObjeto(objeto, true)
	self.Objeto = nil
	self.Postura = nil
	if not sinAplicar then
		self:_postura(nil)
		self:_aplicar(0.3)
	end
	return objeto
end

return Actor
]=======] },
	{ Ruta = "StoryTemplate/Modulos", Nombre = "Efectos", Clase = "ModuleScript", Fuente = [=======[
--[[
	EFECTOS · Textos en pantalla, fundidos y filtros de color
	Studio: ReplicatedStorage > StoryTemplate > Modulos > Efectos

	Todo se dibuja dentro del área 9:16 (Guias.Lienzo), así que nunca se sale
	del encuadre vertical. Lo usan las acciones "Texto", "Fundido" y "Filtro".

	ESTILOS DE TEXTO
	  Titulo     → letras grandes amarillas con borde negro (frase final, ganchos)
	  Rotulo     → nota adhesiva amarilla torcida (fechas, lugares: "1974")
	  Icono      → emoji que rebota (💡, ❗, ❓)
	  Subtitulo  → texto blanco abajo, en la zona reservada

	FILTROS
	  Recuerdo   → tonos sepia y apagados (flashbacks)
	  Calido     → luz de tarde
	  Ninguno    → quita el filtro
]]

local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")

local Guias = require(script.Parent:WaitForChild("Guias"))

local Efectos = {}

local AMARILLO = Color3.fromRGB(255, 222, 60)

local function tween(obj, t, props, estilo, direccion)
	local tw = TweenService:Create(obj, TweenInfo.new(t, estilo or Enum.EasingStyle.Quad, direccion or Enum.EasingDirection.Out), props)
	tw:Play()
	return tw
end

local function etiqueta(padre, texto, fuente, color)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Size = UDim2.fromScale(1, 1)
	l.Font = fuente
	l.TextScaled = true
	l.TextWrapped = true
	l.TextColor3 = color
	l.Text = texto
	l.Parent = padre
	return l
end

-- Entrada con rebote (escala 0 → 1.12 → 1)
local function aparecer(obj)
	local escala = Instance.new("UIScale")
	escala.Scale = 0
	escala.Parent = obj
	local t1 = tween(escala, 0.18, { Scale = 1.12 }, Enum.EasingStyle.Back)
	t1.Completed:Connect(function()
		tween(escala, 0.1, { Scale = 1 })
	end)
	return escala
end

-- Desvanece todos los textos, fondos y bordes de "obj" y lo destruye.
local function desvanecer(obj, t)
	t = t or 0.25
	for _, d in ipairs(obj:GetDescendants()) do
		if d:IsA("TextLabel") then
			tween(d, t, { TextTransparency = 1, TextStrokeTransparency = 1, BackgroundTransparency = 1 })
		elseif d:IsA("Frame") then
			tween(d, t, { BackgroundTransparency = 1 })
		elseif d:IsA("UIStroke") then
			tween(d, t, { Transparency = 1 })
		end
	end
	if obj:IsA("Frame") then
		tween(obj, t, { BackgroundTransparency = 1 })
	end
	task.delay(t + 0.05, function()
		obj:Destroy()
	end)
end

--[[
	Muestra un texto. op (opcional):
	  Posicion = Vector2 (escala 0-1 del área 9:16)
	  Tamano   = Vector2 (escala)
	  Color    = Color3
	  Giro     = grados
	Devuelve el objeto creado. Si duracion es nil se queda hasta Efectos.Limpiar().
]]
function Efectos.Texto(texto, estilo, duracion, op)
	local lienzo = Guias.Lienzo
	if not lienzo then
		return nil
	end
	op = op or {}
	estilo = estilo or "Titulo"
	local raiz

	if estilo == "Rotulo" then
		local pos = op.Posicion or Vector2.new(0.5, 0.11)
		local tam = op.Tamano or Vector2.new(0.38, 0.1)
		raiz = Instance.new("Frame")
		raiz.BackgroundTransparency = 1
		raiz.AnchorPoint = Vector2.new(0.5, 0.5)
		raiz.Position = UDim2.fromScale(pos.X, pos.Y)
		raiz.Size = UDim2.fromScale(tam.X, tam.Y)
		raiz.Rotation = op.Giro or -4
		raiz.ZIndex = 20
		local sombra = Instance.new("Frame")
		sombra.Size = UDim2.fromScale(1, 1)
		sombra.Position = UDim2.new(0, 5, 0, 6)
		sombra.BackgroundColor3 = Color3.new(0, 0, 0)
		sombra.BackgroundTransparency = 0.7
		sombra.BorderSizePixel = 0
		sombra.ZIndex = 1
		sombra.Parent = raiz
		local nota = Instance.new("Frame")
		nota.Size = UDim2.fromScale(1, 1)
		nota.BackgroundColor3 = op.Color or AMARILLO
		nota.BorderSizePixel = 0
		nota.ZIndex = 2
		nota.Parent = raiz
		local banda = Instance.new("Frame")
		banda.Size = UDim2.fromScale(1, 0.14)
		banda.BackgroundColor3 = (op.Color or AMARILLO):Lerp(Color3.new(0.6, 0.45, 0), 0.25)
		banda.BorderSizePixel = 0
		banda.ZIndex = 1
		banda.Parent = nota
		local margen = Instance.new("Frame")
		margen.BackgroundTransparency = 1
		margen.Size = UDim2.fromScale(0.86, 0.72)
		margen.Position = UDim2.fromScale(0.07, 0.2)
		margen.ZIndex = 2
		margen.Parent = nota
		etiqueta(margen, texto, Enum.Font.PermanentMarker, Color3.fromRGB(55, 40, 20))
	elseif estilo == "Icono" then
		raiz = Instance.new("Frame")
		raiz.BackgroundTransparency = 1
		raiz.AnchorPoint = Vector2.new(0.5, 0.5)
		local pos = op.Posicion or Vector2.new(0.5, 0.2)
		local tam = op.Tamano or Vector2.new(0.22, 0.12)
		raiz.Position = UDim2.fromScale(pos.X, pos.Y)
		raiz.Size = UDim2.fromScale(tam.X, tam.Y)
		raiz.ZIndex = 20
		local l = etiqueta(raiz, texto, Enum.Font.GothamBold, Color3.new(1, 1, 1))
		l.ZIndex = 21
	elseif estilo == "Subtitulo" then
		raiz = Instance.new("Frame")
		raiz.BackgroundTransparency = 1
		raiz.AnchorPoint = Vector2.new(0.5, 0.5)
		raiz.Position = UDim2.fromScale(0.5, 0.91)
		raiz.Size = UDim2.fromScale(0.9, 0.09)
		raiz.ZIndex = 20
		local l = etiqueta(raiz, texto, Enum.Font.GothamBold, Color3.new(1, 1, 1))
		l.TextStrokeTransparency = 0
		l.ZIndex = 21
	else -- Titulo
		raiz = Instance.new("Frame")
		raiz.BackgroundTransparency = 1
		raiz.AnchorPoint = Vector2.new(0.5, 0.5)
		local pos = op.Posicion or Vector2.new(0.5, 0.3)
		local tam = op.Tamano or Vector2.new(0.92, 0.2)
		raiz.Position = UDim2.fromScale(pos.X, pos.Y)
		raiz.Size = UDim2.fromScale(tam.X, tam.Y)
		raiz.Rotation = op.Giro or -3
		raiz.ZIndex = 20
		local l = etiqueta(raiz, texto, Enum.Font.FredokaOne, op.Color or AMARILLO)
		l.ZIndex = 21
		local borde = Instance.new("UIStroke")
		borde.Color = Color3.fromRGB(20, 15, 10)
		borde.Thickness = 4
		borde.Parent = l
	end

	raiz.Name = "Texto_" .. estilo
	raiz.Parent = lienzo
	if estilo ~= "Subtitulo" then
		aparecer(raiz)
	end
	if estilo == "Icono" then
		-- pequeño rebote continuo
		task.spawn(function()
			local base = raiz.Position
			while raiz.Parent do
				tween(raiz, 0.35, { Position = base - UDim2.fromScale(0, 0.012) }, Enum.EasingStyle.Sine)
				task.wait(0.35)
				if not raiz.Parent then
					break
				end
				tween(raiz, 0.35, { Position = base }, Enum.EasingStyle.Sine)
				task.wait(0.35)
			end
		end)
	end
	if duracion then
		task.delay(duracion, function()
			if raiz.Parent then
				desvanecer(raiz)
			end
		end)
	end
	return raiz
end

-- Quita todos los textos que haya en pantalla.
function Efectos.Limpiar()
	if not Guias.Lienzo then
		return
	end
	for _, hijo in ipairs(Guias.Lienzo:GetChildren()) do
		if hijo.Name:sub(1, 6) == "Texto_" then
			desvanecer(hijo, 0.15)
		end
	end
end

--[[
	Fundido a un color y vuelta. Devuelve el tiempo hasta que la pantalla está
	totalmente cubierta (entrada + mantener): en ese momento se puede cambiar de
	entorno sin que se note. La salida ocurre sola después.
]]
function Efectos.Fundido(color, entrada, mantener, salida)
	local velo = Guias.Velo
	if not velo then
		return 0
	end
	entrada = entrada or 0.3
	mantener = mantener or 0.1
	salida = salida or 0.35
	if color == "Blanco" then
		velo.BackgroundColor3 = Color3.new(1, 1, 1)
	elseif typeof(color) == "Color3" then
		velo.BackgroundColor3 = color
	else
		velo.BackgroundColor3 = Color3.new(0, 0, 0)
	end
	velo.BackgroundTransparency = 1
	tween(velo, entrada, { BackgroundTransparency = 0 }, Enum.EasingStyle.Sine)
	task.delay(entrada + mantener, function()
		tween(velo, salida, { BackgroundTransparency = 1 }, Enum.EasingStyle.Sine)
	end)
	return entrada + mantener
end

local FILTROS = {
	Recuerdo = { Saturation = -0.65, Contrast = 0.12, Brightness = 0.04, TintColor = Color3.fromRGB(255, 226, 180) },
	Calido = { Saturation = 0.05, Contrast = 0.05, Brightness = 0.02, TintColor = Color3.fromRGB(255, 238, 215) },
}

-- Aplica (o quita con "Ninguno"/nil) un filtro de color a toda la imagen.
function Efectos.Filtro(nombre)
	local cc = Lighting:FindFirstChild("FiltroHistoria")
	local def = FILTROS[nombre or ""]
	if not def then
		if cc then
			cc:Destroy()
		end
		return
	end
	if not cc then
		cc = Instance.new("ColorCorrectionEffect")
		cc.Name = "FiltroHistoria"
		cc.Parent = Lighting
	end
	for k, v in pairs(def) do
		cc[k] = v
	end
end

-- Tono de color propio de cada entorno (atributos Tinte / Saturacion del Model).
function Efectos.TonoEntorno(tinte, saturacion)
	local cc = Lighting:FindFirstChild("TonoEntorno")
	if not tinte and not saturacion then
		if cc then
			cc:Destroy()
		end
		return
	end
	if not cc then
		cc = Instance.new("ColorCorrectionEffect")
		cc.Name = "TonoEntorno"
		cc.Parent = Lighting
	end
	cc.TintColor = tinte or Color3.new(1, 1, 1)
	cc.Saturation = saturacion or 0
end

return Efectos
]=======] },
	{ Ruta = "StoryTemplate/Modulos", Nombre = "Voces", Clase = "ModuleScript", Fuente = [=======[
--[[
	VOCES · Datos de cada audio de la historia
	Studio: ReplicatedStorage > StoryTemplate > Modulos > Voces

	GENERADO por Audio/analizar_audio.py a partir de Audio/voces.json y los WAV.
	No lo edites a mano: cambia voces.json (por ejemplo el Id) y vuelve a ejecutar
	  python Audio/analizar_audio.py  y  node build.js

	Id         → id del audio subido a Roblox ("rbxassetid://..."). Vacío = sin sonido,
	             pero la escena mantiene los mismos tiempos (útil para montar el audio después).
	Duracion   → segundos del archivo.
	Segmentos  → tramos con voz { inicio, fin } en segundos desde el inicio del audio.
	Envolvente → volumen cada Paso segundos (0-9) para mover la boca.
]]

return {
	Paso = 0.05,
	postit1 = {
		Archivo = "postit1.WAV",
		Id = "rbxassetid://112400743441885",
		Personaje = "Art",
		Tipo = "Narrador",
		Escena = 1,
		Duracion = 4.203,
		Texto = "¿Te interesa saber cómo se creó el primer Post-it? ¡Todo comenzó con un pegamento que parecía un fracaso!",
		Segmentos = { { 0.18, 1.96 }, { 2.38, 4.08 } },
		Envolvente = "1116978876588996310887574999837895893262201111069968875968879867777758757968838733100",
	},
	postit2 = {
		Archivo = "postit2.WAV",
		Id = "rbxassetid://73048597437669",
		Personaje = "Spencer",
		Tipo = "Dialogo",
		Escena = 2,
		Duracion = 4.203,
		Texto = "¡He creado un pegamento especial! Se pega, pero puedes quitarlo sin problemas.",
		Segmentos = { { 0.52, 1.82 }, { 2.0, 4.1 } },
		Envolvente = "0000002211783799886476655375264477742111486996982167725976442786564454466755444212210",
	},
	postit3 = {
		Archivo = "postit3.WAV",
		Id = "rbxassetid://121842356559664",
		Personaje = "Art",
		Tipo = "Dialogo",
		Escena = 2,
		Duracion = 1.3,
		Texto = "¿Y para qué sirve eso?",
		Segmentos = { { 0.36, 1.2 } },
		Envolvente = "000011184886396597997475200",
	},
	postit4 = {
		Archivo = "postit4.WAV",
		Id = "rbxassetid://135160250082727",
		Personaje = "Art",
		Tipo = "Narrador",
		Escena = 3,
		Duracion = 4.04,
		Texto = "En 1974 tenía un problema: ¡mis marcapáginas siempre acababan en el suelo!",
		Segmentos = { { 0.28, 1.94 }, { 2.26, 3.94 } },
		Envolvente = "000114999889878758878689487779985999774111110799797787538956997877899776658986410",
	},
	postit5 = {
		Archivo = "postit5.WAV",
		Id = "rbxassetid://140254214115431",
		Personaje = "Art",
		Tipo = "Dialogo",
		Escena = 3,
		Duracion = 1.068,
		Texto = "¡Otra vez no!",
		Segmentos = { { 0.26, 0.94 } },
		Envolvente = "0011188798966899885110",
	},
	postit6 = {
		Archivo = "postit6.WAV",
		Id = "rbxassetid://7474276044230",
		Personaje = "Art",
		Tipo = "Narrador",
		Escena = 4,
		Duracion = 2.879,
		Texto = "Entonces recordé aquel extraño pegamento y tuve una idea.",
		Segmentos = { { 0.32, 2.8 } },
		Envolvente = "0000113787599998778897786387748879876488876517897778987410",
	},
	postit7 = {
		Archivo = "postit7.WAV",
		Id = "rbxassetid://118988480490208",
		Personaje = "Art",
		Tipo = "Dialogo",
		Escena = 4,
		Duracion = 2.113,
		Texto = "¡Espera! ¿Y si lo utilizo para crear un marcapáginas?",
		Segmentos = { { 0.22, 1.84 } },
		Envolvente = "0011772988465875968798489878663956763201100",
	},
	postit8 = {
		Archivo = "postit8.WAV",
		Id = "rbxassetid://79697612206428",
		Personaje = "Art",
		Tipo = "Dialogo",
		Escena = 5,
		Duracion = 2.879,
		Texto = "¡Funciona! ¡No se cae y puedo quitarlo sin romper nada!",
		Segmentos = { { 0.16, 1.0 }, { 1.36, 2.64 } },
		Envolvente = "1116979966327785988511110016999983895688875586867988411100",
	},
	postit9 = {
		Archivo = "postit9.WAV",
		Id = "rbxassetid://105692879107754",
		Personaje = "Art",
		Tipo = "Narrador",
		Escena = 5,
		Duracion = 5.433,
		Texto = "Después empezamos a utilizarlos para dejar mensajes. ¡Habíamos encontrado algo mucho más útil que un simple marcapáginas!",
		Segmentos = { { 0.22, 2.08 }, { 2.5, 3.86 }, { 4.02, 5.24 } },
		Envolvente = "0011563967758858576796964268974877569568540112222189885777689977774886586798521129999977698888676773677541110",
	},
	postit10 = {
		Archivo = "postit10.WAV",
		Id = "rbxassetid://131840630034624",
		Personaje = "Art",
		Tipo = "Narrador",
		Escena = 6,
		Duracion = 8.754,
		Texto = "En 1980 llegaron oficialmente a las tiendas como Post-it. ¡Y todo gracias a un pegamento que parecía inútil!",
		Segmentos = { { 0.36, 1.46 }, { 1.72, 3.62 }, { 4.24, 6.4 }, { 7.36, 8.58 } },
		Envolvente = "00001117888999956978584876885101104999888666598788679886369887278729842732100001100018689797895767876898788677418387648987772664100000000000002211157468644784655465466653331200",
	},
	postit11 = {
		Archivo = "postit11.WAV",
		Id = "rbxassetid://117221469329445",
		Personaje = "Spencer",
		Tipo = "Dialogo",
		Escena = 6,
		Duracion = 1.649,
		Texto = "¡Al final sí que servía para algo!",
		Segmentos = { { 0.24, 1.48 } },
		Envolvente = "232116757965589575646646776443120",
	},
}
]=======] },
	{ Ruta = "StoryTemplate/Modulos", Nombre = "Animaciones", Clase = "ModuleScript", Fuente = [=======[
--[[
	ANIMACIONES · Biblioteca de animaciones reutilizables
	Studio: ReplicatedStorage > StoryTemplate > Modulos > Animaciones

	Hay tres tipos:

	1) Base   → animaciones en bucle del cuerpo entero (quieto, caminar, correr).
	            Son las animaciones oficiales de Roblox para R15: no hay que subir nada.

	2) Clips  → animaciones de catálogo que se reproducen una vez (acción "Animacion").
	            Puedes añadir tus propias animaciones subidas: Nombre = "rbxassetid://ID".

	3) Gestos → posturas "procedurales": giran articulaciones del personaje encima de la
	            animación base. No necesitan subir nada y cuestan casi cero recursos.
	            Cada gesto es una lista de Fotogramas; cada fotograma indica, para cada
	            articulación R15, una rotación {X, Y, Z} en grados.

	            Articulaciones disponibles:
	              Neck (cuello), Waist (cintura),
	              RightShoulder, RightElbow, RightWrist (brazo derecho),
	              LeftShoulder,  LeftElbow,  LeftWrist  (brazo izquierdo)

	            Guía rápida de ejes:
	              Shoulder X+  → levanta el brazo hacia delante
	              RightShoulder Z+ / LeftShoulder Z-  → abre el brazo hacia el lado
	              Elbow X+     → dobla el codo hacia delante
	              Neck X+ / X- → mira arriba / abajo     Neck Y+ → gira la cabeza a su izquierda
	              Waist X+ / X- → inclina el torso atrás / adelante

	            Opciones de cada gesto:
	              Transicion = segundos para pasar de un fotograma al siguiente
	              Pausa      = segundos que se mantiene cada fotograma (solo en bucles)
	              Bucle      = true → alterna los fotogramas hasta que acaba la duración
	              Duracion   = duración por defecto si el paso no indica una
]]

local Animaciones = {}

-- 1) BASE ----------------------------------------------------------------------
-- VelocidadReferencia = studs/s a la que la animación se ve natural (ajusta los pies).
Animaciones.Base = {
	Quieto = { Id = "rbxassetid://507766388" },
	Caminar = { Id = "rbxassetid://507777826", VelocidadReferencia = 8 },
	Correr = { Id = "rbxassetid://507767714", VelocidadReferencia = 16 },
}

-- 2) CLIPS ---------------------------------------------------------------------
Animaciones.Clips = {
	Saludar = "rbxassetid://507770239",
	Reir = "rbxassetid://507770818",
	Celebrar = "rbxassetid://507770677",
}

-- 3) GESTOS --------------------------------------------------------------------
Animaciones.Gestos = {
	-- Gestos de manos al hablar (bucle)
	Hablar = {
		Bucle = true,
		Transicion = 0.35,
		Pausa = 0.05,
		Duracion = 2,
		Fotogramas = {
			{ RightShoulder = { 25, 0, 6 }, RightElbow = { 60, 0, 0 }, Neck = { 4, 0, 0 } },
			{
				RightShoulder = { 32, 0, 14 },
				RightElbow = { 45, 0, 0 },
				LeftShoulder = { 18, 0, -6 },
				LeftElbow = { 35, 0, 0 },
				Neck = { -3, 4, 0 },
			},
		},
	},

	-- Brazo derecho extendido señalando al frente
	Senalar = {
		Transicion = 0.25,
		Duracion = 1.5,
		Fotogramas = {
			{ RightShoulder = { 90, 0, 0 }, RightElbow = { 5, 0, 0 }, RightWrist = { 0, 0, 0 } },
		},
	},

	-- Manos arriba, cabeza y torso hacia atrás
	Sorpresa = {
		Transicion = 0.15,
		Duracion = 1.2,
		Fotogramas = {
			{
				RightShoulder = { 10, 0, 95 },
				LeftShoulder = { 10, 0, -95 },
				RightElbow = { 60, 0, 0 },
				LeftElbow = { 60, 0, 0 },
				Neck = { 15, 0, 0 },
				Waist = { 8, 0, 0 },
			},
		},
	},

	-- Extiende el brazo para dar algo
	Entregar = {
		Transicion = 0.35,
		Duracion = 1,
		Fotogramas = {
			{ RightShoulder = { 70, 0, 0 }, RightElbow = { 15, 0, 0 }, Waist = { -5, 0, 0 } },
		},
	},

	-- Extiende el brazo para recibir algo
	Recibir = {
		Transicion = 0.35,
		Duracion = 0.8,
		Fotogramas = {
			{ RightShoulder = { 60, 0, 0 }, RightElbow = { 20, 0, 0 }, LeftShoulder = { 30, 0, 0 } },
		},
	},

	-- Se inclina para coger o dejar algo del suelo / mesa
	Agacharse = {
		Transicion = 0.35,
		Duracion = 0.8,
		Fotogramas = {
			{
				Waist = { -25, 0, 0 },
				Neck = { -15, 0, 0 },
				RightShoulder = { 50, 0, 0 },
				RightElbow = { 20, 0, 0 },
			},
		},
	},

	-- Postura de reposo mientras lleva un objeto (se aplica sola)
	Sostener = {
		Transicion = 0.3,
		Fotogramas = {
			{ RightShoulder = { 30, 0, 0 }, RightElbow = { 60, 0, 0 } },
		},
	},

	-- Asentir con la cabeza (sí)
	Asentir = {
		Bucle = true,
		Transicion = 0.18,
		Duracion = 1.2,
		Fotogramas = {
			{ Neck = { -14, 0, 0 } },
			{ Neck = { 6, 0, 0 } },
		},
	},

	-- Negar con la cabeza (no)
	Negar = {
		Bucle = true,
		Transicion = 0.18,
		Duracion = 1.2,
		Fotogramas = {
			{ Neck = { 0, 22, 0 } },
			{ Neck = { 0, -22, 0 } },
		},
	},

	-- Mano a la barbilla, pensando
	Pensar = {
		Transicion = 0.4,
		Duracion = 2,
		Fotogramas = {
			{ RightShoulder = { 40, 0, -10 }, RightElbow = { 125, 0, 0 }, Neck = { 8, 10, 0 } },
		},
	},
	-- Brazo estirado hacia delante y arriba: pegar o despegar algo de una pared
	Pegar = {
		Transicion = 0.3,
		Duracion = 0.9,
		Fotogramas = {
			{ RightShoulder = { 105, 0, 0 }, RightElbow = { 10, 0, 0 }, Neck = { 8, 0, 0 } },
		},
	},

	-- Alcanzar algo de una mesa (de pie o sentado)
	AlcanzarMesa = {
		Transicion = 0.3,
		Duracion = 0.8,
		Fotogramas = {
			{ RightShoulder = { 55, 0, 0 }, RightElbow = { 25, 0, 0 }, Waist = { -12, 0, 0 }, Neck = { -15, 0, 0 } },
		},
	},

	-- Enseñar un objeto que lleva en la mano (a la altura de la cara)
	Mostrar = {
		Transicion = 0.3,
		Duracion = 1.5,
		Fotogramas = {
			{ RightShoulder = { 80, 0, 12 }, RightElbow = { 70, 0, 0 }, Neck = { -4, 0, 0 } },
		},
	},

	-- Mirar con atención algo que tiene en la mano
	Examinar = {
		Transicion = 0.35,
		Duracion = 1.5,
		Fotogramas = {
			{ RightShoulder = { 65, 0, -8 }, RightElbow = { 85, 0, 0 }, Neck = { -10, 0, 8 } },
		},
	},

	-- ¡Idea! Dedo índice arriba junto a la cara
	Idea = {
		Transicion = 0.18,
		Duracion = 1.4,
		Fotogramas = {
			{ RightShoulder = { 70, 0, 20 }, RightElbow = { 100, 0, 0 }, Neck = { 10, 0, 0 }, Waist = { 4, 0, 0 } },
		},
	},

	-- Encogerse de hombros, palmas hacia arriba
	Encogerse = {
		Transicion = 0.25,
		Duracion = 1,
		Fotogramas = {
			{
				RightShoulder = { 20, 0, 35 },
				LeftShoulder = { 20, 0, -35 },
				RightElbow = { 80, 0, 0 },
				LeftElbow = { 80, 0, 0 },
				Neck = { 0, 0, 8 },
			},
		},
	},

	-- Cabeza y torso hacia abajo (mirar al suelo)
	MirarAbajo = {
		Transicion = 0.35,
		Duracion = 1.2,
		Fotogramas = {
			{ Neck = { -30, 0, 0 }, Waist = { -10, 0, 0 } },
		},
	},

	-- Lamentarse: mano izquierda a la frente, cabeza baja
	Lamentarse = {
		Transicion = 0.3,
		Duracion = 1.2,
		Fotogramas = {
			{ LeftShoulder = { 100, 0, -15 }, LeftElbow = { 115, 0, 0 }, Neck = { -18, 0, 0 } },
		},
	},

	-- Celebrar con el brazo derecho en alto
	BrazoArriba = {
		Transicion = 0.22,
		Duracion = 1.2,
		Fotogramas = {
			{ RightShoulder = { 160, 0, 10 }, RightElbow = { 10, 0, 0 }, Neck = { 8, 0, 0 } },
		},
	},

	-- Untar pegamento con un pincel (bucle)
	Untar = {
		Bucle = true,
		Transicion = 0.22,
		Duracion = 2,
		Fotogramas = {
			{ RightShoulder = { 50, 0, -5 }, RightElbow = { 40, 0, 0 }, Waist = { -10, 0, 0 }, Neck = { -18, 0, 0 } },
			{ RightShoulder = { 45, 0, 12 }, RightElbow = { 52, 0, 0 }, Waist = { -10, 0, 0 }, Neck = { -18, 0, 0 } },
		},
	},
}

-- 4) POSTURAS DE PIERNAS --------------------------------------------------------
-- Se mantienen debajo de cualquier gesto (acción "Sentar" / "Levantar").
-- Articulaciones: RightHip, LeftHip (X+ = muslo hacia delante), RightKnee, LeftKnee (X- = dobla la rodilla).
Animaciones.Piernas = {
	Sentado = {
		RightHip = { 90, 0, 0 },
		LeftHip = { 90, 0, 0 },
		RightKnee = { -90, 0, 0 },
		LeftKnee = { -90, 0, 0 },
	},
}

return Animaciones
]=======] },
	{ Ruta = "StoryTemplate/Modulos", Nombre = "Camaras", Clase = "ModuleScript", Fuente = [=======[
--[[
	CAMARAS · Planos de cámara reutilizables pensados para vídeo vertical 9:16
	Studio: ReplicatedStorage > StoryTemplate > Modulos > Camaras

	Los planos automáticos calculan la posición de la cámara a partir de los
	personajes, de modo que siempre quedan dentro del encuadre vertical y de la
	zona segura (Margenes). Los planos "Fija" usan los puntos de cámara
	(Cam_General, Cam_Izquierda, Cam_Derecha, Cam_Alta) de cada entorno.

	PLANOS
	  General       → todos los personajes visibles, de cuerpo entero.
	  Medio         → uno o varios personajes de cintura/rodilla para arriba.
	  PrimerPlano   → cara y hombros de un personaje.
	  Personaje     → cámara enfocada en un personaje (Seguir = true lo acompaña).
	  DosPersonajes → dos personajes vistos de lado, ideal para conversaciones.
	  Fija          → un punto de cámara del entorno (Marca = "Cam_...").

	OPCIONES (en el paso "Camara" de la escena, todas opcionales)
	  Actor = "Rol"                 Actores = {"RolA", "RolB"}
	  Encuadre = "Cuerpo" | "Medio" | "Cara"   (cambia lo que entra en plano)
	  Angulo = grados               (gira la cámara alrededor; + = hacia la derecha)
	  Inclinacion = grados          (+ = cámara más alta mirando hacia abajo)
	  Holgura = 1.2                 (multiplica la distancia; >1 = más aire)
	  Seguir = true                 (recalcula cada fotograma: sigue al personaje)
	  Transicion = segundos         (0 = corte)
	  Acercar = studs, TiempoAcercar = segundos   (zoom lento hacia delante)
	  FOV = grados                  (campo de visión solo para este plano)
	  Marca = "Cam_..."             (solo para Plano = "Fija")
]]

local Camaras = {}

-- Zona segura del 9:16 (fracciones de pantalla). Inferior deja sitio a subtítulos.
Camaras.Margenes = { Superior = 0.06, Inferior = 0.14, Lateral = 0.08 }

Camaras.Planos = {
	General = { Tipo = "Grupo", Encuadre = "Cuerpo", Inclinacion = 8, Holgura = 1.2 },
	Medio = { Tipo = "Grupo", Encuadre = "Medio", Inclinacion = 3 },
	PrimerPlano = { Tipo = "Individual", Encuadre = "Cara", Inclinacion = 0, Angulo = 15 },
	Personaje = { Tipo = "Individual", Encuadre = "Medio", Inclinacion = 3, Angulo = 20 },
	DosPersonajes = { Tipo = "Pareja", Encuadre = "Medio", Inclinacion = 3, Angulo = 25 },
	Fija = { Tipo = "Marca", Marca = "Cam_General" },
}

local function plano(v)
	local p = Vector3.new(v.X, 0, v.Z)
	if p.Magnitude < 1e-3 then
		return Vector3.new(0, 0, -1)
	end
	return p.Unit
end

local function girarY(v, grados)
	if not grados or grados == 0 then
		return v
	end
	return CFrame.Angles(0, math.rad(grados), 0):VectorToWorldSpace(v)
end

-- Añade a "lista" las esquinas de la zona que debe verse de un actor.
local function puntosActor(actor, encuadre, derecha, lista)
	local raiz = actor.Raiz.Position
	local yCabeza = raiz.Y + actor.AlturaCabeza
	local arriba = yCabeza + actor.TamanoCabeza / 2 + 0.3
	local abajo, ancho
	if encuadre == "Cuerpo" then
		abajo = raiz.Y - actor.AlturaRaiz - 0.2
		ancho = 1.4
	elseif encuadre == "Cara" then
		abajo = yCabeza - actor.TamanoCabeza / 2 - 0.9
		ancho = 0.75
	else -- "Medio"
		abajo = raiz.Y - 0.5
		ancho = 1.1
	end
	ancho = ancho * (actor.EscalaAncho or 1)
	local base = Vector3.new(raiz.X, 0, raiz.Z)
	for _, y in ipairs({ arriba, abajo }) do
		for _, s in ipairs({ -1, 1 }) do
			table.insert(lista, base + Vector3.new(0, y, 0) + derecha * (ancho * s))
		end
	end
end

--[[
	Calcula el CFrame de cámara para que todos los "puntos" entren en la zona segura.
	direccion   = dirección horizontal desde la cámara hacia los sujetos
	fov         = campo de visión vertical (grados)
	aspecto     = ancho / alto del encuadre (9/16)
]]
function Camaras.Encuadrar(puntos, direccion, fov, aspecto, margenes, inclinacion, holgura)
	local adelante = plano(direccion)
	local pitch = math.rad(inclinacion or 0)
	local F = (adelante * math.cos(pitch) - Vector3.yAxis * math.sin(pitch)).Unit
	local R = F:Cross(Vector3.yAxis).Unit
	local U = R:Cross(F).Unit

	local o = puntos[1]
	local minX, maxX, minY, maxY, minZ, maxZ = math.huge, -math.huge, math.huge, -math.huge, math.huge, -math.huge
	for _, p in ipairs(puntos) do
		local d = p - o
		local x, y, z = d:Dot(R), d:Dot(U), d:Dot(F)
		minX, maxX = math.min(minX, x), math.max(maxX, x)
		minY, maxY = math.min(minY, y), math.max(maxY, y)
		minZ, maxZ = math.min(minZ, z), math.max(maxZ, z)
	end
	local centro = o + R * ((minX + maxX) / 2) + U * ((minY + maxY) / 2) + F * ((minZ + maxZ) / 2)
	local semiAncho = (maxX - minX) / 2
	local semiAlto = (maxY - minY) / 2
	local profundidad = (maxZ - minZ) / 2

	local tanV = math.tan(math.rad(fov) / 2)
	local tanH = tanV * aspecto
	local abajo = -1 + 2 * margenes.Inferior
	local arriba = 1 - 2 * margenes.Superior
	local lateral = 1 - 2 * margenes.Lateral

	local dV = semiAlto / (tanV * (arriba - abajo) / 2)
	local dH = semiAncho / (tanH * lateral)
	local distancia = math.max(dV, dH, 2) * (holgura or 1) + profundidad
	local medio = (arriba + abajo) / 2
	local pos = centro - F * distancia - U * (medio * distancia * tanV)
	return CFrame.lookAt(pos, pos + F), distancia
end

local function resolverActores(op, ctx, tipo)
	local roles = op.Actores or (op.Actor and { op.Actor })
	local lista = {}
	if roles then
		for _, rol in ipairs(roles) do
			table.insert(lista, ctx:ActorVisible(rol))
		end
		return lista
	end
	local visibles = ctx:ActoresVisibles()
	if tipo == "Grupo" then
		return visibles
	elseif tipo == "Pareja" then
		for i = 1, math.min(2, #visibles) do
			table.insert(lista, visibles[i])
		end
		return lista
	end
	local prota = ctx.Actores.Protagonista
	if prota and prota.Modelo.Parent then
		return { prota }
	end
	if visibles[1] then
		table.insert(lista, visibles[1])
	end
	return lista
end

local function direccionGrupo(actores, ctx)
	local centro, mirada = Vector3.zero, Vector3.zero
	for _, a in ipairs(actores) do
		centro = centro + a.Raiz.Position
		mirada = mirada + a.Raiz.CFrame.LookVector
	end
	centro = centro / #actores
	if ctx.Audiencia then
		return plano(centro - ctx.Audiencia)
	end
	return plano(-mirada)
end

local function marcaFija(ctx, nombre)
	local m = ctx:Marca(nombre)
	if not m then
		error(("No existe el punto de cámara '%s' en el entorno actual"):format(tostring(nombre)), 0)
	end
	local cf = m.CFrame
	return function()
		return cf
	end
end

-- Devuelve una función que calcula el CFrame de la cámara para el plano pedido.
function Camaras.Preparar(p, ctx, fov, aspecto)
	local nombrePlano = p.Plano or "General"
	local def = Camaras.Planos[nombrePlano]
	if not def then
		error(("Plano de cámara desconocido: '%s'"):format(tostring(nombrePlano)), 0)
	end
	local op = {}
	for k, v in pairs(def) do
		op[k] = v
	end
	for k, v in pairs(p) do
		op[k] = v
	end

	if def.Tipo == "Marca" then
		return marcaFija(ctx, op.Marca)
	end

	local tipo = def.Tipo
	local actores = resolverActores(op, ctx, tipo)
	if #actores == 0 then
		-- Nadie en escena todavía: usa el punto de cámara general del entorno.
		return marcaFija(ctx, "Cam_General")
	end
	if tipo == "Pareja" and #actores < 2 then
		tipo = "Grupo"
	end

	local direccion
	if tipo == "Individual" then
		direccion = plano(-actores[1].Raiz.CFrame.LookVector)
	elseif tipo == "Pareja" then
		local A, B = actores[1].Raiz.Position, actores[2].Raiz.Position
		local ab = plano(B - A)
		local perp = Vector3.new(-ab.Z, 0, ab.X)
		local ref
		if ctx.Audiencia then
			ref = ctx.Audiencia - (A + B) / 2
		else
			ref = actores[1].Raiz.CFrame.LookVector + actores[2].Raiz.CFrame.LookVector
		end
		if perp:Dot(ref) < 0 then
			perp = -perp
		end
		direccion = -perp
	else
		direccion = direccionGrupo(actores, ctx)
	end
	direccion = girarY(direccion, op.Angulo)

	local function calcular()
		local puntos = {}
		local derecha = plano(direccion):Cross(Vector3.yAxis)
		for _, a in ipairs(actores) do
			puntosActor(a, op.Encuadre, derecha, puntos)
		end
		local cf = Camaras.Encuadrar(puntos, direccion, fov, aspecto, Camaras.Margenes, op.Inclinacion, op.Holgura)
		return cf
	end

	if op.Seguir then
		return calcular
	end
	local fijo = calcular()
	return function()
		return fijo
	end
end

return Camaras
]=======] },
	{ Ruta = "StoryTemplate/Modulos", Nombre = "Guias", Clase = "ModuleScript", Fuente = [=======[
--[[
	GUIAS · Encuadre vertical 9:16 en pantalla
	Studio: ReplicatedStorage > StoryTemplate > Modulos > Guias

	· Si la ventana no es 9:16, dibuja bandas negras para que solo se vea la
	  zona que acabará en el vídeo (Config.BandasNegras).
	· Dibuja un recuadro verde con la zona segura (Config.MostrarGuias).
	· Ajusta el campo de visión para que la composición sea idéntica sea cual
	  sea el tamaño de la ventana.
]]

local Players = game:GetService("Players")

local Guias = {}

-- Rectángulo (x, y, ancho, alto) en píxeles del área 9:16 centrada en la ventana.
function Guias.Rect(viewport, aspecto)
	local W, H = viewport.X, viewport.Y
	if H <= 0 then
		return 0, 0, W, H
	end
	if W / H > aspecto then
		local w = H * aspecto
		return (W - w) / 2, 0, w, H
	end
	local h = W / aspecto
	return 0, (H - h) / 2, W, h
end

-- FOV real de la cámara para que el área 9:16 tenga exactamente "fov" en vertical.
function Guias.FOVReal(camara, fov, aspecto)
	local vp = camara.ViewportSize
	if vp.Y <= 0 then
		return fov
	end
	local _, _, _, h = Guias.Rect(vp, aspecto)
	if h >= vp.Y - 0.5 then
		return fov
	end
	return math.deg(2 * math.atan(math.tan(math.rad(fov) / 2) * vp.Y / h))
end

function Guias.Crear(config, margenes)
	local jugador = Players.LocalPlayer
	local gui = Instance.new("ScreenGui")
	gui.Name = "GuiasVertical"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 100
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

	local barras = {}
	for i = 1, 4 do
		local f = Instance.new("Frame")
		f.Name = "Banda" .. i
		f.BackgroundColor3 = Color3.new(0, 0, 0)
		f.BorderSizePixel = 0
		f.Visible = config.BandasNegras ~= false
		f.Parent = gui
		barras[i] = f
	end

	-- Lienzo: el área 9:16 exacta, donde se colocan los rótulos y textos
	local lienzo = Instance.new("Frame")
	lienzo.Name = "Lienzo"
	lienzo.BackgroundTransparency = 1
	lienzo.ClipsDescendants = true
	lienzo.ZIndex = 5
	lienzo.Parent = gui
	Guias.Lienzo = lienzo

	-- Velo para fundidos (cubre toda la pantalla)
	local velo = Instance.new("Frame")
	velo.Name = "Velo"
	velo.Size = UDim2.fromScale(1, 1)
	velo.BackgroundColor3 = Color3.new(0, 0, 0)
	velo.BackgroundTransparency = 1
	velo.BorderSizePixel = 0
	velo.ZIndex = 50
	velo.Parent = gui
	Guias.Velo = velo

	-- Reloj de la escena (solo con las guías activas): ayuda a comprobar la sincronización
	local reloj = Instance.new("TextLabel")
	reloj.Name = "Reloj"
	reloj.BackgroundColor3 = Color3.new(0, 0, 0)
	reloj.BackgroundTransparency = 0.4
	reloj.TextColor3 = Color3.fromRGB(0, 255, 140)
	reloj.Font = Enum.Font.Code
	reloj.TextSize = 14
	reloj.Size = UDim2.fromOffset(150, 20)
	reloj.Position = UDim2.fromOffset(6, 6)
	reloj.Text = ""
	reloj.Visible = config.MostrarGuias == true
	reloj.ZIndex = 40
	reloj.Parent = lienzo
	Guias.Reloj = reloj

	local zona = Instance.new("Frame")
	zona.Name = "ZonaSegura"
	zona.BackgroundTransparency = 1
	zona.Visible = config.MostrarGuias == true
	zona.Parent = gui
	local borde = Instance.new("UIStroke")
	borde.Color = Color3.fromRGB(0, 255, 140)
	borde.Thickness = 2
	borde.Transparency = 0.2
	borde.Parent = zona
	local texto = Instance.new("TextLabel")
	texto.BackgroundTransparency = 1
	texto.Size = UDim2.new(1, 0, 0, 18)
	texto.Position = UDim2.new(0, 0, 1, 4)
	texto.Font = Enum.Font.GothamBold
	texto.TextSize = 12
	texto.TextColor3 = Color3.fromRGB(0, 255, 140)
	texto.Text = "Zona segura · Config.MostrarGuias = false para grabar"
	texto.Parent = zona

	local function actualizar()
		local vp = workspace.CurrentCamera.ViewportSize
		local x, y, w, h = Guias.Rect(vp, config.Aspecto)
		barras[1].Position = UDim2.fromOffset(0, 0)
		barras[1].Size = UDim2.fromOffset(x, vp.Y)
		barras[2].Position = UDim2.fromOffset(x + w, 0)
		barras[2].Size = UDim2.fromOffset(vp.X - x - w, vp.Y)
		barras[3].Position = UDim2.fromOffset(x, 0)
		barras[3].Size = UDim2.fromOffset(w, y)
		barras[4].Position = UDim2.fromOffset(x, y + h)
		barras[4].Size = UDim2.fromOffset(w, vp.Y - y - h)
		lienzo.Position = UDim2.fromOffset(x, y)
		lienzo.Size = UDim2.fromOffset(w, h)
		zona.Position = UDim2.fromOffset(x + w * margenes.Lateral, y + h * margenes.Superior)
		zona.Size = UDim2.fromOffset(w * (1 - 2 * margenes.Lateral), h * (1 - margenes.Superior - margenes.Inferior))
	end
	actualizar()
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(actualizar)

	gui.Parent = jugador:WaitForChild("PlayerGui")
	Guias.Gui = gui
	return gui
end

-- Actualiza el reloj de la escena (segundos desde el primer paso).
function Guias.Tiempo(t, texto)
	if Guias.Reloj and Guias.Reloj.Visible then
		Guias.Reloj.Text = string.format(" t = %6.2f s %s", t, texto or "")
	end
end

return Guias
]=======] },
	{ Ruta = "StoryTemplate/Modulos", Nombre = "DefPersonajes", Clase = "ModuleScript", Fuente = [=======[
--[[
	DEFPERSONAJES · Aspecto y personalidad de los personajes reutilizables
	Studio: ReplicatedStorage > StoryTemplate > Modulos > DefPersonajes

	Cada entrada crea un Model R15 de estilo clásico en StoryTemplate > Personajes.
	En cada escena se asignan a ROLES con la tabla "Reparto".
	Las piezas disponibles (caras, pelo, prendas, accesorios) están en Modulos > Atuendos.

	Campos:
	  Personalidad → texto de referencia (se guarda como atributo del Model)
	  Piel         → Color3 del tono de piel
	  Cuerpo       → { Altura, Anchura, Profundidad, Cabeza }  (1 = normal)
	  Cara         → nombre de Atuendos.Caras, tabla { Ojos, Cejas, Boca, Mejillas, Pecas }
	                 o id numérico de una cara del catálogo
	  Pelo         → { Estilo = "Corto" | "Despeinado" | "Rapado" | "Raya" | "Entradas" | "Ninguno", Color }
	  Superior     → { Prenda = "Camiseta" | "MangaLarga" | "Sudadera" | "Polo" | "Tirantes"
	                            | "Chaqueta" | "CamisetaRayas" | "Camisa" | "Bata"
	                            | "ChalecoCamisa", Color, ColorDetalle }
	  Inferior     → { Prenda = "Pantalon" | "Corto", Color }
	  Calzado      → Color3
	  Accesorios   → lista de { Tipo = "Gorra" | "GorraAtras" | "Gafas" | "GafasSol" | "Barba"
	                                  | "Bigote" | "Corbata" | "Cinturon" | "Barriga" | "Mochila", Color }

	Las prendas son básicas a propósito (sudadera, camiseta, pantalón largo, gorra)
	para que sirvan en casi cualquier historia: casa, calle, colegio, trabajo...
	Para un atuendo especial (pijama, uniforme...) crea una variante con otro nombre,
	p. ej. "Protagonista_Pijama", copiando la entrada y cambiando solo la ropa.
]]

local function rgb(r, g, b)
	return Color3.fromRGB(r, g, b)
end

return {
	-- Flaco, piel clara. Curioso, algo tímido y nervioso: el chico corriente
	-- al que le pasan las cosas. Sudadera con capucha, vaqueros y zapatillas.
	Protagonista = {
		Personalidad = "Curioso, tímido y algo nervioso",
		Piel = rgb(245, 218, 196),
		Cuerpo = { Altura = 1.02, Anchura = 0.72, Profundidad = 0.75, Cabeza = 1 },
		Cara = "Timido",
		Pelo = { Estilo = "Despeinado", Color = rgb(96, 62, 38) },
		Superior = { Prenda = "Sudadera", Color = rgb(52, 98, 170) },
		Inferior = { Prenda = "Pantalon", Color = rgb(44, 56, 80) },
		Calzado = rgb(235, 235, 235),
	},

	-- Alto y fuerte, piel negra. Seguro de sí mismo, tranquilo y protector:
	-- el amigo fiable. Camiseta blanca, pantalón gris oscuro, cinturón y barba corta.
	Secundario1 = {
		Personalidad = "Seguro, tranquilo y protector",
		Piel = rgb(92, 60, 44),
		Cuerpo = { Altura = 1.15, Anchura = 1.2, Profundidad = 1.1, Cabeza = 1 },
		Cara = "Seguro",
		Pelo = { Estilo = "Rapado", Color = rgb(25, 20, 20) },
		Superior = { Prenda = "Camiseta", Color = rgb(242, 242, 238) },
		Inferior = { Prenda = "Pantalon", Color = rgb(58, 58, 64) },
		Calzado = rgb(85, 58, 40),
		Accesorios = {
			{ Tipo = "Barba", Color = rgb(25, 20, 20) },
			{ Tipo = "Cinturon", Color = rgb(70, 45, 30) },
		},
	},

	-- Pequeño y gordito, piel amarilla clásica de Roblox. Alegre, glotón y
	-- gracioso: el que alivia la tensión. Camiseta de rayas, pantalón caqui y gorra.
	Secundario2 = {
		Personalidad = "Alegre, glotón y gracioso",
		Piel = rgb(245, 205, 48),
		Cuerpo = { Altura = 0.85, Anchura = 1.25, Profundidad = 1.35, Cabeza = 1.08 },
		Cara = "Alegre",
		Pelo = { Estilo = "Ninguno" },
		Superior = { Prenda = "CamisetaRayas", Color = rgb(70, 150, 210), ColorDetalle = rgb(245, 245, 245) },
		Inferior = { Prenda = "Pantalon", Color = rgb(180, 150, 105) },
		Calzado = rgb(190, 40, 40),
		Accesorios = {
			{ Tipo = "GorraAtras", Color = rgb(196, 40, 28) },
			{ Tipo = "Barriga" },
		},
	},

	--==========================================================================
	-- HISTORIA: EL ORIGEN DEL POST-IT
	--==========================================================================

	-- Spencer: químico joven y entusiasta, orgulloso de su "pegamento raro".
	-- Bata blanca de laboratorio sobre camisa azul clara, corbata granate,
	-- gafas de pasta negras y pelo castaño peinado de lado (años 70).
	Spencer = {
		Personalidad = "Químico entusiasta y optimista, orgulloso de su invento",
		Piel = rgb(240, 208, 185),
		Cuerpo = { Altura = 1.0, Anchura = 0.85, Profundidad = 0.85, Cabeza = 1 },
		Cara = "Entusiasta",
		Pelo = { Estilo = "Raya", Color = rgb(72, 48, 32) },
		Superior = { Prenda = "Bata", Color = rgb(246, 246, 242), ColorDetalle = rgb(150, 185, 215) },
		Inferior = { Prenda = "Pantalon", Color = rgb(72, 74, 82) },
		Calzado = rgb(40, 32, 28),
		Accesorios = {
			{ Tipo = "Gafas", Color = rgb(25, 22, 22) },
			{ Tipo = "Corbata", Color = rgb(125, 35, 40) },
		},
	},

	-- Art: ingeniero curioso y práctico que canta en el coro (narrador).
	-- Algo mayor: entradas canosas y bigote. Chaleco mostaza sobre camisa crema
	-- y pantalón de pana marrón, muy de los años 70.
	Art = {
		Personalidad = "Ingeniero curioso y práctico; canta en el coro",
		Piel = rgb(232, 196, 170),
		Cuerpo = { Altura = 1.06, Anchura = 1.0, Profundidad = 1.0, Cabeza = 1 },
		Cara = "Curioso",
		Pelo = { Estilo = "Entradas", Color = rgb(128, 108, 88) },
		Superior = { Prenda = "ChalecoCamisa", Color = rgb(184, 128, 46), ColorDetalle = rgb(245, 238, 220) },
		Inferior = { Prenda = "Pantalon", Color = rgb(110, 74, 45) },
		Calzado = rgb(62, 40, 26),
		Accesorios = {
			{ Tipo = "Bigote", Color = rgb(112, 88, 64) },
		},
	},
}
]=======] },
	{ Ruta = "StoryTemplate/Modulos", Nombre = "Atuendos", Clase = "ModuleScript", Fuente = [=======[
--[[
	ATUENDOS · Biblioteca reutilizable de caras, pelo, ropa y accesorios
	Studio: ReplicatedStorage > StoryTemplate > Modulos > Atuendos

	Todo se construye con colores planos y unas pocas Parts soldadas al cuerpo,
	sin texturas ni ids del catálogo: no depende de nada externo y cuesta muy poco.
	Lo usa FabricaPersonajes al construir los personajes de DefPersonajes.

	PIEZAS DISPONIBLES (para usar en DefPersonajes)

	Caras (Cara = "Nombre" o una tabla { Ojos, Cejas, Boca, Mejillas, Pecas })
	  Caras predefinidas : Timido, Seguro, Alegre, Neutral, Serio
	  Ojos   : tabla { Iris = Color3, Parpado = 0..0.6, ParpadoInferior = 0..0.4, Tamano = 1 }
	           (ojos detallados que parpadean solos)
	  Cejas  : Normales, Gruesas, Preocupadas, Arqueadas, Levantadas, Enfadadas, Ninguna
	  Boca   : Sonrisa, SonrisaPequena, SonrisaAbierta, MediaSonrisa, Seria, Triste, O
	           (al hablar se cambia por una boca que se abre y se cierra)

	Pelo (Pelo = { Estilo = "...", Color = Color3 })
	  Corto, Despeinado, Rapado, Raya (peinado de lado con patillas), Entradas (pelo en retirada), Ninguno

	Expresiones (acción "Expresion" de las escenas; cambian cejas, boca y párpados un rato)
	  Sorpresa, Frustracion, Idea, Feliz, Curiosidad, Orgullo, Pensativo, Duda

	Prendas superiores (Superior = { Prenda = "...", Color = Color3, ColorDetalle = Color3 })
	  Camiseta, MangaLarga, Sudadera, Polo, Tirantes, Chaqueta, CamisetaRayas,
	  Camisa, Bata (bata de laboratorio; ColorDetalle = camisa), ChalecoCamisa (ColorDetalle = camisa)

	Prendas inferiores (Inferior = { Prenda = "...", Color = Color3 })
	  Pantalon, Corto

	Accesorios (Accesorios = { { Tipo = "...", Color = Color3 }, ... })
	  Gorra, GorraAtras, Gafas (montura dibujada en la cara), GafasSol, Barba, Bigote,
	  Corbata, Cinturon, Barriga, Mochila
]]

local Atuendos = {}

local OSCURO = Color3.fromRGB(35, 28, 28)
local BLANCO = Color3.fromRGB(250, 250, 250)

--==============================================================================
-- CABEZA CLÁSICA
-- La cabeza por defecto de Roblox es una "cabeza dinámica" con su propia cara
-- animada (ojos que parpadean). Para que no se superponga a nuestra cara, se
-- sustituye por la cabeza clásica de bloques (SpecialMesh "Head", sin texturas).
--==============================================================================

function Atuendos.CabezaClasica(modelo)
	local vieja = modelo:FindFirstChild("Head")
	if not vieja or not vieja:IsA("BasePart") then
		return nil
	end
	local lado = vieja.Size.Y
	local nueva = Instance.new("Part")
	nueva.Name = "Head"
	nueva.Size = Vector3.new(lado, lado, lado)
	nueva.CFrame = vieja.CFrame
	nueva.Color = vieja.Color
	nueva.Material = Enum.Material.SmoothPlastic
	nueva.TopSurface = Enum.SurfaceType.Smooth
	nueva.BottomSurface = Enum.SurfaceType.Smooth
	nueva.CanCollide = false
	nueva.CanTouch = false
	nueva.CanQuery = false
	local malla = Instance.new("SpecialMesh")
	malla.MeshType = Enum.MeshType.Head
	malla.Scale = Vector3.new(1, 1, 1)
	malla.Parent = nueva

	-- Conserva articulaciones y puntos de anclaje; descarta cara, texturas y FaceControls
	for _, hijo in ipairs(vieja:GetChildren()) do
		if hijo:IsA("Attachment") or hijo:IsA("JointInstance") or hijo:IsA("WeldConstraint") or hijo:IsA("ValueBase") then
			hijo.Parent = nueva
		end
	end
	for _, d in ipairs(modelo:GetDescendants()) do
		if d:IsA("JointInstance") or d:IsA("WeldConstraint") then
			if d.Part0 == vieja then
				d.Part0 = nueva
			end
			if d.Part1 == vieja then
				d.Part1 = nueva
			end
		end
	end
	vieja:Destroy()
	nueva.Parent = modelo
	return nueva
end

--==============================================================================
-- CARAS
-- Se dibujan con un SurfaceGui en la cara frontal de la cabeza. Los nombres
-- de los elementos (OjoIzq, OjoDer, Parpado, BocaReposo, BocaHabla) los usa
-- el Actor para parpadear y mover la boca al hablar.
--==============================================================================

--[[
	Ojos = {
	  Iris            = Color3 del iris
	  Parpado         = 0..0.6  cuánto tapa el párpado superior (0.35 = mirada entornada)
	  ParpadoInferior = 0..0.4  cuánto sube el párpado inferior (ojos sonrientes)
	  Tamano          = 1       escala del ojo
	}
]]
Atuendos.Caras = {
	Neutral = {
		Ojos = { Iris = Color3.fromRGB(95, 65, 40), Parpado = 0.08 },
		Cejas = "Normales",
		Boca = "SonrisaPequena",
	},
	Timido = {
		Ojos = { Iris = Color3.fromRGB(70, 125, 190), Parpado = 0.04, Tamano = 1.1 },
		Cejas = "Preocupadas",
		Boca = "SonrisaPequena",
		Pecas = true,
	},
	Seguro = {
		Ojos = { Iris = Color3.fromRGB(80, 50, 30), Parpado = 0.36, Tamano = 0.95 },
		Cejas = "Gruesas",
		Boca = "MediaSonrisa",
	},
	Alegre = {
		Ojos = { Iris = Color3.fromRGB(60, 145, 80), Parpado = 0.1, ParpadoInferior = 0.28, Tamano = 1.05 },
		Cejas = "Arqueadas",
		Boca = "SonrisaAbierta",
		Mejillas = true,
	},
	Serio = {
		Ojos = { Iris = Color3.fromRGB(90, 90, 100), Parpado = 0.25 },
		Cejas = "Gruesas",
		Boca = "Seria",
	},
	Entusiasta = {
		Ojos = { Iris = Color3.fromRGB(105, 120, 60), Parpado = 0.02, Tamano = 1.05 },
		Cejas = "Arqueadas",
		Boca = "Sonrisa",
	},
	Curioso = {
		Ojos = { Iris = Color3.fromRGB(70, 120, 170), Parpado = 0.14 },
		Cejas = "Normales",
		Boca = "SonrisaPequena",
	},
}

-- Expresiones temporales: se superponen a la cara base (ver Atuendos.Expresar).
-- Parpado = cuánto baja el párpado superior (0 = ojos muy abiertos).
Atuendos.Expresiones = {
	Sorpresa = { Cejas = "Levantadas", Boca = "O", Parpado = 0 },
	Frustracion = { Cejas = "Enfadadas", Boca = "Triste", Parpado = 0.3 },
	Idea = { Cejas = "Levantadas", Boca = "Sonrisa", Parpado = 0 },
	Feliz = { Cejas = "Arqueadas", Boca = "SonrisaAbierta" },
	Curiosidad = { Cejas = "Preocupadas", Boca = "Seria", Parpado = 0.08 },
	Duda = { Cejas = "Preocupadas", Boca = "MediaSonrisa", Parpado = 0.2 },
	Orgullo = { Cejas = "Normales", Boca = "MediaSonrisa", Parpado = 0.3 },
	Pensativo = { Cejas = "Gruesas", Boca = "Seria", Parpado = 0.28 },
}

-- Rectángulo (o pastilla/círculo si redondo) centrado en "x, y" (escala 0-1 del padre).
local function forma(padre, x, y, ancho, alto, color, redondo, rotacion, transparencia, z)
	local f = Instance.new("Frame")
	f.AnchorPoint = Vector2.new(0.5, 0.5)
	f.Position = UDim2.fromScale(x, y)
	f.Size = UDim2.fromScale(ancho, alto)
	f.BackgroundColor3 = color
	f.BackgroundTransparency = transparencia or 0
	f.BorderSizePixel = 0
	f.Rotation = rotacion or 0
	f.ZIndex = z or 1
	if redondo then
		local c = Instance.new("UICorner")
		c.CornerRadius = UDim.new(0.5, 0)
		c.Parent = f
	end
	f.Parent = padre
	return f
end

--[[
	Media elipse centrada en (x, y).
	haciaAbajo = true → forma de U (sonrisa); false → forma de ∩.
	relleno = Color3 → media elipse rellena; nil → solo el contorno (grosor en píxeles de 100).
]]
local function arco(padre, x, y, ancho, alto, haciaAbajo, color, grosor, relleno)
	local cont = Instance.new("Frame")
	cont.BackgroundTransparency = 1
	cont.ClipsDescendants = true
	cont.AnchorPoint = Vector2.new(0.5, haciaAbajo and 0 or 1)
	cont.Position = UDim2.fromScale(x, y)
	cont.Size = UDim2.fromScale(ancho, alto / 2)
	cont.Parent = padre
	local e = Instance.new("Frame")
	e.Size = UDim2.fromScale(1, 2)
	e.Position = UDim2.fromScale(0, haciaAbajo and -1 or 0)
	e.BorderSizePixel = 0
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0.5, 0)
	c.Parent = e
	if relleno then
		e.BackgroundColor3 = relleno
	else
		e.BackgroundTransparency = 1
		local s = Instance.new("UIStroke")
		s.Color = color
		s.Thickness = grosor or 3
		s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		s.Parent = e
	end
	e.Parent = cont
	return cont
end

local PESTANAS = Color3.fromRGB(25, 18, 18)

-- Ojo detallado: blanco, iris, pupila, dos brillos, párpado superior con pestañas
-- y párpado inferior. "haciaDentro" (1 o -1) desplaza un poco el iris hacia la nariz.
local function ojo(g, nombre, x, y, op, piel, haciaDentro)
	local t = op.Tamano or 1
	local cont = Instance.new("Frame")
	cont.Name = nombre
	cont.AnchorPoint = Vector2.new(0.5, 0.5)
	cont.Position = UDim2.fromScale(x, y)
	cont.Size = UDim2.fromScale(0.17 * t, 0.21 * t)
	cont.BackgroundTransparency = 1
	cont.ClipsDescendants = true
	cont.Parent = g

	local dx = 0.05 * haciaDentro
	forma(cont, 0.5, 0.5, 1, 1, BLANCO, true, 0, 0, 1) -- blanco del ojo
	forma(cont, 0.5 + dx, 0.55, 0.64, 0.52, op.Iris or Color3.fromRGB(95, 65, 40), true, 0, 0, 2) -- iris
	forma(cont, 0.5 + dx, 0.55, 0.32, 0.26, Color3.fromRGB(15, 12, 12), true, 0, 0, 3) -- pupila
	forma(cont, 0.62 + dx, 0.42, 0.2, 0.16, BLANCO, true, 0, 0, 4) -- brillo grande
	forma(cont, 0.4 + dx, 0.66, 0.09, 0.075, BLANCO, true, 0, 0.1, 4) -- brillo pequeño

	-- Párpado inferior (tapa desde abajo)
	local inferior = op.ParpadoInferior or 0
	if inferior > 0 then
		local pi = Instance.new("Frame")
		pi.Name = "ParpadoInferior"
		pi.AnchorPoint = Vector2.new(0.5, 1)
		pi.Position = UDim2.fromScale(0.5, 1)
		pi.Size = UDim2.fromScale(1.2, inferior)
		pi.BackgroundColor3 = piel
		pi.BorderSizePixel = 0
		pi.ZIndex = 5
		pi.Parent = cont
	end

	-- Párpado superior (el que se cierra al parpadear) con la línea de pestañas
	local alto = op.Parpado or 0.06
	local p = Instance.new("Frame")
	p.Name = "Parpado"
	p.AnchorPoint = Vector2.new(0.5, 0)
	p.Position = UDim2.fromScale(0.5, 0)
	p.Size = UDim2.fromScale(1.2, alto)
	p.BackgroundColor3 = piel
	p.BorderSizePixel = 0
	p.ZIndex = 6
	p:SetAttribute("Alto", alto)
	p:SetAttribute("AltoBase", alto)
	p.Parent = cont

	local pestanas = forma(p, 0.5, 1, 0.86, 0, PESTANAS, true, 0, 0, 7)
	pestanas.Name = "Pestanas"
	pestanas.Size = UDim2.new(0.86, 0, 0, 3)
	-- Pestaña exterior (detalle)
	local rabito = forma(p, 0.5 - 0.42 * haciaDentro, 1, 0.22, 0, PESTANAS, true, 25 * haciaDentro, 0, 7)
	rabito.Name = "PestanaExterior"
	rabito.Size = UDim2.new(0.22, 0, 0, 3)
	return cont
end

-- Cada ceja: inclinación de la izquierda (la derecha es simétrica), altura y grosor.
local CEJAS = {
	Normales = { Giro = 0, Y = 0.26, Grosor = 0.035 },
	Gruesas = { Giro = 7, Y = 0.28, Grosor = 0.06 },
	Preocupadas = { Giro = -16, Y = 0.25, Grosor = 0.035 },
	Arqueadas = { Giro = -9, Y = 0.22, Grosor = 0.04 },
	Levantadas = { Giro = -4, Y = 0.18, Grosor = 0.04 },
	Enfadadas = { Giro = 18, Y = 0.29, Grosor = 0.05 },
}

local BOCAS = {
	Sonrisa = function(g, y)
		arco(g, 0.5, y, 0.32, 0.18, true, OSCURO, 3.5)
	end,
	SonrisaPequena = function(g, y)
		arco(g, 0.5, y, 0.2, 0.1, true, OSCURO, 3)
	end,
	SonrisaAbierta = function(g, y)
		local boca = arco(g, 0.5, y - 0.02, 0.34, 0.26, true, nil, nil, Color3.fromRGB(90, 25, 30))
		forma(boca, 0.5, 0.1, 0.8, 0.2, BLANCO, false, 0, 0, 2)
		forma(boca, 0.5, 0.78, 0.4, 0.28, Color3.fromRGB(220, 90, 100), true, 0, 0, 2)
	end,
	MediaSonrisa = function(g, y)
		forma(g, 0.43, y + 0.005, 0.12, 0.03, OSCURO, true, -4)
		arco(g, 0.55, y - 0.03, 0.16, 0.1, true, OSCURO, 3)
	end,
	Seria = function(g, y)
		forma(g, 0.5, y, 0.22, 0.03, OSCURO, true)
	end,
	Triste = function(g, y)
		arco(g, 0.5, y + 0.04, 0.22, 0.1, false, OSCURO, 3)
	end,
	O = function(g, y)
		forma(g, 0.5, y, 0.1, 0.13, Color3.fromRGB(90, 25, 30), true)
	end,
}

-- Boca abierta que se usa al hablar (oculta en reposo). El Actor cambia su tamaño.
local function bocaHabla(g, y)
	local b = forma(g, 0.5, y, 0.2, 0.12, Color3.fromRGB(90, 25, 30), true, 0, 0, 1)
	b.Name = "BocaHabla"
	b.ClipsDescendants = true
	b.Visible = false
	local dientes = Instance.new("Frame")
	dientes.AnchorPoint = Vector2.new(0.5, 0)
	dientes.Position = UDim2.fromScale(0.5, 0)
	dientes.Size = UDim2.fromScale(0.8, 0.22)
	dientes.BackgroundColor3 = BLANCO
	dientes.BorderSizePixel = 0
	dientes.ZIndex = 2
	dientes.Parent = b
	local lengua = forma(b, 0.5, 1.15, 0.6, 0.5, Color3.fromRGB(220, 90, 100), true, 0, 0, 2)
	lengua.AnchorPoint = Vector2.new(0.5, 1)
	return b
end

-- Contenedor transparente a pantalla completa de la cara (agrupa piezas).
local function capa(padre, nombre, visible)
	local f = Instance.new("Frame")
	f.Name = nombre
	f.Size = UDim2.fromScale(1, 1)
	f.BackgroundTransparency = 1
	f.Visible = visible ~= false
	f.Parent = padre
	return f
end

function Atuendos.CrearCara(cabeza, def)
	if type(def) == "string" then
		def = Atuendos.Caras[def]
	end
	if type(def) ~= "table" then
		return nil
	end
	for _, d in ipairs(cabeza:GetChildren()) do
		if d:IsA("Decal") or d:IsA("FaceControls") or d:IsA("SurfaceAppearance") or d.Name == "Cara" then
			d:Destroy()
		end
	end

	local piel = cabeza.Color
	local g = Instance.new("SurfaceGui")
	g.Name = "Cara"
	g.Face = Enum.NormalId.Front
	g.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
	g.CanvasSize = Vector2.new(100, 100)
	g.LightInfluence = 1
	g.ClipsDescendants = true
	g.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

	local ojos = type(def.Ojos) == "table" and def.Ojos or {}
	ojo(g, "OjoIzq", 0.33, 0.45, ojos, piel, 1)
	ojo(g, "OjoDer", 0.67, 0.45, ojos, piel, -1)

	local cejasBase = def.Cejas or "Normales"
	for nombre, ceja in pairs(CEJAS) do
		local grupo = capa(g, "Cejas_" .. nombre, nombre == cejasBase)
		forma(grupo, 0.33, ceja.Y, 0.17, ceja.Grosor, OSCURO, true, ceja.Giro)
		forma(grupo, 0.67, ceja.Y, 0.17, ceja.Grosor, OSCURO, true, -ceja.Giro)
	end
	g:SetAttribute("CejasBase", cejasBase)

	local reposo = capa(g, "BocaReposo", true)
	local bocaBase = BOCAS[def.Boca or ""] and def.Boca or "SonrisaPequena"
	for nombre, dibujar in pairs(BOCAS) do
		dibujar(capa(reposo, "Boca_" .. nombre, nombre == bocaBase), 0.69)
	end
	g:SetAttribute("BocaBase", bocaBase)
	bocaHabla(g, 0.71)

	if def.Mejillas then
		local rosa = Color3.fromRGB(240, 120, 120)
		forma(g, 0.18, 0.62, 0.13, 0.08, rosa, true, 0, 0.45)
		forma(g, 0.82, 0.62, 0.13, 0.08, rosa, true, 0, 0.45)
	end
	if def.Pecas then
		local marron = Color3.fromRGB(170, 110, 80)
		for _, p in ipairs({ { 0.2, 0.6 }, { 0.25, 0.63 }, { 0.17, 0.65 } }) do
			forma(g, p[1], p[2], 0.025, 0.025, marron, true, 0, 0.2)
			forma(g, 1 - p[1], p[2], 0.025, 0.025, marron, true, 0, 0.2)
		end
	end

	g.Parent = cabeza
	return g
end

--[[
	Aplica una expresión a una cara creada por CrearCara (nil = vuelve a la cara base).
	expresion = nombre de Atuendos.Expresiones o tabla { Cejas, Boca, Parpado }.
	Devuelve la altura de párpado que hay que usar (la anima el Actor).
]]
function Atuendos.Expresar(cara, expresion)
	if type(expresion) == "string" then
		expresion = Atuendos.Expresiones[expresion]
	end
	expresion = expresion or {}
	local cejas = expresion.Cejas or cara:GetAttribute("CejasBase")
	local boca = expresion.Boca or cara:GetAttribute("BocaBase")
	for _, hijo in ipairs(cara:GetChildren()) do
		if hijo.Name:sub(1, 6) == "Cejas_" then
			hijo.Visible = hijo.Name == "Cejas_" .. tostring(cejas)
		end
	end
	local reposo = cara:FindFirstChild("BocaReposo")
	if reposo then
		for _, hijo in ipairs(reposo:GetChildren()) do
			hijo.Visible = hijo.Name == "Boca_" .. tostring(boca)
		end
	end
	return expresion.Parpado
end

-- Montura de gafas dibujada sobre la cara (no tapa los ojos ni el parpadeo).
function Atuendos.GafasCara(cara, color)
	color = color or OSCURO
	local grupo = capa(cara, "Gafas", true)
	grupo.ZIndex = 10
	for _, x in ipairs({ 0.33, 0.67 }) do
		local lente = forma(grupo, x, 0.45, 0.27, 0.26, Color3.fromRGB(200, 225, 240), false, 0, 0.88, 20)
		local c = Instance.new("UICorner")
		c.CornerRadius = UDim.new(0.3, 0)
		c.Parent = lente
		local borde = Instance.new("UIStroke")
		borde.Color = color
		borde.Thickness = 3.5
		borde.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		borde.Parent = lente
	end
	forma(grupo, 0.5, 0.42, 0.08, 0.03, color, false, 0, 0, 20)
	return grupo
end

--==============================================================================
-- PIEZAS 3D SOLDADAS AL CUERPO
--==============================================================================

-- Crea una Part pegada a "base" con un desplazamiento local (CFrame) y la suelda.
local function pegar(modelo, base, nombre, tam, offset, color, forma3d)
	local p = Instance.new("Part")
	p.Name = nombre
	p.Shape = forma3d or Enum.PartType.Block
	p.Size = tam
	p.CFrame = base.CFrame * offset
	p.Color = color
	p.Material = Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Anchored = false
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.Massless = true
	local w = Instance.new("WeldConstraint")
	w.Part0 = base
	w.Part1 = p
	w.Parent = p
	local carpeta = modelo:FindFirstChild("Atuendo")
	if not carpeta then
		carpeta = Instance.new("Folder")
		carpeta.Name = "Atuendo"
		carpeta.Parent = modelo
	end
	p.Parent = carpeta
	return p
end

local function C(x, y, z)
	return CFrame.new(x, y, z)
end

-- Cada pieza recibe (modelo, color, colorDetalle). El frente del cuerpo es -Z.
local PIEZAS = {}

PIEZAS.PeloCorto = function(m, color)
	local h = m.Head
	local s = h.Size
	pegar(m, h, "Pelo", Vector3.new(s.X * 1.06, s.Y * 0.22, s.Z * 1.06), C(0, s.Y * 0.43, 0), color)
	pegar(m, h, "Pelo", Vector3.new(s.X * 1.06, s.Y * 0.65, s.Z * 0.2), C(0, s.Y * 0.13, s.Z * 0.45), color)
end

PIEZAS.PeloDespeinado = function(m, color)
	PIEZAS.PeloCorto(m, color)
	local h = m.Head
	local s = h.Size
	pegar(m, h, "Flequillo", Vector3.new(s.X * 0.85, s.Y * 0.16, s.Z * 0.14), C(s.X * 0.06, s.Y * 0.33, -s.Z * 0.5) * CFrame.Angles(0, 0, math.rad(-6)), color)
	for i, d in ipairs({ { -0.25, 15 }, { 0.05, -10 }, { 0.3, 20 } }) do
		pegar(m, h, "Mechon" .. i, Vector3.new(s.X * 0.28, s.Y * 0.18, s.Z * 0.35), C(s.X * d[1], s.Y * 0.56, -s.Z * 0.1 * i) * CFrame.Angles(math.rad(d[2]), math.rad(d[2] * 2), math.rad(d[2])), color)
	end
end

PIEZAS.PeloRapado = function(m, color)
	local h = m.Head
	local s = h.Size
	pegar(m, h, "Pelo", Vector3.new(s.X * 1.02, s.Y * 0.08, s.Z * 1.02), C(0, s.Y * 0.47, 0), color)
	pegar(m, h, "Pelo", Vector3.new(s.X * 1.02, s.Y * 0.5, s.Z * 0.06), C(0, s.Y * 0.2, s.Z * 0.49), color)
end

PIEZAS.Gorra = function(m, color, _, atras)
	local h = m.Head
	local s = h.Size
	pegar(m, h, "GorraCopa", Vector3.new(s.X * 1.1, s.Y * 0.3, s.Z * 1.1), C(0, s.Y * 0.5, 0), color)
	local z = atras and s.Z * 0.75 or -s.Z * 0.75
	pegar(m, h, "GorraVisera", Vector3.new(s.X * 0.8, s.Y * 0.06, s.Z * 0.5), C(0, s.Y * 0.38, z), color)
end

PIEZAS.GorraAtras = function(m, color, detalle)
	PIEZAS.Gorra(m, color, detalle, true)
end

PIEZAS.GafasSol = function(m, color)
	local h = m.Head
	local s = h.Size
	for _, lado in ipairs({ -1, 1 }) do
		pegar(m, h, "Lente", Vector3.new(s.X * 0.28, s.Y * 0.2, 0.05), C(lado * s.X * 0.17, s.Y * 0.07, -s.Z * 0.52), color)
	end
	pegar(m, h, "Puente", Vector3.new(s.X * 0.1, 0.05, 0.05), C(0, s.Y * 0.1, -s.Z * 0.52), color)
end

PIEZAS.Barba = function(m, color)
	local h = m.Head
	local s = h.Size
	pegar(m, h, "Barba", Vector3.new(s.X * 0.86, s.Y * 0.26, s.Z * 0.2), C(0, -s.Y * 0.38, -s.Z * 0.42), color)
	pegar(m, h, "Patilla", Vector3.new(s.X * 1.02, s.Y * 0.35, s.Z * 0.3), C(0, -s.Y * 0.2, -s.Z * 0.15), color)
end

PIEZAS.PeloRaya = function(m, color)
	PIEZAS.PeloCorto(m, color)
	local h = m.Head
	local s = h.Size
	-- Volumen peinado hacia un lado, flequillo lateral y patillas (estilo años 70)
	pegar(m, h, "Tupe", Vector3.new(s.X * 0.8, s.Y * 0.18, s.Z * 0.92), C(s.X * 0.1, s.Y * 0.55, -s.Z * 0.03) * CFrame.Angles(0, 0, math.rad(-6)), color)
	pegar(m, h, "FlequilloLateral", Vector3.new(s.X * 0.62, s.Y * 0.14, s.Z * 0.16), C(s.X * 0.17, s.Y * 0.39, -s.Z * 0.5) * CFrame.Angles(0, 0, math.rad(-12)), color)
	for _, lado in ipairs({ -1, 1 }) do
		pegar(m, h, "Patilla", Vector3.new(s.X * 0.08, s.Y * 0.36, s.Z * 0.3), C(lado * s.X * 0.52, s.Y * 0.04, -s.Z * 0.05), color)
	end
end

PIEZAS.PeloEntradas = function(m, color)
	local h = m.Head
	local s = h.Size
	-- Coronilla y nuca con pelo; la frente queda despejada
	pegar(m, h, "Pelo", Vector3.new(s.X * 1.04, s.Y * 0.16, s.Z * 0.62), C(0, s.Y * 0.45, s.Z * 0.22), color)
	pegar(m, h, "Pelo", Vector3.new(s.X * 1.04, s.Y * 0.6, s.Z * 0.18), C(0, s.Y * 0.15, s.Z * 0.46), color)
	for _, lado in ipairs({ -1, 1 }) do
		pegar(m, h, "Sien", Vector3.new(s.X * 0.1, s.Y * 0.42, s.Z * 0.62), C(lado * s.X * 0.52, s.Y * 0.14, s.Z * 0.16), color)
		pegar(m, h, "Patilla", Vector3.new(s.X * 0.08, s.Y * 0.3, s.Z * 0.22), C(lado * s.X * 0.52, -s.Y * 0.05, -s.Z * 0.12), color)
	end
end

PIEZAS.Bigote = function(m, color)
	local h = m.Head
	local s = h.Size
	pegar(m, h, "Bigote", Vector3.new(s.X * 0.42, s.Y * 0.09, s.Z * 0.12), C(0, -s.Y * 0.1, -s.Z * 0.49), color)
	for _, lado in ipairs({ -1, 1 }) do
		pegar(m, h, "BigotePunta", Vector3.new(s.X * 0.1, s.Y * 0.11, s.Z * 0.1), C(lado * s.X * 0.22, -s.Y * 0.15, -s.Z * 0.48), color)
	end
end

PIEZAS.Corbata = function(m, color)
	local t = m.UpperTorso
	local s = t.Size
	pegar(m, t, "CorbataNudo", Vector3.new(s.X * 0.12, s.Y * 0.11, 0.08), C(0, s.Y * 0.4, -s.Z * 0.55), color)
	pegar(m, t, "CorbataPala", Vector3.new(s.X * 0.13, s.Y * 0.62, 0.05), C(0, s.Y * 0.02, -s.Z * 0.54), color)
end

-- Bata de laboratorio: solapas, faldón hasta las rodillas y bolsillo con bolígrafos
PIEZAS.Solapas = function(m, color)
	local t = m.UpperTorso
	local s = t.Size
	local tono = color:Lerp(Color3.new(0, 0, 0), 0.1)
	for _, lado in ipairs({ -1, 1 }) do
		pegar(m, t, "Solapa", Vector3.new(s.X * 0.16, s.Y * 0.5, 0.07), C(lado * s.X * 0.2, s.Y * 0.2, -s.Z * 0.53) * CFrame.Angles(0, 0, math.rad(lado * 18)), tono)
	end
end

PIEZAS.Faldon = function(m, color)
	local t = m.LowerTorso
	local s = t.Size
	local pierna = m:FindFirstChild("RightUpperLeg")
	local largo = (pierna and pierna.Size.Y or 1.2) * 1.05
	pegar(m, t, "Faldon", Vector3.new(s.X * 1.1, largo, s.Z * 1.15), C(0, -s.Y * 0.3 - largo / 2, 0), color)
	pegar(m, t, "FaldonAbertura", Vector3.new(0.06, largo, 0.04), C(0, -s.Y * 0.3 - largo / 2, -s.Z * 0.59), color:Lerp(Color3.new(0, 0, 0), 0.25))
end

PIEZAS.BolsilloBata = function(m, color)
	local t = m.UpperTorso
	local s = t.Size
	local tono = color:Lerp(Color3.new(0, 0, 0), 0.08)
	pegar(m, t, "Bolsillo", Vector3.new(s.X * 0.22, s.Y * 0.2, 0.05), C(-s.X * 0.28, -s.Y * 0.02, -s.Z * 0.53), tono)
	pegar(m, t, "Boligrafo", Vector3.new(0.06, s.Y * 0.2, 0.06), C(-s.X * 0.32, s.Y * 0.12, -s.Z * 0.54), Color3.fromRGB(40, 70, 170))
	pegar(m, t, "Boligrafo", Vector3.new(0.06, s.Y * 0.18, 0.06), C(-s.X * 0.25, s.Y * 0.11, -s.Z * 0.54), Color3.fromRGB(190, 40, 40))
end

PIEZAS.Botones = function(m)
	local t = m.UpperTorso
	local s = t.Size
	for i, y in ipairs({ 0.25, 0.0, -0.25 }) do
		pegar(m, t, "Boton" .. i, Vector3.new(0.08, 0.08, 0.04), C(0, s.Y * y, -s.Z * 0.52), Color3.fromRGB(235, 235, 230))
	end
end

-- Cuello de camisa con el color de detalle (debajo de un chaleco)
PIEZAS.CuelloCamisa = function(m, _, detalle)
	local t = m.UpperTorso
	local s = t.Size
	pegar(m, t, "Cuello", Vector3.new(s.X * 0.55, s.Y * 0.08, s.Z * 1.04), C(0, s.Y * 0.47, 0), detalle or BLANCO)
end

-- Escote en pico del chaleco (deja ver la camisa)
PIEZAS.PicoChaleco = function(m, _, detalle)
	local t = m.UpperTorso
	local s = t.Size
	local lado = s.X * 0.26
	pegar(m, t, "Pico", Vector3.new(lado, lado, 0.04), C(0, s.Y * 0.45, -s.Z * 0.51) * CFrame.Angles(0, 0, math.rad(45)), detalle or BLANCO)
end

PIEZAS.Capucha = function(m, color)
	local t = m.UpperTorso
	local s = t.Size
	pegar(m, t, "Capucha", Vector3.new(s.X * 0.7, s.Y * 0.3, s.Z * 0.35), C(0, s.Y * 0.38, s.Z * 0.6), color)
end

PIEZAS.Cuello = function(m, color)
	local t = m.UpperTorso
	local s = t.Size
	pegar(m, t, "Cuello", Vector3.new(s.X * 0.55, s.Y * 0.08, s.Z * 1.04), C(0, s.Y * 0.47, 0), color)
end

PIEZAS.Abertura = function(m, _, detalle)
	local t = m.UpperTorso
	local s = t.Size
	pegar(m, t, "Abertura", Vector3.new(s.X * 0.3, s.Y * 0.98, 0.06), C(0, 0, -s.Z * 0.51), detalle or BLANCO)
end

PIEZAS.Rayas = function(m, _, detalle)
	local t = m.UpperTorso
	local s = t.Size
	for i, y in ipairs({ 0.22, -0.08, -0.38 }) do
		pegar(m, t, "Raya" .. i, Vector3.new(s.X * 1.03, s.Y * 0.1, s.Z * 1.03), C(0, s.Y * y, 0), detalle or BLANCO)
	end
end

PIEZAS.Cinturon = function(m, color)
	local t = m.LowerTorso
	local s = t.Size
	pegar(m, t, "Cinturon", Vector3.new(s.X * 1.03, s.Y * 0.22, s.Z * 1.03), C(0, s.Y * 0.36, 0), color)
end

PIEZAS.Barriga = function(m, color)
	local t = m.UpperTorso
	local s = t.Size
	local d = math.min(s.X * 0.72, s.Y * 1.1)
	pegar(m, t, "Barriga", Vector3.new(d, d, d), C(0, -s.Y * 0.2, -s.Z * 0.18), color, Enum.PartType.Ball)
end

PIEZAS.Mochila = function(m, color)
	local t = m.UpperTorso
	local s = t.Size
	pegar(m, t, "Mochila", Vector3.new(s.X * 0.7, s.Y * 0.85, s.Z * 0.5), C(0, -s.Y * 0.05, s.Z * 0.72), color)
end

--==============================================================================
-- PRENDAS (qué partes del cuerpo se colorean y qué piezas se añaden)
--==============================================================================

-- Brazos: "Ninguno" (sin mangas), "Superior" (manga corta), "Completo" (manga larga)
Atuendos.Superiores = {
	Camiseta = { Brazos = "Superior" },
	MangaLarga = { Brazos = "Completo" },
	Sudadera = { Brazos = "Completo", Extras = { "Capucha" } },
	Polo = { Brazos = "Superior", Extras = { "Cuello" } },
	Tirantes = { Brazos = "Ninguno" },
	Chaqueta = { Brazos = "Completo", Extras = { "Abertura" } }, -- ColorDetalle = camiseta de debajo
	CamisetaRayas = { Brazos = "Superior", Extras = { "Rayas" } }, -- ColorDetalle = color de las rayas
	Camisa = { Brazos = "Completo", Extras = { "Cuello", "Botones" } },
	Bata = { Brazos = "Completo", Extras = { "Abertura", "Solapas", "Faldon", "BolsilloBata" } }, -- ColorDetalle = camisa
	ChalecoCamisa = { Brazos = "Completo", BrazosDetalle = true, Extras = { "CuelloCamisa", "PicoChaleco" } }, -- ColorDetalle = camisa
}

-- Piernas: "Superior" (pantalón corto) o "Completo"
Atuendos.Inferiores = {
	Pantalon = { Piernas = "Completo" },
	Corto = { Piernas = "Superior" },
}

local CUERPO = {
	"Head",
	"UpperTorso",
	"LowerTorso",
	"LeftUpperArm",
	"RightUpperArm",
	"LeftLowerArm",
	"RightLowerArm",
	"LeftHand",
	"RightHand",
	"LeftUpperLeg",
	"RightUpperLeg",
	"LeftLowerLeg",
	"RightLowerLeg",
	"LeftFoot",
	"RightFoot",
}

local function colorear(modelo, nombres, color)
	for _, n in ipairs(nombres) do
		local p = modelo:FindFirstChild(n)
		if p and p:IsA("BasePart") then
			p.Color = color
		end
	end
end

local function pieza(modelo, nombre, color, detalle)
	local f = PIEZAS[nombre]
	if not f then
		warn(("[Atuendos] Pieza desconocida: '%s'"):format(tostring(nombre)))
		return
	end
	local ok, err = pcall(f, modelo, color, detalle)
	if not ok then
		warn(("[Atuendos] No se pudo añadir '%s': %s"):format(nombre, tostring(err)))
	end
end

-- Viste un modelo R15 ya construido según la definición de DefPersonajes.
function Atuendos.Vestir(modelo, def)
	local piel = def.Piel or Color3.fromRGB(255, 204, 153)
	if type(def.Cara) ~= "number" then
		Atuendos.CabezaClasica(modelo)
	end
	colorear(modelo, CUERPO, piel)

	-- Parte de arriba
	local sup = def.Superior or {}
	local prendaSup = Atuendos.Superiores[sup.Prenda or "Camiseta"] or Atuendos.Superiores.Camiseta
	local colorSup = sup.Color or Color3.fromRGB(13, 105, 172)
	colorear(modelo, { "UpperTorso" }, colorSup)
	local colorBrazos = (prendaSup.BrazosDetalle and sup.ColorDetalle) or colorSup
	if prendaSup.Brazos ~= "Ninguno" then
		colorear(modelo, { "LeftUpperArm", "RightUpperArm" }, colorBrazos)
	end
	if prendaSup.Brazos == "Completo" then
		colorear(modelo, { "LeftLowerArm", "RightLowerArm" }, colorBrazos)
	end

	-- Parte de abajo
	local inf = def.Inferior or {}
	local prendaInf = Atuendos.Inferiores[inf.Prenda or "Pantalon"] or Atuendos.Inferiores.Pantalon
	local colorInf = inf.Color or Color3.fromRGB(40, 50, 70)
	colorear(modelo, { "LowerTorso", "LeftUpperLeg", "RightUpperLeg" }, colorInf)
	if prendaInf.Piernas == "Completo" then
		colorear(modelo, { "LeftLowerLeg", "RightLowerLeg" }, colorInf)
	end

	-- Calzado
	colorear(modelo, { "LeftFoot", "RightFoot" }, def.Calzado or Color3.fromRGB(40, 40, 40))

	-- Piezas extra de las prendas
	for _, extra in ipairs(prendaSup.Extras or {}) do
		pieza(modelo, extra, colorSup, sup.ColorDetalle)
	end

	-- Pelo
	if def.Pelo and def.Pelo.Estilo and def.Pelo.Estilo ~= "Ninguno" then
		pieza(modelo, "Pelo" .. def.Pelo.Estilo, def.Pelo.Color or OSCURO)
	end

	-- Cara
	local cara = nil
	if def.Cara and type(def.Cara) ~= "number" and modelo:FindFirstChild("Head") then
		cara = Atuendos.CrearCara(modelo.Head, def.Cara)
	end

	-- Accesorios (las gafas normales se dibujan sobre la cara)
	for _, acc in ipairs(def.Accesorios or {}) do
		local color = acc.Color
		if acc.Tipo == "Barriga" then
			color = color or colorSup
		end
		if acc.Tipo == "Gafas" then
			if cara then
				Atuendos.GafasCara(cara, color)
			else
				pieza(modelo, "GafasSol", color or OSCURO)
			end
		else
			pieza(modelo, acc.Tipo, color or OSCURO, acc.ColorDetalle)
		end
	end
end

return Atuendos
]=======] },
	{ Ruta = "StoryTemplate/Modulos", Nombre = "FabricaPersonajes", Clase = "ModuleScript", Fuente = [=======[
--[[
	FABRICAPERSONAJES · Construye los modelos de personaje a partir de DefPersonajes
	Studio: ReplicatedStorage > StoryTemplate > Modulos > FabricaPersonajes

	Lo usan el instalador (en modo edición) y StoryServer (al pulsar Play, solo
	si falta algún personaje). Usa Players:CreateHumanoidModelFromDescription
	(cuerpo, piel y escalas) y después el módulo Atuendos (ropa, pelo, cara...).
	Solo funciona en el servidor o en la barra de comandos de Studio.
]]

local Players = game:GetService("Players")

local Fabrica = {}

local CARA_POR_DEFECTO = "rbxasset://textures/face.png"

-- Se carga al usarse (el módulo Atuendos está junto a este en Modulos)
local cacheAtuendos = nil
local function Atuendos()
	if not cacheAtuendos then
		cacheAtuendos = require(script.Parent:WaitForChild("Atuendos"))
	end
	return cacheAtuendos
end

-- Escalas del cuerpo. Acepta def.Cuerpo = { Altura, Anchura, Profundidad, Cabeza }
-- (y, por compatibilidad, def.Altura / def.Anchura / def.Cabeza).
local function escalas(def)
	local c = def.Cuerpo or {}
	return {
		Altura = c.Altura or def.Altura or 1,
		Anchura = c.Anchura or def.Anchura or 1,
		Profundidad = c.Profundidad or c.Anchura or def.Anchura or 1,
		Cabeza = c.Cabeza or def.Cabeza or 1,
	}
end

-- Compatibilidad con el formato antiguo (Camiseta / Brazos / Pantalon)
local function normalizar(def)
	local d = {}
	for k, v in pairs(def) do
		d[k] = v
	end
	if not d.Superior and d.Camiseta then
		d.Superior = { Prenda = (d.Brazos == d.Camiseta) and "MangaLarga" or "Camiseta", Color = d.Camiseta }
	end
	if not d.Inferior and d.Pantalon then
		d.Inferior = { Prenda = "Pantalon", Color = d.Pantalon }
	end
	return d
end

function Fabrica.Descripcion(def)
	local d = Instance.new("HumanoidDescription")
	local piel = def.Piel or Color3.fromRGB(255, 204, 153)
	d.HeadColor = piel
	d.TorsoColor = piel
	d.LeftArmColor = piel
	d.RightArmColor = piel
	d.LeftLegColor = piel
	d.RightLegColor = piel

	-- Proporciones clásicas (bloques) con la complexión de cada personaje
	local e = escalas(def)
	d.BodyTypeScale = 0
	d.ProportionScale = 0
	d.HeightScale = e.Altura
	d.WidthScale = e.Anchura
	d.DepthScale = e.Profundidad
	d.HeadScale = e.Cabeza

	-- Cara del catálogo (solo si Cara es un número)
	if type(def.Cara) == "number" then
		d.Face = def.Cara
	end
	return d
end

function Fabrica.Construir(nombre, def)
	def = normalizar(def)
	local modelo = Players:CreateHumanoidModelFromDescription(Fabrica.Descripcion(def), Enum.HumanoidRigType.R15)
	modelo.Name = nombre
	for _, d in ipairs(modelo:GetDescendants()) do
		if d:IsA("LuaSourceContainer") or d:IsA("BodyColors") then
			d:Destroy()
		end
	end
	local humanoid = modelo:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	end

	-- Ropa, pelo, accesorios y cara (Atuendos)
	Atuendos().Vestir(modelo, def)

	-- Si no tiene cara propia, pone la cara clásica
	local cabeza = modelo:FindFirstChild("Head")
	if cabeza and not cabeza:FindFirstChild("Cara") and not cabeza:FindFirstChildOfClass("Decal") then
		local cara = Instance.new("Decal")
		cara.Name = "face"
		cara.Texture = CARA_POR_DEFECTO
		cara.Face = Enum.NormalId.Front
		cara.Parent = cabeza
	end
	if def.Personalidad then
		modelo:SetAttribute("Personalidad", def.Personalidad)
	end
	local raiz = modelo:FindFirstChild("HumanoidRootPart")
	if raiz then
		raiz.Anchored = true
	end
	return modelo
end

--[[
	Construye todos los personajes de "defs" dentro de "carpeta".
	defs         → tabla de DefPersonajes (si es nil, se carga el módulo)
	soloFaltantes → true = no toca los que ya existen
]]
function Fabrica.ConstruirTodos(carpeta, defs, soloFaltantes)
	defs = defs or require(script.Parent:WaitForChild("DefPersonajes"))
	local nombres = {}
	for nombre in pairs(defs) do
		table.insert(nombres, nombre)
	end
	table.sort(nombres)
	for i, nombre in ipairs(nombres) do
		local existente = carpeta:FindFirstChild(nombre)
		if not (soloFaltantes and existente) then
			local ok, modelo = pcall(Fabrica.Construir, nombre, defs[nombre])
			if ok then
				if existente then
					existente:Destroy()
				end
				modelo:PivotTo(CFrame.new((i - 1) * 5, 3, 0))
				modelo.Parent = carpeta
			else
				warn(("[Personajes] No se pudo crear '%s': %s"):format(nombre, tostring(modelo)))
			end
		end
	end
end

return Fabrica
]=======] },
	{ Ruta = "StoryTemplate/Herramientas", Nombre = "ConstructorEntornos", Clase = "ModuleScript", Fuente = [=======[
--[[
	CONSTRUCTORENTORNOS · Genera los escenarios básicos
	Studio: ReplicatedStorage > StoryTemplate > Herramientas > ConstructorEntornos

	Solo se usa al instalar (o para regenerar un escenario). En tiempo de
	ejecución el Director clona el entorno ya construido.

	Convención de todos los entornos:
	  · El suelo donde actúan los personajes está a Y = 0, alrededor de (0, 0, 0).
	  · La cámara/público está hacia +Z y los personajes miran hacia +Z.
	  · Todo es Part con SmoothPlastic: sin texturas, sin luces, sin colisiones.

	Carpeta "Marcas" de cada entorno (se vuelven invisibles al reproducir):
	  Pos_A, Pos_B, Pos_C, Pos_D → posiciones de personajes (cara FRENTE = hacia dónde miran)
	  Entrada_Izq, Entrada_Der    → puntos de entrada/salida de escena
	  Obj_1, Obj_2                → posiciones de objetos
	  Cam_General, Cam_Izquierda, Cam_Derecha, Cam_Alta → puntos de cámara fijos
	  Pared_*, Nota_* → superficies verticales donde pegar cosas (atributo Pared)
	  Silla_*         → asientos (acción Sentar)       Suelo_* → puntos del suelo
	  Audiencia                   → desde dónde "mira el público" (orienta los planos automáticos)

	Atributos del Model (iluminación que se aplica al cargarlo):
	  Hora (ClockTime), Brillo (Brightness), Ambiente (Color3), AmbienteExterior (Color3),
	  Tinte (Color3) y Saturacion (número) → tono de color de toda la imagen
]]

local Constructor = {}

local function rgb(r, g, b)
	return Color3.fromRGB(r, g, b)
end

local COLOR_MARCA = {
	Pos = rgb(60, 200, 90),
	Entrada = rgb(240, 190, 40),
	Obj = rgb(255, 130, 40),
	Cam = rgb(30, 30, 30),
	Audiencia = rgb(160, 80, 220),
	Pared = rgb(40, 170, 230),
	Nota = rgb(255, 220, 60),
	Silla = rgb(60, 200, 90),
	Suelo = rgb(255, 130, 40),
}

local function parte(padre, nombre, tam, cf, color, op)
	op = op or {}
	local p = Instance.new("Part")
	p.Name = nombre
	p.Shape = op.Forma or Enum.PartType.Block
	p.Size = tam
	p.CFrame = cf
	p.Color = color
	p.Material = op.Material or Enum.Material.SmoothPlastic
	p.Anchored = true
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.CastShadow = op.Sombra ~= false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = padre
	return p
end

-- Bloque centrado en "centro"
local function bloque(padre, nombre, tam, centro, color, op)
	return parte(padre, nombre, tam, CFrame.new(centro), color, op)
end

-- Bloque apoyado: su base está a la altura yBase
local function caja(padre, nombre, tam, x, yBase, z, color, op)
	return parte(padre, nombre, tam, CFrame.new(x, yBase + tam.Y / 2, z), color, op)
end

local function cilindroVertical(padre, nombre, altura, diametro, base, color, op)
	op = op or {}
	op.Forma = Enum.PartType.Cylinder
	local cf = CFrame.new(base + Vector3.new(0, altura / 2, 0)) * CFrame.Angles(0, 0, math.pi / 2)
	return parte(padre, nombre, Vector3.new(altura, diametro, diametro), cf, color, op)
end

local function etiqueta(p, texto, color)
	local bb = Instance.new("BillboardGui")
	bb.Name = "Etiqueta"
	bb.Size = UDim2.fromOffset(110, 20)
	bb.StudsOffset = Vector3.new(0, 1.3, 0)
	bb.AlwaysOnTop = true
	bb.MaxDistance = 150
	bb.LightInfluence = 0
	local t = Instance.new("TextLabel")
	t.Size = UDim2.fromScale(1, 1)
	t.BackgroundColor3 = color
	t.BackgroundTransparency = 0.25
	t.TextColor3 = Color3.new(1, 1, 1)
	t.TextStrokeTransparency = 0.3
	t.TextScaled = true
	t.Font = Enum.Font.GothamBold
	t.Text = texto
	t.Parent = bb
	bb.Parent = p
end

--[[
	Crea una marca.
	  Pos/Entrada/Obj : "pos" es el punto del suelo; "mirar" la dirección a la que mira.
	  Cam             : "pos" es la posición de la cámara; "mirar" el punto al que apunta.
	  Audiencia       : solo "pos".
]]
local function marca(carpeta, nombre, pos, mirar)
	local tipo = nombre:match("^(%a+)")
	local color = COLOR_MARCA[tipo] or rgb(255, 255, 255)
	local p
	if tipo == "Cam" then
		p = parte(carpeta, nombre, Vector3.new(0.8, 0.8, 1.6), CFrame.lookAt(pos, mirar), color, { Sombra = false })
	elseif tipo == "Audiencia" then
		p = parte(carpeta, nombre, Vector3.new(1, 1, 1), CFrame.new(pos), color, { Forma = Enum.PartType.Ball, Sombra = false })
	elseif tipo == "Pared" or tipo == "Nota" then
		-- Superficie vertical: "pos" está sobre la pared y "mirar" es la normal (hacia fuera)
		local n = (mirar or Vector3.new(0, 0, 1)).Unit
		local centro = pos + n * 0.05
		p = parte(carpeta, nombre, Vector3.new(0.7, 0.7, 0.1), CFrame.lookAt(centro, centro + n), color, { Sombra = false })
		p:SetAttribute("Pared", true)
	else
		local pequena = tipo == "Obj" or tipo == "Suelo" or tipo == "Silla"
		local tam = pequena and Vector3.new(1, 0.2, 1) or Vector3.new(2, 0.4, 2)
		local centro = pos + Vector3.new(0, tam.Y / 2, 0)
		local dir = mirar or Vector3.new(0, 0, 1)
		p = parte(carpeta, nombre, tam, CFrame.lookAt(centro, centro + dir), color, { Sombra = false })
		if tipo ~= "Obj" and tipo ~= "Suelo" then
			-- Indica la cara frontal (hacia donde mirará el personaje)
			local sg = Instance.new("SurfaceGui")
			sg.Name = "Frente"
			sg.Face = Enum.NormalId.Front
			sg.LightInfluence = 0
			sg.PixelsPerStud = 40
			local t = Instance.new("TextLabel")
			t.Size = UDim2.fromScale(1, 1)
			t.BackgroundColor3 = Color3.new(1, 1, 1)
			t.TextColor3 = Color3.new(0, 0, 0)
			t.TextScaled = true
			t.Font = Enum.Font.GothamBold
			t.Text = "FRENTE"
			t.Parent = sg
			sg.Parent = p
		end
	end
	p.Transparency = 0.35
	etiqueta(p, nombre, color)
	return p
end

local function camarasEstandar(M, objetivo, distancia)
	marca(M, "Cam_General", objetivo + Vector3.new(0, 3, distancia), objetivo)
	marca(M, "Cam_Izquierda", objetivo + Vector3.new(-distancia * 0.55, 2, distancia * 0.7), objetivo)
	marca(M, "Cam_Derecha", objetivo + Vector3.new(distancia * 0.55, 2, distancia * 0.7), objetivo)
	marca(M, "Cam_Alta", objetivo + Vector3.new(0, distancia * 0.7, distancia * 0.6), objetivo - Vector3.new(0, 1.5, 0))
end

local function nuevoEntorno(carpeta, nombre, atributos)
	local viejo = carpeta:FindFirstChild(nombre)
	if viejo then
		viejo:Destroy()
	end
	local m = Instance.new("Model")
	m.Name = nombre
	for k, v in pairs(atributos) do
		m:SetAttribute(k, v)
	end
	local g = Instance.new("Folder")
	g.Name = "Geometria"
	g.Parent = m
	local marcas = Instance.new("Folder")
	marcas.Name = "Marcas"
	marcas.Parent = m
	m.Parent = carpeta
	return m, g, marcas
end

-- Elementos reutilizables ------------------------------------------------------

local function arbol(g, base, escala)
	escala = escala or 1
	cilindroVertical(g, "Tronco", 6 * escala, 1 * escala, base, rgb(110, 80, 50))
	parte(
		g,
		"Copa",
		Vector3.new(7, 7, 7) * escala,
		CFrame.new(base + Vector3.new(0, 7.5 * escala, 0)),
		rgb(70, 140, 60),
		{ Forma = Enum.PartType.Ball }
	)
end

-- Banco mirando hacia +Z. Devuelve la altura del asiento.
local function banco(g, base, color)
	local gris = rgb(60, 60, 60)
	caja(g, "BancoPata", Vector3.new(0.4, 1.4, 1.4), base.X - 2, base.Y, base.Z, gris)
	caja(g, "BancoPata", Vector3.new(0.4, 1.4, 1.4), base.X + 2, base.Y, base.Z, gris)
	caja(g, "BancoAsiento", Vector3.new(5, 0.4, 1.6), base.X, base.Y + 1.4, base.Z, color)
	caja(g, "BancoRespaldo", Vector3.new(5, 1.6, 0.3), base.X, base.Y + 1.8, base.Z - 0.75, color)
	return base.Y + 1.8
end

-- ENTORNOS ---------------------------------------------------------------------

function Constructor.Calle(carpeta)
	local _, g, M = nuevoEntorno(carpeta, "Calle", { Hora = 15, Brillo = 2 })
	local acera = rgb(190, 190, 185)

	bloque(g, "Acera", Vector3.new(90, 1, 10), Vector3.new(0, -0.5, -1), acera, { Sombra = false })
	bloque(g, "Carretera", Vector3.new(90, 1, 14), Vector3.new(0, -0.8, 11), rgb(60, 60, 65), { Sombra = false })
	bloque(g, "AceraFrontal", Vector3.new(90, 1, 8), Vector3.new(0, -0.5, 22), acera, { Sombra = false })
	for i = -4, 4 do
		bloque(g, "Linea", Vector3.new(4, 0.05, 0.4), Vector3.new(i * 10, -0.275, 11), rgb(240, 240, 240), { Sombra = false })
	end

	local edificios = {
		{ -33, 12, 18, rgb(150, 95, 80) },
		{ -20, 14, 24, rgb(178, 107, 82) },
		{ -7, 12, 16, rgb(226, 203, 160) },
		{ 5, 12, 28, rgb(120, 144, 156) },
		{ 18, 14, 18, rgb(196, 160, 120) },
		{ 31, 12, 22, rgb(140, 120, 150) },
	}
	for i, e in ipairs(edificios) do
		local x, ancho, alto, color = e[1], e[2], e[3], e[4]
		caja(g, "Edificio" .. i, Vector3.new(ancho, alto, 10), x, 0, -11, color)
		for y = 9, alto - 4, 6 do
			for _, dx in ipairs({ -ancho / 4, ancho / 4 }) do
				bloque(g, "Ventana", Vector3.new(2.6, 3, 0.2), Vector3.new(x + dx, y, -5.95), rgb(160, 200, 225), { Sombra = false })
			end
		end
	end
	for _, x in ipairs({ -7, 5, 18 }) do
		caja(g, "Puerta", Vector3.new(3.5, 6.5, 0.3), x, 0, -5.9, rgb(95, 65, 45), { Sombra = false })
	end

	for _, x in ipairs({ -12, 12 }) do
		cilindroVertical(g, "Farola", 11, 0.4, Vector3.new(x, 0, 3), rgb(50, 50, 55))
		bloque(g, "FarolaLuz", Vector3.new(1.4, 0.6, 1.4), Vector3.new(x, 11.2, 3), rgb(255, 235, 170), {
			Material = Enum.Material.Neon,
			Sombra = false,
		})
	end
	arbol(g, Vector3.new(-25, 0, 1.5), 1)
	local asiento = banco(g, Vector3.new(14, 0, -4), rgb(120, 85, 55))

	local frente = Vector3.new(0, 0, 1)
	marca(M, "Pos_A", Vector3.new(-2, 0, 0), frente)
	marca(M, "Pos_B", Vector3.new(2, 0, 0), frente)
	marca(M, "Pos_C", Vector3.new(0, 0, -3), frente)
	marca(M, "Pos_D", Vector3.new(-7, 0, -2), frente)
	marca(M, "Entrada_Izq", Vector3.new(-22, 0, 0), Vector3.new(1, 0, 0))
	marca(M, "Entrada_Der", Vector3.new(22, 0, 0), Vector3.new(-1, 0, 0))
	marca(M, "Obj_1", Vector3.new(15.2, asiento, -4), frente)
	marca(M, "Obj_2", Vector3.new(-5, 0, 1.5), frente)
	camarasEstandar(M, Vector3.new(0, 3, 0), 26)
	marca(M, "Audiencia", Vector3.new(0, 4, 20))
end

function Constructor.Habitacion(carpeta)
	local _, g, M = nuevoEntorno(carpeta, "Habitacion", {
		Hora = 13,
		Brillo = 2,
		Ambiente = rgb(110, 105, 100),
	})
	local pared = rgb(232, 222, 200)
	local paredLateral = rgb(220, 208, 185)
	local madera = rgb(130, 90, 55)
	local tela = rgb(70, 95, 145)

	bloque(g, "Suelo", Vector3.new(28, 1, 22), Vector3.new(0, -0.5, -2), rgb(165, 120, 80), { Sombra = false })
	bloque(g, "ParedFondo", Vector3.new(28, 14, 1), Vector3.new(0, 7, -13.5), pared)
	bloque(g, "ParedIzquierda", Vector3.new(1, 14, 22), Vector3.new(-14.5, 7, -2), paredLateral)
	bloque(g, "ParedDerecha", Vector3.new(1, 14, 22), Vector3.new(14.5, 7, -2), paredLateral)
	bloque(g, "Zocalo", Vector3.new(28, 0.8, 0.2), Vector3.new(0, 0.4, -12.95), rgb(120, 90, 60), { Sombra = false })

	bloque(g, "MarcoVentana", Vector3.new(6.4, 5.4, 0.3), Vector3.new(6, 8, -12.9), rgb(250, 250, 250))
	bloque(g, "Ventana", Vector3.new(5.6, 4.6, 0.3), Vector3.new(6, 8, -12.8), rgb(170, 210, 235), { Sombra = false })
	bloque(g, "Cuadro", Vector3.new(4, 3, 0.2), Vector3.new(-5, 8, -12.9), rgb(90, 130, 170))
	bloque(g, "Puerta", Vector3.new(0.3, 8, 4), Vector3.new(-13.9, 4, -6), rgb(120, 80, 50))
	bloque(g, "Alfombra", Vector3.new(10, 0.06, 7), Vector3.new(0, 0.03, -1), rgb(160, 70, 70), { Sombra = false })

	-- Mesa y silla
	caja(g, "MesaTablero", Vector3.new(5, 0.3, 3), -7, 2.6, -8, madera)
	for _, d in ipairs({ { -2.2, -1.2 }, { 2.2, -1.2 }, { -2.2, 1.2 }, { 2.2, 1.2 } }) do
		caja(g, "MesaPata", Vector3.new(0.3, 2.6, 0.3), -7 + d[1], 0, -8 + d[2], madera)
	end
	caja(g, "SillaBase", Vector3.new(1.6, 1.5, 1.6), -7, 0, -5.4, madera)
	caja(g, "SillaRespaldo", Vector3.new(1.6, 2.2, 0.3), -7, 1.5, -4.75, madera)

	-- Sofá
	caja(g, "SofaBase", Vector3.new(8, 1.6, 3), 6, 0, -10.5, tela)
	caja(g, "SofaRespaldo", Vector3.new(8, 2.4, 1), 6, 1.6, -11.6, tela)
	caja(g, "SofaBrazo", Vector3.new(1, 2.4, 3), 1.5, 0, -10.5, tela)
	caja(g, "SofaBrazo", Vector3.new(1, 2.4, 3), 10.5, 0, -10.5, tela)

	-- Estantería y lámpara (sin luz real)
	caja(g, "Estanteria", Vector3.new(1.2, 7, 5), 13.4, 0, 1, madera)
	cilindroVertical(g, "LamparaPie", 6, 0.3, Vector3.new(12, 0, -11), rgb(60, 60, 60))
	parte(g, "LamparaPantalla", Vector3.new(1.4, 1.8, 1.8), CFrame.new(12, 6.4, -11) * CFrame.Angles(0, 0, math.pi / 2), rgb(245, 230, 190), {
		Forma = Enum.PartType.Cylinder,
		Sombra = false,
	})

	local frente = Vector3.new(0, 0, 1)
	marca(M, "Pos_A", Vector3.new(-2, 0, 0), frente)
	marca(M, "Pos_B", Vector3.new(2, 0, 0), frente)
	marca(M, "Pos_C", Vector3.new(0, 0, -4), frente)
	marca(M, "Pos_D", Vector3.new(6, 0, -7.5), frente)
	marca(M, "Entrada_Izq", Vector3.new(-12, 0, -6), Vector3.new(1, 0, 0))
	marca(M, "Entrada_Der", Vector3.new(12, 0, 4), Vector3.new(-1, 0, 0))
	marca(M, "Obj_1", Vector3.new(-6, 2.9, -8), frente)
	marca(M, "Obj_2", Vector3.new(-3, 0, 2), frente)
	camarasEstandar(M, Vector3.new(0, 3, -2), 22)
	marca(M, "Audiencia", Vector3.new(0, 4, 16))
end

function Constructor.Exterior(carpeta)
	local _, g, M = nuevoEntorno(carpeta, "Exterior", { Hora = 11, Brillo = 2.2 })

	bloque(g, "Cesped", Vector3.new(400, 1, 400), Vector3.new(0, -0.5, -100), rgb(100, 155, 75), { Sombra = false })
	bloque(g, "Camino", Vector3.new(5, 0.05, 120), Vector3.new(0, 0.025, -40), rgb(195, 175, 135), { Sombra = false })

	local arboles = {
		{ -12, -8, 1 },
		{ -20, -22, 1.3 },
		{ 14, -10, 1.1 },
		{ 24, -26, 1.4 },
		{ -9, -40, 1.2 },
		{ 10, -48, 1.5 },
		{ -30, -6, 1.2 },
		{ 32, -4, 1 },
	}
	for _, a in ipairs(arboles) do
		arbol(g, Vector3.new(a[1], 0, a[2]), a[3])
	end
	for _, r in ipairs({ { -6, -14, 3 }, { 7, -20, 2.2 }, { -16, 3, 2.5 } }) do
		parte(g, "Roca", Vector3.new(r[3], r[3], r[3]), CFrame.new(r[1], r[3] * 0.25, r[2]), rgb(130, 130, 125), {
			Forma = Enum.PartType.Ball,
		})
	end
	local asiento = banco(g, Vector3.new(8, 0, -4), rgb(120, 85, 55))
	parte(g, "Colina", Vector3.new(120, 120, 120), CFrame.new(-90, -35, -200), rgb(85, 140, 70), {
		Forma = Enum.PartType.Ball,
		Sombra = false,
	})
	parte(g, "Colina", Vector3.new(140, 140, 140), CFrame.new(100, -40, -220), rgb(90, 145, 75), {
		Forma = Enum.PartType.Ball,
		Sombra = false,
	})

	local frente = Vector3.new(0, 0, 1)
	marca(M, "Pos_A", Vector3.new(-2, 0, 0), frente)
	marca(M, "Pos_B", Vector3.new(2, 0, 0), frente)
	marca(M, "Pos_C", Vector3.new(0, 0, -3), frente)
	marca(M, "Pos_D", Vector3.new(0, 0, -12), frente)
	marca(M, "Entrada_Izq", Vector3.new(-22, 0, 0), Vector3.new(1, 0, 0))
	marca(M, "Entrada_Der", Vector3.new(22, 0, 0), Vector3.new(-1, 0, 0))
	marca(M, "Obj_1", Vector3.new(9.2, asiento, -4), frente)
	marca(M, "Obj_2", Vector3.new(-4, 0, 2), frente)
	camarasEstandar(M, Vector3.new(0, 3, 0), 26)
	marca(M, "Audiencia", Vector3.new(0, 4, 20))
end

function Constructor.Neutro(carpeta)
	local _, g, M = nuevoEntorno(carpeta, "Neutro", {
		Hora = 12,
		Brillo = 2,
		Ambiente = rgb(120, 115, 125),
	})
	local fondo = rgb(225, 215, 235)

	bloque(g, "Suelo", Vector3.new(60, 1, 40), Vector3.new(0, -0.5, -4), rgb(210, 200, 220), { Sombra = false })
	bloque(g, "Fondo", Vector3.new(60, 40, 1), Vector3.new(0, 20, -16.5), fondo, { Sombra = false })
	bloque(g, "FondoIzq", Vector3.new(1, 40, 40), Vector3.new(-30.5, 20, -4), fondo, { Sombra = false })
	bloque(g, "FondoDer", Vector3.new(1, 40, 40), Vector3.new(30.5, 20, -4), fondo, { Sombra = false })

	-- Pos_A y Pos_B ya están giradas una hacia la otra (posición de conversación)
	marca(M, "Pos_A", Vector3.new(-2, 0, 0), Vector3.new(0.6, 0, 1))
	marca(M, "Pos_B", Vector3.new(2, 0, 0), Vector3.new(-0.6, 0, 1))
	marca(M, "Pos_C", Vector3.new(0, 0, -3), Vector3.new(0, 0, 1))
	marca(M, "Pos_D", Vector3.new(-6, 0, -2), Vector3.new(0, 0, 1))
	marca(M, "Entrada_Izq", Vector3.new(-14, 0, 0), Vector3.new(1, 0, 0))
	marca(M, "Entrada_Der", Vector3.new(14, 0, 0), Vector3.new(-1, 0, 0))
	marca(M, "Obj_1", Vector3.new(0, 0, 2), Vector3.new(0, 0, 1))
	marca(M, "Obj_2", Vector3.new(-4, 0, 1), Vector3.new(0, 0, 1))
	camarasEstandar(M, Vector3.new(0, 3, 0), 20)
	marca(M, "Audiencia", Vector3.new(0, 4, 18))
end

-- Texto pintado en una cara de una pieza (carteles, pizarras...). Sin texturas.
local function rotulo(p, texto, fuente, color, cara, op)
	op = op or {}
	local sg = Instance.new("SurfaceGui")
	sg.Name = "Rotulo"
	sg.Face = cara or Enum.NormalId.Back
	sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	sg.PixelsPerStud = op.Densidad or 60
	sg.LightInfluence = 1
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.Size = UDim2.fromScale(op.Ancho or 0.9, op.Alto or 0.84)
	t.Position = UDim2.fromScale((1 - (op.Ancho or 0.9)) / 2, (1 - (op.Alto or 0.84)) / 2)
	t.Font = fuente
	t.TextScaled = true
	t.TextWrapped = true
	t.TextColor3 = color
	t.Text = texto
	t.Parent = sg
	sg.Parent = p
	return sg
end

-- Silla sencilla mirando hacia "dir" (+Z por defecto). Devuelve el punto central del asiento.
local function silla(g, base, color, alto, haciaAtras)
	alto = alto or 1.5
	local z = haciaAtras and -1 or 1
	caja(g, "SillaBase", Vector3.new(1.2, alto - 0.2, 1.2), base.X, base.Y, base.Z, color:Lerp(Color3.new(0, 0, 0), 0.25))
	caja(g, "SillaAsiento", Vector3.new(1.6, 0.2, 1.6), base.X, base.Y + alto - 0.2, base.Z, color)
	caja(g, "SillaRespaldo", Vector3.new(1.6, 2.2, 0.2), base.X, base.Y + alto, base.Z - 0.75 * z, color)
	return Vector3.new(base.X, base.Y + alto, base.Z)
end

-- Mesa con cuatro patas. Devuelve la altura del tablero.
local function mesa(g, centro, tam, alto, colorTablero, colorPatas)
	caja(g, "MesaTablero", Vector3.new(tam.X, 0.3, tam.Y), centro.X, alto - 0.3, centro.Z, colorTablero)
	for _, sx in ipairs({ -1, 1 }) do
		for _, sz in ipairs({ -1, 1 }) do
			caja(
				g,
				"MesaPata",
				Vector3.new(0.25, alto - 0.3, 0.25),
				centro.X + sx * (tam.X / 2 - 0.3),
				0,
				centro.Z + sz * (tam.Y / 2 - 0.3),
				colorPatas or colorTablero
			)
		end
	end
	return alto
end

local function cilindroFrontal(padre, nombre, grosor, diametro, centro, color, op)
	op = op or {}
	op.Forma = Enum.PartType.Cylinder
	return parte(padre, nombre, Vector3.new(grosor, diametro, diametro), CFrame.new(centro) * CFrame.Angles(0, math.pi / 2, 0), color, op)
end

--[[
	LABORATORIO · Laboratorio de adhesivos de los años 70
	Mesa central de trabajo junto a la pared del fondo, tablón de corcho y pizarra
	(superficies donde pegar papeles), banco de química con microscopio y matraces,
	armario de vidrio, ventana, reloj y cartel.
]]
function Constructor.Laboratorio(carpeta)
	local _, g, M = nuevoEntorno(carpeta, "Laboratorio", {
		Hora = 13,
		Brillo = 2,
		Ambiente = rgb(120, 125, 128),
		Tinte = rgb(238, 246, 255),
	})
	local pared = rgb(238, 240, 232)
	local menta = rgb(150, 195, 175)
	local madera = rgb(130, 90, 55)
	local metal = rgb(150, 152, 158)
	local negro = rgb(45, 48, 52)

	-- Suelo de baldosas
	bloque(g, "Suelo", Vector3.new(32, 1, 24), Vector3.new(0, -0.5, -3), rgb(208, 212, 204), { Sombra = false })
	for x = -12, 12, 4 do
		bloque(g, "Junta", Vector3.new(0.08, 0.02, 24), Vector3.new(x, 0.01, -3), rgb(182, 188, 180), { Sombra = false })
	end
	for z = -11, 5, 4 do
		bloque(g, "Junta", Vector3.new(32, 0.02, 0.08), Vector3.new(0, 0.01, z), rgb(182, 188, 180), { Sombra = false })
	end

	-- Paredes con zócalo verde menta
	bloque(g, "ParedFondo", Vector3.new(32, 16, 1), Vector3.new(0, 8, -15.5), pared)
	bloque(g, "ParedIzquierda", Vector3.new(1, 16, 24), Vector3.new(-16.5, 8, -3), pared)
	bloque(g, "ParedDerecha", Vector3.new(1, 16, 24), Vector3.new(16.5, 8, -3), pared)
	bloque(g, "ZocaloFondo", Vector3.new(32, 4, 0.2), Vector3.new(0, 2, -14.9), menta, { Sombra = false })
	bloque(g, "ZocaloIzq", Vector3.new(0.2, 4, 24), Vector3.new(-15.9, 2, -3), menta, { Sombra = false })
	bloque(g, "ZocaloDer", Vector3.new(0.2, 4, 24), Vector3.new(15.9, 2, -3), menta, { Sombra = false })

	-- Cartel
	local cartel = bloque(g, "Cartel", Vector3.new(11, 1.3, 0.2), Vector3.new(0, 13.2, -14.85), rgb(40, 85, 70))
	rotulo(cartel, "LABORATORIO DE ADHESIVOS", Enum.Font.GothamBold, rgb(245, 245, 235))

	-- Tablón de corcho (a la derecha) con un par de hojas clavadas
	bloque(g, "TablonMarco", Vector3.new(6.6, 4.8, 0.25), Vector3.new(2.2, 6, -14.85), madera)
	bloque(g, "TablonCorcho", Vector3.new(6, 4.2, 0.3), Vector3.new(2.2, 6, -14.8), rgb(196, 156, 104), { Sombra = false })
	local hoja1 = bloque(g, "HojaClavada", Vector3.new(1, 1.3, 0.04), Vector3.new(-0.15, 4.75, -14.63), rgb(248, 248, 244), { Sombra = false })
	rotulo(hoja1, "PRUEBA 12\n✗", Enum.Font.PatrickHand, rgb(60, 60, 70))
	bloque(g, "Chincheta", Vector3.new(0.12, 0.12, 0.12), Vector3.new(-0.15, 5.3, -14.6), rgb(200, 40, 40), { Forma = Enum.PartType.Ball })
	local hoja2 = bloque(g, "HojaClavada", Vector3.new(1.2, 0.9, 0.04), Vector3.new(4.6, 7.45, -14.63), rgb(248, 248, 244), { Sombra = false })
	rotulo(hoja2, "PRUEBA 13\n✗", Enum.Font.PatrickHand, rgb(60, 60, 70))
	bloque(g, "Chincheta", Vector3.new(0.12, 0.12, 0.12), Vector3.new(4.6, 7.8, -14.6), rgb(40, 90, 200), { Forma = Enum.PartType.Ball })

	-- Pizarra (a la izquierda) con fórmulas
	bloque(g, "PizarraMarco", Vector3.new(7.4, 4.6, 0.25), Vector3.new(-6, 6, -14.85), rgb(110, 80, 50))
	local pizarra = bloque(g, "Pizarra", Vector3.new(7, 4.2, 0.3), Vector3.new(-6, 6, -14.8), rgb(40, 70, 55), { Sombra = false })
	rotulo(pizarra, "Polímero A-174\nadhesión: BAJA\n¿utilidad?  ???", Enum.Font.PatrickHand, rgb(235, 240, 230), Enum.NormalId.Back, { Ancho = 0.62, Alto = 0.8 })
	bloque(g, "Repisa", Vector3.new(7, 0.15, 0.45), Vector3.new(-6, 3.85, -14.55), rgb(110, 80, 50))
	bloque(g, "Tiza", Vector3.new(0.4, 0.1, 0.1), Vector3.new(-8.5, 3.98, -14.5), rgb(250, 250, 250), { Sombra = false })

	-- Reloj de pared
	cilindroFrontal(g, "RelojAro", 0.15, 2.2, Vector3.new(-12, 11, -14.9), rgb(30, 30, 30))
	cilindroFrontal(g, "RelojEsfera", 0.2, 2, Vector3.new(-12, 11, -14.85), rgb(250, 250, 245))
	parte(g, "Aguja", Vector3.new(0.1, 0.75, 0.05), CFrame.new(-12, 11.3, -14.73), rgb(20, 20, 20), { Sombra = false })
	parte(g, "Aguja", Vector3.new(0.1, 0.55, 0.05), CFrame.new(-11.8, 11, -14.73) * CFrame.Angles(0, 0, math.rad(-70)), rgb(20, 20, 20), { Sombra = false })

	-- Mesa central de trabajo (encimera negra)
	caja(g, "MesaTablero", Vector3.new(6, 0.3, 3), -1, 2.85, -10, negro)
	for _, sx in ipairs({ -1, 1 }) do
		for _, sz in ipairs({ -1, 1 }) do
			caja(g, "MesaPata", Vector3.new(0.25, 2.85, 0.25), -1 + sx * 2.7, 0, -10 + sz * 1.2, metal)
		end
	end
	caja(g, "MesaBalda", Vector3.new(5.6, 0.15, 2.6), -1, 0.8, -10, metal)
	caja(g, "Folios", Vector3.new(1, 0.25, 1.3), -0.6, 3.15, -10.6, rgb(250, 250, 248), { Sombra = false })
	cilindroVertical(g, "VasoPrecipitado", 0.6, 0.45, Vector3.new(1.3, 3.15, -10.9), rgb(190, 225, 240), { Sombra = false }).Transparency = 0.35
	cilindroVertical(g, "Liquido", 0.3, 0.4, Vector3.new(1.3, 3.16, -10.9), rgb(120, 200, 120), { Sombra = false })
	cilindroVertical(g, "TuboEnsayo", 0.7, 0.18, Vector3.new(1.75, 3.15, -10.6), rgb(240, 170, 60), { Sombra = false })

	-- Banco de química a la derecha
	caja(g, "BancoMueble", Vector3.new(2.6, 2.85, 11), 14.4, 0, -8, rgb(120, 165, 150))
	caja(g, "BancoEncimera", Vector3.new(2.9, 0.3, 11.2), 14.3, 2.85, -8, negro)
	for i, z in ipairs({ -11, -9.5, -8, -6.5 }) do
		caja(g, "Cajon" .. i, Vector3.new(0.05, 1, 1.2), 13.08, 1.5, z, rgb(100, 140, 128), { Sombra = false })
	end
	-- Microscopio
	caja(g, "MicroBase", Vector3.new(0.8, 0.15, 1), 14.3, 3.15, -11.5, rgb(235, 235, 230))
	caja(g, "MicroBrazo", Vector3.new(0.25, 1.2, 0.25), 14.3, 3.3, -11.85, rgb(235, 235, 230))
	parte(g, "MicroTubo", Vector3.new(0.9, 0.25, 0.25), CFrame.new(14.3, 4.5, -11.55) * CFrame.Angles(0, 0, math.rad(70)), rgb(40, 40, 45))
	-- Matraces de colores
	for i, d in ipairs({ { -9, rgb(240, 140, 60) }, { -8, rgb(80, 150, 230) }, { -7, rgb(130, 210, 110) } }) do
		cilindroVertical(g, "Matraz" .. i, 0.5, 0.7, Vector3.new(14.3, 3.15, d[1]), d[2], { Sombra = false })
		cilindroVertical(g, "Cuello" .. i, 0.5, 0.22, Vector3.new(14.3, 3.65, d[1]), rgb(210, 235, 245), { Sombra = false })
	end
	-- Balda con frascos
	caja(g, "Balda", Vector3.new(1.3, 0.2, 10), 15.3, 7, -8, madera)
	for i, z in ipairs({ -12, -10.5, -9, -7.5, -6, -4.5 }) do
		local c = (i % 2 == 0) and rgb(120, 70, 30) or rgb(60, 110, 70)
		cilindroVertical(g, "Frasco" .. i, 0.9, 0.5, Vector3.new(15.3, 7.2, z), c, { Sombra = false })
	end
	-- Taburetes
	for _, z in ipairs({ -6, -3.5 }) do
		cilindroVertical(g, "TaburetePie", 1.9, 0.25, Vector3.new(12, 0, z), metal)
		cilindroVertical(g, "TabureteAsiento", 0.25, 1.2, Vector3.new(12, 1.9, z), rgb(60, 60, 65))
	end

	-- Armario de vidrio (izquierda) y ventana
	caja(g, "Armario", Vector3.new(2, 8, 6), -15, 0, -9, rgb(180, 186, 182))
	for _, z in ipairs({ -10.4, -7.6 }) do
		bloque(g, "ArmarioCristal", Vector3.new(0.1, 3.4, 2.5), Vector3.new(-13.97, 5.6, z), rgb(190, 220, 235), { Sombra = false })
	end
	bloque(g, "VentanaMarco", Vector3.new(0.3, 4.6, 6.2), Vector3.new(-15.9, 8.6, -1.5), rgb(245, 245, 245))
	bloque(g, "VentanaCristal", Vector3.new(0.3, 4, 5.6), Vector3.new(-15.8, 8.6, -1.5), rgb(170, 210, 240), { Sombra = false })

	-- Papelera con intentos fallidos
	cilindroVertical(g, "Papelera", 1.5, 1.2, Vector3.new(-5.2, 0, -13), rgb(120, 125, 130))
	for i, d in ipairs({ { -5.4, -12.9 }, { -5, -13.2 }, { -5.1, -12.7 } }) do
		parte(g, "PapelArrugado" .. i, Vector3.new(0.5, 0.5, 0.5), CFrame.new(d[1], 1.55 + i * 0.05, d[2]), rgb(245, 245, 240), {
			Forma = Enum.PartType.Ball,
			Sombra = false,
		})
	end

	-- Marcas
	local frente = Vector3.new(0, 0, 1)
	marca(M, "Pos_A", Vector3.new(-3.2, 0, -12.7), frente)
	marca(M, "Pos_TrasMesa", Vector3.new(1, 0, -12.7), frente)
	marca(M, "Pos_B", Vector3.new(2.6, 0, -6.5), Vector3.new(-0.5, 0, 1))
	marca(M, "Pos_C", Vector3.new(-0.5, 0, -4.5), frente)
	marca(M, "Pos_D", Vector3.new(6.5, 0, -6), Vector3.new(-1, 0, 0.3))
	marca(M, "Entrada_Izq", Vector3.new(-13, 0, -4), Vector3.new(1, 0, 0))
	marca(M, "Entrada_Der", Vector3.new(12.5, 0, -1), Vector3.new(-1, 0, 0))
	marca(M, "Obj_1", Vector3.new(-2.8, 3.15, -10.2), frente)
	marca(M, "Obj_2", Vector3.new(0.6, 3.15, -9.5), frente)
	marca(M, "Obj_3", Vector3.new(14.1, 3.15, -4.6), Vector3.new(-1, 0, 0))
	marca(M, "Obj_4", Vector3.new(14.1, 3.15, -2.9), Vector3.new(-1, 0, 0))
	marca(M, "Suelo_1", Vector3.new(10.5, 0, -2), Vector3.new(-1, 0, 0.5))
	-- Superficies de pared (cara frontal = hacia fuera de la pared)
	local corcho, encerado = -14.65, -14.65
	marca(M, "Pared_1", Vector3.new(1.6, 5, corcho), frente)
	marca(M, "Pared_2", Vector3.new(-3.7, 5, encerado), frente)
	for i, d in ipairs({ { 0.3, 7.2 }, { 1.8, 7.4 }, { 3.2, 7 }, { 3, 5.2 }, { 4.5, 5.5 }, { 1.5, 4.5 } }) do
		marca(M, "Nota_" .. i, Vector3.new(d[1], d[2], corcho), frente)
	end
	camarasEstandar(M, Vector3.new(0, 3.5, -9), 24)
	marca(M, "Cam_Tablon", Vector3.new(2.2, 6, -6.5), Vector3.new(2.2, 6, -14.7))
	marca(M, "Cam_Mesa", Vector3.new(-0.5, 5.2, -3), Vector3.new(-0.5, 3.4, -10.5))
	marca(M, "Audiencia", Vector3.new(0, 4, 14))
end

--[[
	SALAENSAYO · Sala de ensayo del coro (años 70)
	Gradas con sillas, atriles, piano vertical, vidrieras de colores, tablero de
	himnos y, en primer plano, la mesa y la silla donde Art lee su cancionero.
]]
function Constructor.SalaEnsayo(carpeta)
	local _, g, M = nuevoEntorno(carpeta, "SalaEnsayo", {
		Hora = 17.4,
		Brillo = 1.7,
		Ambiente = rgb(135, 112, 92),
		Tinte = rgb(255, 236, 210),
		Saturacion = 0.05,
	})
	local pared = rgb(232, 214, 184)
	local madera = rgb(125, 85, 52)
	local maderaClara = rgb(150, 102, 62)
	local tapizado = rgb(140, 45, 50)

	-- Suelo de tarima
	bloque(g, "Suelo", Vector3.new(32, 1, 26), Vector3.new(0, -0.5, -3), maderaClara, { Sombra = false })
	for x = -12, 12, 4.8 do
		bloque(g, "Tabla", Vector3.new(0.06, 0.02, 26), Vector3.new(x, 0.01, -3), rgb(125, 82, 48), { Sombra = false })
	end

	-- Paredes con friso de madera
	bloque(g, "ParedFondo", Vector3.new(32, 16, 1), Vector3.new(0, 8, -16.5), pared)
	bloque(g, "ParedIzquierda", Vector3.new(1, 16, 26), Vector3.new(-16.5, 8, -3), pared)
	bloque(g, "ParedDerecha", Vector3.new(1, 16, 26), Vector3.new(16.5, 8, -3), pared)
	bloque(g, "FrisoFondo", Vector3.new(32, 3.5, 0.2), Vector3.new(0, 1.75, -15.9), madera, { Sombra = false })
	bloque(g, "MolduraFondo", Vector3.new(32, 0.2, 0.35), Vector3.new(0, 3.6, -15.85), madera, { Sombra = false })
	bloque(g, "FrisoIzq", Vector3.new(0.2, 3.5, 26), Vector3.new(-15.9, 1.75, -3), madera, { Sombra = false })
	bloque(g, "FrisoDer", Vector3.new(0.2, 3.5, 26), Vector3.new(15.9, 1.75, -3), madera, { Sombra = false })

	-- Vidrieras de colores
	local colores = {
		rgb(190, 60, 60),
		rgb(60, 90, 170),
		rgb(220, 180, 60),
		rgb(60, 140, 90),
		rgb(150, 70, 150),
		rgb(230, 140, 60),
	}
	for _, x in ipairs({ -9, 9 }) do
		bloque(g, "VidrieraMarco", Vector3.new(4.2, 6.4, 0.3), Vector3.new(x, 9.2, -15.85), rgb(60, 45, 40))
		local i = 0
		for fila = 0, 2 do
			for col = 0, 1 do
				i = i + 1
				bloque(g, "Vidrio", Vector3.new(1.8, 1.9, 0.3), Vector3.new(x - 0.95 + col * 1.9, 7.2 + fila * 2, -15.8), colores[i], {
					Material = Enum.Material.Neon,
					Sombra = false,
				}).Transparency = 0.25
			end
		end
	end

	-- Tablero de himnos y cartel
	local tablero = bloque(g, "TableroHimnos", Vector3.new(3, 4, 0.25), Vector3.new(0, 9.4, -15.85), rgb(70, 45, 30))
	rotulo(tablero, "CORO\n\n12\n47\n103", Enum.Font.Antique, rgb(245, 235, 210))
	local cartel = bloque(g, "Cartel", Vector3.new(12, 1.3, 0.2), Vector3.new(0, 13.6, -15.85), rgb(245, 238, 220))
	rotulo(cartel, "ENSAYO DEL CORO · JUEVES 19:00", Enum.Font.Antique, rgb(110, 40, 40))

	-- Gradas con sillas
	caja(g, "GradaAlta", Vector3.new(22, 1.2, 2.8), 0, 0, -14.3, madera)
	caja(g, "GradaBaja", Vector3.new(22, 0.6, 2.8), 0, 0, -11.5, madera)
	for _, x in ipairs({ -6, 0, 6 }) do
		silla(g, Vector3.new(x, 1.2, -14.3), tapizado, 1.5)
		silla(g, Vector3.new(x + 3, 0.6, -11.5), tapizado, 1.5)
	end
	-- Atriles
	for _, x in ipairs({ -5, 1, 7 }) do
		cilindroVertical(g, "AtrilPie", 3, 0.15, Vector3.new(x, 0, -9), rgb(35, 35, 38))
		parte(g, "AtrilBandeja", Vector3.new(1.4, 1, 0.08), CFrame.new(x, 3.3, -8.95) * CFrame.Angles(math.rad(-25), 0, 0), rgb(35, 35, 38))
	end

	-- Piano vertical (izquierda)
	caja(g, "PianoCuerpo", Vector3.new(2.2, 4.6, 6), -12.6, 0, -6, rgb(60, 34, 22))
	caja(g, "PianoTapa", Vector3.new(2.5, 0.2, 6.3), -12.6, 4.6, -6, rgb(45, 25, 16))
	caja(g, "PianoTeclas", Vector3.new(1.1, 0.25, 5.4), -11.05, 2.5, -6, rgb(242, 240, 232))
	caja(g, "PianoTeclasNegras", Vector3.new(0.45, 0.12, 5.2), -11.35, 2.75, -6, rgb(20, 20, 20), { Sombra = false })
	parte(g, "Partitura", Vector3.new(0.05, 1, 1.4), CFrame.new(-11.45, 3.5, -6) * CFrame.Angles(0, 0, math.rad(-12)), rgb(248, 246, 238), { Sombra = false })
	caja(g, "PianoBanqueta", Vector3.new(1.4, 1.6, 3), -9.4, 0, -6, rgb(60, 34, 22))

	-- Planta
	cilindroVertical(g, "Maceta", 1.2, 1.2, Vector3.new(13.5, 0, -13), rgb(170, 90, 60))
	parte(g, "Planta", Vector3.new(2.4, 2.4, 2.4), CFrame.new(13.5, 2.4, -13), rgb(70, 130, 60), { Forma = Enum.PartType.Ball })

	-- Mesa y silla de Art (primer término, mirando a cámara)
	local alto = mesa(g, Vector3.new(2.5, 0, -2.5), Vector2.new(4.4, 2.6), 2.75, rgb(140, 95, 55))
	local asiento = silla(g, Vector3.new(2.5, 0, -5), rgb(120, 80, 48), 1.5)
	-- Pila de cancioneros y lámpara de mesa
	for i, c in ipairs({ rgb(110, 30, 40), rgb(30, 60, 110), rgb(110, 30, 40) }) do
		caja(g, "CancioneroPila" .. i, Vector3.new(0.9, 0.22, 1.2), 0.9, alto + (i - 1) * 0.22, -2.1, c, { Sombra = false })
	end
	cilindroVertical(g, "LamparaPie", 1.2, 0.12, Vector3.new(4.2, alto, -3.4), rgb(40, 40, 40))
	parte(g, "LamparaPantalla", Vector3.new(0.7, 0.7, 0.7), CFrame.new(4.2, alto + 1.35, -3.2), rgb(40, 110, 70), {
		Forma = Enum.PartType.Ball,
	})
	-- Papeles sueltos sobre la mesa
	for i, d in ipairs({ { 3.6, -2.2, 12 }, { 3.9, -1.9, -20 } }) do
		parte(g, "PapelSuelto" .. i, Vector3.new(0.85, 0.03, 1.1), CFrame.new(d[1], alto + 0.02 * i, d[2]) * CFrame.Angles(0, math.rad(d[3]), 0), rgb(248, 248, 242), {
			Sombra = false,
		})
	end

	local frente = Vector3.new(0, 0, 1)
	marca(M, "Silla_1", asiento, frente)
	marca(M, "Obj_Libro", Vector3.new(2.4, alto, -3), frente)
	marca(M, "Obj_Papeles", Vector3.new(3.7, alto + 0.05, -2.9), frente)
	marca(M, "Obj_Nota", Vector3.new(1.4, alto, -3.1), frente)
	marca(M, "Suelo_Libro", Vector3.new(3.1, 0, -0.5), frente)
	marca(M, "Pos_A", Vector3.new(-2, 0, -2), frente)
	marca(M, "Pos_B", Vector3.new(6, 0, -2), frente)
	marca(M, "Pos_C", Vector3.new(0, 0, -7), frente)
	marca(M, "Pos_D", Vector3.new(-8, 0, -4), frente)
	marca(M, "Entrada_Izq", Vector3.new(-13, 0, 0), Vector3.new(1, 0, 0))
	marca(M, "Entrada_Der", Vector3.new(13, 0, 0), Vector3.new(-1, 0, 0))
	camarasEstandar(M, Vector3.new(1, 3, -5), 22)
	marca(M, "Cam_Mesa", Vector3.new(2.5, 3.9, 4.5), Vector3.new(2.5, 2.7, -3))
	marca(M, "Audiencia", Vector3.new(1, 4, 16))
end

Constructor.Lista = { "Calle", "Habitacion", "Exterior", "Neutro", "Laboratorio", "SalaEnsayo" }

function Constructor.ConstruirTodos(carpeta)
	for _, nombre in ipairs(Constructor.Lista) do
		Constructor[nombre](carpeta)
	end
end

return Constructor
]=======] },
	{ Ruta = "StoryTemplate/Herramientas", Nombre = "ConstructorObjetos", Clase = "ModuleScript", Fuente = [=======[
--[[
	CONSTRUCTOROBJETOS · Genera los objetos (props) básicos
	Studio: ReplicatedStorage > StoryTemplate > Herramientas > ConstructorObjetos

	Cada objeto es un Model pequeño (1-2 Parts, sin texturas) con:
	  · PrimaryPart = la pieza principal (por ahí se agarra).
	  · Atributo "OffsetAgarre" (CFrame) = cómo se coloca en la mano derecha.
	  · Atributo "Plano" = true en hojas y notas: su cara grande es la frontal (-Z),
	    se pegan planas en paredes y mesas y caen como un papel.

	Puedes añadir tus propios objetos directamente en StoryTemplate > Objetos:
	cualquier Model sirve (si no tiene PrimaryPart se usa su primera pieza).
]]

local Constructor = {}

local function rgb(r, g, b)
	return Color3.fromRGB(r, g, b)
end

local function nuevo(carpeta, nombre, offset)
	local viejo = carpeta:FindFirstChild(nombre)
	if viejo then
		viejo:Destroy()
	end
	local m = Instance.new("Model")
	m.Name = nombre
	m:SetAttribute("OffsetAgarre", offset or CFrame.new())
	m.Parent = carpeta
	return m
end

local function plano(m)
	m:SetAttribute("Plano", true)
	return m
end

-- Texto impreso o escrito en la cara frontal de una pieza
local function escrito(p, texto, fuente, color, cara)
	local sg = Instance.new("SurfaceGui")
	sg.Name = "Escrito"
	sg.Face = cara or Enum.NormalId.Front
	sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	sg.PixelsPerStud = 120
	sg.LightInfluence = 1
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.Size = UDim2.fromScale(0.86, 0.8)
	t.Position = UDim2.fromScale(0.07, 0.1)
	t.Font = fuente
	t.TextScaled = true
	t.TextWrapped = true
	t.TextColor3 = color
	t.Text = texto
	t.Parent = sg
	sg.Parent = p
end

local function pieza(m, nombre, tam, cf, color)
	local p = Instance.new("Part")
	p.Name = nombre
	p.Size = tam
	p.CFrame = cf
	p.Color = color
	p.Material = Enum.Material.SmoothPlastic
	p.Anchored = true
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = m
	return p
end

function Constructor.ConstruirTodos(carpeta)
	-- Caja de cartón
	local m = nuevo(carpeta, "Caja", CFrame.new(0, 0.3, -0.45))
	m.PrimaryPart = pieza(m, "Cuerpo", Vector3.new(1.3, 1, 1.1), CFrame.new(), rgb(190, 150, 100))
	pieza(m, "Cinta", Vector3.new(0.3, 1.02, 1.12), CFrame.new(), rgb(225, 205, 150))

	-- Sobre / carta
	m = nuevo(carpeta, "Sobre", CFrame.new(0, 0.2, -0.35) * CFrame.Angles(math.rad(70), 0, 0))
	m.PrimaryPart = pieza(m, "Papel", Vector3.new(1.1, 0.06, 0.75), CFrame.new(), rgb(245, 240, 225))
	pieza(m, "Sello", Vector3.new(0.22, 0.08, 0.22), CFrame.new(0, 0.01, 0), rgb(180, 30, 30))

	-- Teléfono móvil
	m = nuevo(carpeta, "Telefono", CFrame.new(0, 0.15, -0.25) * CFrame.Angles(math.rad(60), 0, 0))
	m.PrimaryPart = pieza(m, "Carcasa", Vector3.new(0.45, 0.06, 0.85), CFrame.new(), rgb(25, 25, 30))
	pieza(m, "Pantalla", Vector3.new(0.39, 0.065, 0.75), CFrame.new(0, 0.002, 0), rgb(60, 120, 200))

	-- Libro
	m = nuevo(carpeta, "Libro", CFrame.new(0, 0.2, -0.4))
	m.PrimaryPart = pieza(m, "Tapas", Vector3.new(0.9, 0.25, 1.2), CFrame.new(), rgb(150, 40, 45))
	pieza(m, "Paginas", Vector3.new(0.86, 0.2, 1.1), CFrame.new(0.03, 0, 0), rgb(245, 240, 225))

	-- Bolsa
	m = nuevo(carpeta, "Bolsa", CFrame.new(0, -0.2, -0.5))
	m.PrimaryPart = pieza(m, "Cuerpo", Vector3.new(1.2, 1.3, 0.6), CFrame.new(), rgb(205, 175, 125))
	pieza(m, "Borde", Vector3.new(1.22, 0.15, 0.62), CFrame.new(0, 0.58, 0), rgb(150, 115, 70))

	--==========================================================================
	-- HISTORIA: EL ORIGEN DEL POST-IT
	-- Hojas y notas: finas en Z, cara frontal = -Z (en la mano mira hacia delante).
	--==========================================================================

	-- Folio con unas líneas de texto
	m = plano(nuevo(carpeta, "Papel", CFrame.new(0, 0.5, -0.1)))
	m.PrimaryPart = pieza(m, "Hoja", Vector3.new(1, 1.3, 0.03), CFrame.new(), rgb(248, 248, 245))
	for i, y in ipairs({ 0.4, 0.2, 0, -0.2 }) do
		pieza(m, "Linea" .. i, Vector3.new(0.7 - i * 0.05, 0.04, 0.032), CFrame.new(-0.05, y, 0), rgb(150, 150, 160))
	end

	-- Hoja con el pegamento de Spencer (crema, con la franja adhesiva arriba)
	m = plano(nuevo(carpeta, "PapelAdhesivo", CFrame.new(0, 0.35, -0.1)))
	m.PrimaryPart = pieza(m, "Hoja", Vector3.new(0.75, 0.75, 0.03), CFrame.new(), rgb(250, 241, 205))
	pieza(m, "Franja", Vector3.new(0.75, 0.13, 0.034), CFrame.new(0, 0.31, 0), rgb(232, 216, 160))

	-- Nota adhesiva amarilla (Post-it)
	m = plano(nuevo(carpeta, "NotaAmarilla", CFrame.new(0, 0.3, -0.1)))
	m.PrimaryPart = pieza(m, "Hoja", Vector3.new(0.6, 0.6, 0.03), CFrame.new(), rgb(255, 225, 60))
	pieza(m, "Franja", Vector3.new(0.6, 0.1, 0.034), CFrame.new(0, 0.25, 0), rgb(242, 205, 45))

	-- Marcapáginas de papel
	m = plano(nuevo(carpeta, "Marcapaginas", CFrame.new(0, 0.45, -0.1)))
	m.PrimaryPart = pieza(m, "Tira", Vector3.new(0.3, 1.1, 0.03), CFrame.new(), rgb(246, 246, 240))
	pieza(m, "Borla", Vector3.new(0.1, 0.25, 0.04), CFrame.new(0, -0.62, 0), rgb(180, 40, 45))

	-- Bloc de notas amarillas
	m = plano(nuevo(carpeta, "BlocNotas", CFrame.new(0, 0.4, -0.25)))
	m.PrimaryPart = pieza(m, "Bloque", Vector3.new(0.9, 0.9, 0.3), CFrame.new(), rgb(250, 215, 50))
	pieza(m, "HojaSuperior", Vector3.new(0.9, 0.9, 0.02), CFrame.new(0, 0, -0.155), rgb(255, 230, 80))
	pieza(m, "Canto", Vector3.new(0.92, 0.08, 0.31), CFrame.new(0, 0.42, 0), rgb(235, 195, 40))

	-- Cancionero cerrado (granate con franja dorada)
	m = nuevo(carpeta, "Cancionero", CFrame.new(0, 0.1, -0.5) * CFrame.Angles(math.rad(-80), 0, 0))
	m.PrimaryPart = pieza(m, "Tapa", Vector3.new(0.95, 0.28, 1.25), CFrame.new(), rgb(110, 30, 40))
	pieza(m, "Paginas", Vector3.new(0.9, 0.24, 1.2), CFrame.new(0.04, 0, 0), rgb(245, 238, 220))
	pieza(m, "Franja", Vector3.new(0.96, 0.29, 0.12), CFrame.new(0, 0, -0.42), rgb(210, 170, 70))

	-- Cancionero abierto sobre la mesa
	m = nuevo(carpeta, "CancioneroAbierto", CFrame.new(0, 0.1, -0.5) * CFrame.Angles(math.rad(-70), 0, 0))
	m.PrimaryPart = pieza(m, "Tapas", Vector3.new(1.95, 0.05, 1.3), CFrame.new(), rgb(110, 30, 40))
	pieza(m, "PaginasIzq", Vector3.new(0.92, 0.12, 1.2), CFrame.new(-0.48, 0.08, 0) * CFrame.Angles(0, 0, math.rad(4)), rgb(245, 238, 220))
	pieza(m, "PaginasDer", Vector3.new(0.92, 0.12, 1.2), CFrame.new(0.48, 0.08, 0) * CFrame.Angles(0, 0, math.rad(-4)), rgb(245, 238, 220))
	pieza(m, "Lomo", Vector3.new(0.05, 0.14, 1.2), CFrame.new(0, 0.07, 0), rgb(200, 190, 170))
	for i, z in ipairs({ -0.35, -0.15, 0.05, 0.25 }) do
		pieza(m, "Pentagrama" .. i, Vector3.new(0.7, 0.01, 0.03), CFrame.new(-0.5, 0.145, z), rgb(120, 110, 100))
		pieza(m, "Pentagrama" .. i, Vector3.new(0.7, 0.01, 0.03), CFrame.new(0.5, 0.145, z), rgb(120, 110, 100))
	end

	-- Bote de pegamento con pincel
	m = nuevo(carpeta, "Pegamento", CFrame.new(0, 0.2, -0.3))
	m.PrimaryPart = pieza(m, "Bote", Vector3.new(0.6, 0.55, 0.55), CFrame.Angles(0, 0, math.pi / 2), rgb(175, 115, 45))
	m.PrimaryPart.Shape = Enum.PartType.Cylinder
	m.PrimaryPart.Size = Vector3.new(0.6, 0.55, 0.55)
	m.PrimaryPart.Transparency = 0.15
	local etiqueta = pieza(m, "Etiqueta", Vector3.new(0.25, 0.57, 0.57), CFrame.Angles(0, 0, math.pi / 2), rgb(245, 245, 240))
	etiqueta.Shape = Enum.PartType.Cylinder
	etiqueta.Size = Vector3.new(0.25, 0.57, 0.57)
	local tapa = pieza(m, "Tapa", Vector3.new(0.12, 0.6, 0.6), CFrame.new(0, 0.36, 0) * CFrame.Angles(0, 0, math.pi / 2), rgb(30, 30, 30))
	tapa.Shape = Enum.PartType.Cylinder
	tapa.Size = Vector3.new(0.12, 0.6, 0.6)
	pieza(m, "Pincel", Vector3.new(0.07, 0.6, 0.07), CFrame.new(0.08, 0.55, 0) * CFrame.Angles(0, 0, math.rad(-15)), rgb(150, 100, 55))

	-- Caja de producto (notas adhesivas listas para las tiendas)
	m = nuevo(carpeta, "CajaNotas", CFrame.new(0, 0.3, -0.5))
	m.PrimaryPart = pieza(m, "Caja", Vector3.new(1.6, 1, 1.2), CFrame.new(), rgb(250, 205, 40))
	local franja = pieza(m, "Franja", Vector3.new(1.62, 0.35, 1.22), CFrame.new(0, 0, 0), rgb(255, 245, 220))
	escrito(franja, "NOTAS ADHESIVAS", Enum.Font.GothamBold, rgb(60, 50, 30), Enum.NormalId.Back)
	escrito(franja, "NOTAS ADHESIVAS", Enum.Font.GothamBold, rgb(60, 50, 30), Enum.NormalId.Front)
end

return Constructor
]=======] },
	{ Ruta = "StoryTemplate/Escenas", Nombre = "_PlantillaEscena", Clase = "ModuleScript", Fuente = [=======[
--[[
	PLANTILLA DE ESCENA · Copia este ModuleScript para crear una escena nueva
	Studio: ReplicatedStorage > StoryTemplate > Escenas > _PlantillaEscena

	1. Duplica este ModuleScript (Ctrl+D) y renómbralo (p. ej. "Historia01_Escena1").
	2. Rellena los apartados de abajo.
	3. En StoryTemplate > Config pon  Config.EscenaActiva = "Historia01_Escena1"
	4. Pulsa Play (F5).

	REGLA DE TIEMPO: cada paso espera a que termine su acción (caminar, gesto,
	sonido...) antes de pasar al siguiente. Añade  Paralelo = true  para que
	el siguiente paso empiece a la vez, y  Pausa = segundos  para esperar más.

	ACCIONES DISPONIBLES (ejemplos completos en README.md)
	  Esperar    { Accion = "Esperar", Tiempo = 1 }
	  Colocar    { Accion = "Colocar", Actor = "Protagonista", En = "Pos_A", MirarA = "Camara" }
	  Ocultar    { Accion = "Ocultar", Actor = "Secundario1" }
	  Caminar    { Accion = "Caminar", Actor = "Protagonista", Hasta = "Pos_B", Desde = "Entrada_Izq", MirarA = "Secundario1" }
	  Correr     { Accion = "Correr",  Actor = "Protagonista", Hasta = "Secundario1", Distancia = 3 }
	  Mirar      { Accion = "Mirar", Actor = "Protagonista", A = "Secundario1", SoloCabeza = false }
	  Hablar     { Accion = "Hablar", Actor = "Protagonista", Duracion = 3 }   (o Sonido = "Voz1"; SoloBoca = true sin gestos)
	  Senalar    { Accion = "Senalar", Actor = "Protagonista", A = "Obj_1" }
	  Sorpresa   { Accion = "Sorpresa", Actor = "Secundario1" }
	  Gesto      { Accion = "Gesto", Actor = "Protagonista", Gesto = "Pensar", Duracion = 2, Mantener = false }
	  Animacion  { Accion = "Animacion", Actor = "Protagonista", Clip = "Saludar" }
	  Entregar   { Accion = "Entregar", De = "Protagonista", A = "Secundario1", Objeto = "Caja" }
	  Recoger    { Accion = "Recoger", Actor = "Protagonista", Objeto = "Caja" }
	  Soltar     { Accion = "Soltar", Actor = "Protagonista", En = "Obj_1" }
	  Objeto     { Accion = "Objeto", Objeto = "Caja", En = "Obj_2" }  /  EnManoDe = "Rol"  /  Visible = false
	  Camara     { Accion = "Camara", Plano = "DosPersonajes", Actores = {"Protagonista","Secundario1"}, Transicion = 1 }
	  Sonido     { Accion = "Sonido", Sonido = "Narracion", Volumen = 1, Paralelo = true }
	  Musica     { Accion = "Musica", Sonido = "Musica", Volumen = 0.3 }   /  Parar = true
	  Entorno    { Accion = "Entorno", Nombre = "Habitacion" }
]]

return {
	-- Escenario inicial: "Calle", "Habitacion", "Exterior", "Neutro" (o uno tuyo)
	Entorno = "Neutro",

	-- ROL = MODELO. Los pasos usan el rol; el modelo sale de StoryTemplate > Personajes.
	-- Para cambiar quién hace de protagonista basta con cambiar el modelo aquí.
	Reparto = {
		Protagonista = "Protagonista",
		Secundario1 = "Secundario1",
		Secundario2 = "Secundario2",
	},

	-- Dónde está cada rol al empezar. Los que no aparezcan aquí no se ven
	-- hasta que un paso los coloque (Colocar o Caminar con Desde).
	Posiciones = {
		Protagonista = "Pos_A",
		Secundario1 = { Marca = "Pos_B", MirarA = "Protagonista" },
	},

	-- Objetos al empezar:  Nombre = "Marca"  o  Nombre = { Modelo = "Caja", En = "Obj_1" }
	--                      o  Nombre = { EnManoDe = "Protagonista" }
	Objetos = {
		-- Caja = "Obj_1",
	},

	-- Música de fondo (Sound de StoryTemplate > Audio o id numérico)
	-- Musica = { Sonido = "Musica", Volumen = 0.3 },

	-- Plano inicial
	Camara = { Plano = "DosPersonajes" },

	Pasos = {
		{ Accion = "Hablar", Actor = "Protagonista", Duracion = 2 },
		{ Accion = "Camara", Plano = "PrimerPlano", Actor = "Secundario1" },
		{ Accion = "Hablar", Actor = "Secundario1", Duracion = 2 },
		{ Accion = "Esperar", Tiempo = 1 },
	},
}
]=======] },
	{ Ruta = "StoryTemplate/Escenas", Nombre = "Prueba_Plantilla", Clase = "ModuleScript", Fuente = [=======[
--[[
	PRUEBA_PLANTILLA · Escena técnica de prueba (no es una historia)
	Studio: ReplicatedStorage > StoryTemplate > Escenas > Prueba_Plantilla

	Recorre todos los recursos de la plantilla para comprobar que funcionan:
	los 3 personajes, los 4 entornos, todas las animaciones y gestos,
	todos los planos de cámara, y entregar / recoger objetos.
	Dura aproximadamente 1 minuto. Mira la ventana Output por si hay avisos.
]]

return {
	Entorno = "Calle",
	Reparto = {
		Protagonista = "Protagonista",
		Secundario1 = "Secundario1",
		Secundario2 = "Secundario2",
	},
	Posiciones = {
		Secundario1 = { Marca = "Pos_B", MirarA = "Camara" },
	},
	Objetos = {
		Caja = "Obj_2",
	},
	Camara = { Plano = "Fija", Marca = "Cam_General" },

	Pasos = {
		-- 1 · CALLE: entrada caminando, plano fijo
		{ Accion = "Caminar", Actor = "Protagonista", Desde = "Entrada_Izq", Hasta = "Pos_A", MirarA = "Secundario1" },

		-- 2 · Conversación: dos personajes, mirar, saludar, hablar
		{ Accion = "Camara", Plano = "DosPersonajes", Actores = { "Protagonista", "Secundario1" }, Transicion = 1 },
		{ Accion = "Mirar", Actor = "Secundario1", A = "Protagonista" },
		{ Accion = "Animacion", Actor = "Secundario1", Clip = "Saludar", Paralelo = true },
		{ Accion = "Hablar", Actor = "Protagonista", Duracion = 2.5 },
		{ Accion = "Camara", Plano = "PrimerPlano", Actor = "Secundario1" },
		{ Accion = "Hablar", Actor = "Secundario1", Duracion = 2 },
		{ Accion = "Gesto", Actor = "Secundario1", Gesto = "Asentir" },

		-- 3 · Señalar y recoger un objeto
		{ Accion = "Camara", Plano = "Medio", Transicion = 0.6 },
		{ Accion = "Senalar", Actor = "Protagonista", A = "Caja" },
		{ Accion = "Camara", Plano = "Personaje", Actor = "Protagonista", Encuadre = "Cuerpo", Seguir = true },
		{ Accion = "Caminar", Actor = "Protagonista", Hasta = "Caja" },
		{ Accion = "Recoger", Actor = "Protagonista", Objeto = "Caja" },

		-- 4 · Entregar el objeto
		{ Accion = "Caminar", Actor = "Protagonista", Hasta = "Secundario1", Distancia = 2.6 },
		{ Accion = "Camara", Plano = "DosPersonajes", Transicion = 0.8 },
		{ Accion = "Entregar", De = "Protagonista", A = "Secundario1" },

		-- 5 · Sorpresa en primer plano con zoom lento
		{ Accion = "Camara", Plano = "PrimerPlano", Actor = "Secundario1", Acercar = 1.5, TiempoAcercar = 2 },
		{ Accion = "Mirar", Actor = "Secundario1", A = "Camara" },
		{ Accion = "Sorpresa", Actor = "Secundario1" },

		-- 6 · Tercer personaje entra corriendo, la cámara le sigue
		{ Accion = "Colocar", Actor = "Secundario2", En = "Entrada_Der" },
		{ Accion = "Camara", Plano = "Personaje", Actor = "Secundario2", Encuadre = "Cuerpo", Seguir = true },
		{ Accion = "Correr", Actor = "Secundario2", Hasta = "Pos_C", MirarA = "Camara" },
		{ Accion = "Camara", Plano = "General", Transicion = 1 },
		{ Accion = "Gesto", Actor = "Secundario2", Gesto = "Negar" },
		{ Accion = "Gesto", Actor = "Protagonista", Gesto = "Pensar" },

		-- 7 · Recorrido por los demás entornos con los puntos de cámara fijos
		{ Accion = "Entorno", Nombre = "Habitacion" },
		{ Accion = "Colocar", Actor = "Protagonista", En = "Pos_A", MirarA = "Camara" },
		{ Accion = "Colocar", Actor = "Secundario1", En = "Pos_B", MirarA = "Camara" },
		{ Accion = "Colocar", Actor = "Secundario2", En = "Pos_C", MirarA = "Camara" },
		{ Accion = "Camara", Plano = "Fija", Marca = "Cam_General" },
		{ Accion = "Soltar", Actor = "Secundario1", En = "Obj_1" },
		{ Accion = "Camara", Plano = "Fija", Marca = "Cam_Izquierda", Transicion = 1.5, Pausa = 2 },
		{ Accion = "Camara", Plano = "Fija", Marca = "Cam_Derecha", Transicion = 1.5, Pausa = 2 },
		{ Accion = "Camara", Plano = "Fija", Marca = "Cam_Alta", Transicion = 1.5, Pausa = 2 },
		{ Accion = "Esperar", Tiempo = 1.5 },

		{ Accion = "Entorno", Nombre = "Exterior" },
		{ Accion = "Colocar", Actor = "Protagonista", En = "Pos_A", MirarA = "Camara" },
		{ Accion = "Colocar", Actor = "Secundario1", En = "Pos_B", MirarA = "Camara" },
		{ Accion = "Ocultar", Actor = "Secundario2" },
		{ Accion = "Camara", Plano = "General" },
		{ Accion = "Animacion", Actor = "Protagonista", Clip = "Celebrar", Paralelo = true },
		{ Accion = "Correr", Actor = "Secundario1", Hasta = "Pos_D" },
		{ Accion = "Esperar", Tiempo = 1 },

		{ Accion = "Entorno", Nombre = "Neutro" },
		{ Accion = "Colocar", Actor = "Protagonista", En = "Pos_A" },
		{ Accion = "Colocar", Actor = "Secundario1", En = "Pos_B" },
		{ Accion = "Camara", Plano = "DosPersonajes" },
		{ Accion = "Hablar", Actor = "Protagonista", Duracion = 2, Paralelo = true },
		{ Accion = "Mirar", Actor = "Secundario1", A = "Protagonista", SoloCabeza = true },
		{ Accion = "Camara", Plano = "Fija", Marca = "Cam_General", Transicion = 2 },
		{ Accion = "Esperar", Tiempo = 2.5 },
	},
}
]=======] },
	{ Ruta = "StoryTemplate/Escenas", Nombre = "Prueba_Caras", Clase = "ModuleScript", Fuente = [=======[
--[[
	PRUEBA_CARAS · Escena técnica de prueba de caras (no es una historia)
	Studio: ReplicatedStorage > StoryTemplate > Escenas > Prueba_Caras

	Los 3 personajes, uno al lado del otro y mirando a cámara, quietos.
	Parpadean solos todo el rato y van hablando por turnos (solo la boca,
	sin gestos de brazos). Al final hablan los tres a la vez.

	Para verla: en StoryTemplate > Config pon  Config.EscenaActiva = "Prueba_Caras"
]]

return {
	Entorno = "Neutro",
	Reparto = {
		Protagonista = "Protagonista",
		Secundario1 = "Secundario1",
		Secundario2 = "Secundario2",
	},
	Posiciones = {
		Protagonista = { En = Vector3.new(-2.4, 0, 0), MirarA = "Camara" },
		Secundario1 = { En = Vector3.new(0, 0, -0.5), MirarA = "Camara" },
		Secundario2 = { En = Vector3.new(2.4, 0, 0), MirarA = "Camara" },
	},
	Camara = { Plano = "Medio", Encuadre = "Cara", Inclinacion = 0 },

	Pasos = {
		-- Los tres quietos, solo parpadean
		{ Accion = "Esperar", Tiempo = 3 },

		-- Habla cada uno en su primer plano
		{ Accion = "Camara", Plano = "PrimerPlano", Actor = "Protagonista", Angulo = 0 },
		{ Accion = "Hablar", Actor = "Protagonista", Duracion = 3, SoloBoca = true },
		{ Accion = "Esperar", Tiempo = 1.5 },

		{ Accion = "Camara", Plano = "PrimerPlano", Actor = "Secundario1", Angulo = 0 },
		{ Accion = "Hablar", Actor = "Secundario1", Duracion = 3, SoloBoca = true },
		{ Accion = "Esperar", Tiempo = 1.5 },

		{ Accion = "Camara", Plano = "PrimerPlano", Actor = "Secundario2", Angulo = 0 },
		{ Accion = "Hablar", Actor = "Secundario2", Duracion = 3, SoloBoca = true },
		{ Accion = "Esperar", Tiempo = 1.5 },

		-- Los tres juntos, por turnos y luego a la vez
		{ Accion = "Camara", Plano = "Medio", Encuadre = "Cara", Inclinacion = 0, Transicion = 1 },
		{ Accion = "Hablar", Actor = "Protagonista", Duracion = 1.5, SoloBoca = true },
		{ Accion = "Hablar", Actor = "Secundario1", Duracion = 1.5, SoloBoca = true },
		{ Accion = "Hablar", Actor = "Secundario2", Duracion = 1.5, SoloBoca = true },
		{ Accion = "Hablar", Actor = "Protagonista", Duracion = 3, SoloBoca = true, Paralelo = true },
		{ Accion = "Hablar", Actor = "Secundario1", Duracion = 3, SoloBoca = true, Paralelo = true },
		{ Accion = "Hablar", Actor = "Secundario2", Duracion = 3, SoloBoca = true },
		{ Accion = "Esperar", Tiempo = 3 },
	},
}
]=======] },
	{ Ruta = "StoryTemplate/Escenas", Nombre = "Historia_PostIt", Clase = "ModuleScript", Fuente = [=======[
--[[
	HISTORIA_POSTIT · «El pegamento que no pegaba» (Guion.md, 6 escenas)
	Studio: ReplicatedStorage > StoryTemplate > Escenas > Historia_PostIt

	Toda la escena es una LÍNEA DE TIEMPO: cada paso tiene  T = segundo  y se
	ejecuta exactamente en ese momento (contado desde el primer paso).
	Las voces (Audio/postit1..11.WAV) empiezan en los segundos de la tabla VOZ y
	cada acción se ancla a una voz:  T = en("postit2", 1.5)  = 1.5 s después de
	que empiece postit2. Así, si cambias un audio, basta con mover su entrada en VOZ.

	Duración de cada audio y tramos con voz (medidos por Audio/analizar_audio.py):
	  postit1  4.20 s  [0.18-1.96] [2.38-4.08]
	  postit2  4.20 s  [0.52-1.82] [2.00-4.10]
	  postit3  1.30 s  [0.36-1.20]
	  postit4  4.04 s  [0.28-1.94] [2.26-3.94]
	  postit5  1.07 s  [0.26-0.94]
	  postit6  2.88 s  [0.32-2.80]
	  postit7  2.11 s  [0.22-1.84]
	  postit8  2.88 s  [0.16-1.00] [1.36-2.64]
	  postit9  5.43 s  [0.22-2.08] [2.50-3.86] [4.02-5.24]
	  postit10 8.75 s  [0.36-1.46] [1.72-3.62] [4.24-6.40] [7.36-8.58]
	  postit11 1.65 s  [0.24-1.48]

	Personajes: Spencer (químico, bata y gafas) y Art (ingeniero y narrador).
	Escenarios: Laboratorio y SalaEnsayo.
]]

-- Segundo de la escena en el que empieza cada audio (tabla de sincronización)
local VOZ = {
	postit1 = 0.00, -- Escena 1
	postit2 = 5.20, -- Escena 2
	postit3 = 9.75,
	postit4 = 12.45, -- Escena 3
	postit5 = 16.60,
	postit6 = 17.95, -- Escena 4
	postit7 = 21.10,
	postit8 = 23.75, -- Escena 5
	postit9 = 26.95,
	postit10 = 32.55, -- Escena 6
	postit11 = 41.80,
}
local FIN = 47.0

local function en(voz, mas)
	return VOZ[voz] + (mas or 0)
end

local NOTA_AMARILLA = Color3.fromRGB(255, 225, 60)
local NOTA_ROSA = Color3.fromRGB(255, 160, 190)
local NOTA_AZUL = Color3.fromRGB(140, 205, 245)
local NOTA_VERDE = Color3.fromRGB(170, 230, 140)

return {
	Entorno = "Laboratorio",

	Reparto = {
		Spencer = "Spencer",
		Art = "Art",
	},

	Posiciones = {
		Spencer = "Pos_TrasMesa",
		Art = { Marca = "Pos_A", MirarA = "Camara" },
	},

	-- Objetos: los que tienen En / EnManoDe aparecen al empezar; el resto se usan más tarde.
	Objetos = {
		Muestra = { Modelo = "PapelAdhesivo", EnManoDe = "Spencer" }, -- el papel con el pegamento de Spencer
		Bote = { Modelo = "Pegamento", En = "Obj_1" },
		Recuerdo = { Modelo = "PapelAdhesivo" }, -- el que aparece en el flashback
		Cancionero = { Modelo = "Cancionero" },
		CancioneroAbierto = { Modelo = "CancioneroAbierto" },
		Marcapaginas = { Modelo = "Marcapaginas" },
		Bloc = { Modelo = "BlocNotas" },
		CajaA = { Modelo = "CajaNotas" },
		CajaB = { Modelo = "CajaNotas" },
		CajaC = { Modelo = "CajaNotas" },
		Nota1 = { Modelo = "NotaAmarilla", Texto = "¡Reunión 3pm!", Color = NOTA_AMARILLA },
		Nota2 = { Modelo = "NotaAmarilla", Texto = "Llamar a Bob", Color = NOTA_ROSA },
		Nota3 = { Modelo = "NotaAmarilla", Texto = "Comprar café", Color = NOTA_AZUL },
		Nota4 = { Modelo = "NotaAmarilla", Texto = "¡Funciona!", Color = NOTA_AMARILLA },
		Nota5 = { Modelo = "NotaAmarilla", Texto = "Ensayo jueves", Color = NOTA_VERDE },
		Nota6 = { Modelo = "NotaAmarilla", Texto = "No tocar :)", Color = NOTA_AMARILLA },
	},

	-- Plano inicial: Art habla a cámara (gancho)
	Camara = { Plano = "PrimerPlano", Actor = "Art", Angulo = 0 },

	Pasos = {
		--======================================================================
		-- ESCENA 1 · El pegamento que no pegaba (Laboratorio)
		-- ART: «¿Te interesa saber cómo se creó el primer Post-it?
		--       ¡Todo comenzó con un pegamento que parecía un fracaso!»
		--======================================================================
		-- Gancho: Art mira a cámara y habla (labios solo en la primera frase)
		{ T = en("postit1"), Accion = "Voz", Voz = "postit1", Actor = "Art", Labios = true, LabiosHasta = 2.05, Gestos = true },
		{ T = en("postit1"), Accion = "Gesto", Actor = "Spencer", Gesto = "Examinar", Duracion = 2 },

		-- «¡Todo comenzó con un pegamento...»: Spencer pega el papel en el tablón
		{ T = en("postit1", 2.05), Accion = "Camara", Plano = "General", Actores = { "Art", "Spencer" }, Inclinacion = 6, Holgura = 1.05 },
		{ T = en("postit1", 2.05), Accion = "Mirar", Actor = "Art", A = "Spencer" },
		{ T = en("postit1", 2.15), Accion = "Pegar", Actor = "Spencer", Objeto = "Muestra", En = "Pared_1" },
		-- «...que parecía un fracaso!»: el papel se despega y cae
		{ T = en("postit1", 3.2), Accion = "Caer", Objeto = "Muestra", Tiempo = 0.85 },
		{ T = en("postit1", 3.35), Accion = "Expresion", Actor = "Art", Expresion = "Curiosidad", Duracion = 2.2 },
		-- Spencer lo recoge del suelo y se acerca a Art
		{ T = en("postit1", 4.15), Accion = "Recoger", Actor = "Spencer", Objeto = "Muestra" },
		{ T = en("postit1", 4.95), Accion = "Expresion", Actor = "Spencer", Expresion = "Feliz", Duracion = 4.4 },
		{ T = en("postit1", 5.0), Accion = "Caminar", Actor = "Spencer", Hasta = "Art", Distancia = 2.5, MirarA = "Art" },

		--======================================================================
		-- ESCENA 2 · Un invento inútil (Laboratorio)
		-- SPENCER: «¡He creado un pegamento especial! Se pega, pero puedes quitarlo sin problemas».
		-- ART: «¿Y para qué sirve eso?».
		--======================================================================
		{ T = en("postit2"), Accion = "Voz", Voz = "postit2" },
		{ T = en("postit2", 0.35), Accion = "Camara", Plano = "DosPersonajes", Actores = { "Spencer", "Art" }, Angulo = 0 },
		-- «¡He creado un pegamento especial!»: Spencer enseña el papel, orgulloso
		{ T = en("postit2", 0.4), Accion = "Gesto", Actor = "Spencer", Gesto = "Mostrar", Duracion = 1.1 },
		{ T = en("postit2", 0.4), Accion = "Expresion", Actor = "Art", Expresion = "Curiosidad", Duracion = 3.6 },
		-- Se lo entrega a Art
		{ T = en("postit2", 1.55), Accion = "Entregar", De = "Spencer", A = "Art" },
		-- «Se pega...»: Art lo pega en la pizarra
		{ T = en("postit2", 2.7), Accion = "Pegar", Actor = "Art", Objeto = "Muestra", En = "Pared_2" },
		-- «...pero puedes quitarlo sin problemas»: y lo despega
		{ T = en("postit2", 3.65), Accion = "Recoger", Actor = "Art", Objeto = "Muestra" },

		-- ART: «¿Y para qué sirve eso?» mirando el papel con curiosidad
		{ T = en("postit3", -0.43), Accion = "Mirar", Actor = "Art", A = "Camara" },
		{ T = en("postit3", -0.4), Accion = "Gesto", Actor = "Art", Gesto = "Examinar", Mantener = true },
		{ T = en("postit3", -0.05), Accion = "Camara", Plano = "Personaje", Actor = "Art", Angulo = 0 },
		{ T = en("postit3"), Accion = "Voz", Voz = "postit3" },
		{ T = en("postit3"), Accion = "Expresion", Actor = "Art", Expresion = "Duda", Duracion = 1.5 },
		-- Spencer se encoge de hombros
		{ T = en("postit3", 1.4), Accion = "Camara", Plano = "DosPersonajes", Actores = { "Art", "Spencer" }, Angulo = 0 },
		{ T = en("postit3", 1.4), Accion = "Gesto", Actor = "Spencer", Gesto = "Encogerse", Duracion = 0.9 },
		{ T = en("postit3", 1.4), Accion = "Expresion", Actor = "Spencer", Expresion = "Duda", Duracion = 0.9 },

		-- Fundido a negro: saltamos a 1974
		{ T = en("postit3", 2.1), Accion = "Fundido", Entrada = 0.3, Mantener = 0.3, Salida = 0.4 },

		--======================================================================
		-- ESCENA 3 · Mi pequeño problema (Sala de ensayo)
		-- ART (NARRADOR): «En 1974 tenía un problema: ¡mis marcapáginas siempre acababan en el suelo!».
		-- ART: «¡Otra vez no!».
		--======================================================================
		{ T = en("postit4", -0.3), Accion = "Entorno", Nombre = "SalaEnsayo" },
		{ T = en("postit4", -0.3), Accion = "Sentar", Actor = "Art", En = "Silla_1" },
		{ T = en("postit4", -0.3), Accion = "Objeto", Objeto = "Muestra", En = "Obj_Nota" }, -- Art se guardó la muestra
		{ T = en("postit4", -0.3), Accion = "Objeto", Objeto = "Cancionero", En = "Obj_Libro" },
		{ T = en("postit4", -0.3), Accion = "Objeto", Objeto = "Marcapaginas", En = "Obj_Papeles" },
		{ T = en("postit4", -0.3), Accion = "Camara", Plano = "Fija", Marca = "Cam_General", Acercar = 3, TiempoAcercar = 1.4 },
		{ T = en("postit4", -0.15), Accion = "Texto", Texto = "1974", Estilo = "Rotulo", Duracion = 2.6 },
		{ T = en("postit4"), Accion = "Voz", Voz = "postit4" },

		-- «tenía un problema»: abre el cancionero
		{ T = en("postit4", 1.1), Accion = "Camara", Plano = "Personaje", Actor = "Art", Angulo = 12, Acercar = 0.6, TiempoAcercar = 3 },
		{ T = en("postit4", 1.15), Accion = "Gesto", Actor = "Art", Gesto = "AlcanzarMesa", Duracion = 0.7 },
		{ T = en("postit4", 1.55), Accion = "Objeto", Objeto = "Cancionero", Visible = false },
		{ T = en("postit4", 1.55), Accion = "Objeto", Objeto = "CancioneroAbierto", En = "Obj_Libro" },
		-- Coge un marcapáginas y lo pone entre las páginas
		{ T = en("postit4", 2.05), Accion = "Recoger", Actor = "Art", Objeto = "Marcapaginas" },
		{ T = en("postit4", 2.7), Accion = "Soltar", Actor = "Art", En = "CancioneroAbierto", Desplazamiento = Vector3.new(0.25, 0, 0) },
		-- «...acababan en el suelo!»: se escurre y cae
		{ T = en("postit4", 3.2), Accion = "Camara", Plano = "Personaje", Actor = "Art", Encuadre = "Cuerpo", Angulo = 18 },
		{ T = en("postit4", 3.25), Accion = "Caer", Objeto = "Marcapaginas", Hasta = "Suelo_Libro", Tiempo = 0.75 },

		-- Art mira al suelo, frustrado: «¡Otra vez no!»
		{ T = en("postit5", -0.15), Accion = "Gesto", Actor = "Art", Gesto = "MirarAbajo", Mantener = true },
		{ T = en("postit5", -0.15), Accion = "Expresion", Actor = "Art", Expresion = "Frustracion", Duracion = 1.5 },
		{ T = en("postit5", -0.1), Accion = "Camara", Plano = "PrimerPlano", Actor = "Art", Angulo = 0, Inclinacion = 4 },
		{ T = en("postit5"), Accion = "Voz", Voz = "postit5" },
		{ T = en("postit5", 0.25), Accion = "Gesto", Actor = "Art", Gesto = "Lamentarse", Duracion = 0.9 },

		--======================================================================
		-- ESCENA 4 · ¡Eureka! (Sala de ensayo + recuerdo del laboratorio)
		-- ART (NARRADOR): «Entonces recordé aquel extraño pegamento y tuve una idea».
		-- ART: «¡Espera! ¿Y si lo utilizo para crear un marcapáginas?».
		--======================================================================
		{ T = en("postit6", -0.2), Accion = "Camara", Plano = "Personaje", Actor = "Art", Angulo = -12 },
		{ T = en("postit6", -0.2), Accion = "Gesto", Actor = "Art", Gesto = "Pensar", Duracion = 1.2 },
		{ T = en("postit6", -0.2), Accion = "Expresion", Actor = "Art", Expresion = "Pensativo", Duracion = 1 },
		{ T = en("postit6"), Accion = "Voz", Voz = "postit6" },

		-- «recordé aquel extraño pegamento»: flashback en sepia
		{ T = en("postit6", 0.6), Accion = "Fundido", Color = "Blanco", Entrada = 0.12, Mantener = 0.08, Salida = 0.25 },
		{ T = en("postit6", 0.8), Accion = "Entorno", Nombre = "Laboratorio" },
		{ T = en("postit6", 0.8), Accion = "Ocultar", Actor = "Art" },
		{ T = en("postit6", 0.8), Accion = "Colocar", Actor = "Spencer", En = "Pos_TrasMesa" },
		{ T = en("postit6", 0.8), Accion = "Objeto", Objeto = "Recuerdo", EnManoDe = "Spencer" },
		{ T = en("postit6", 0.8), Accion = "Filtro", Filtro = "Recuerdo" },
		{ T = en("postit6", 0.8), Accion = "Camara", Plano = "Personaje", Actor = "Spencer", Angulo = 0, Acercar = 0.8, TiempoAcercar = 1.1 },
		{ T = en("postit6", 0.85), Accion = "Gesto", Actor = "Spencer", Gesto = "Mostrar", Mantener = true },
		{ T = en("postit6", 0.85), Accion = "Expresion", Actor = "Spencer", Expresion = "Feliz", Duracion = 1.1 },

		-- «y tuve una idea»: vuelta a la sala, ¡idea!
		{ T = en("postit6", 1.85), Accion = "Fundido", Color = "Blanco", Entrada = 0.12, Mantener = 0.08, Salida = 0.25 },
		{ T = en("postit6", 2.05), Accion = "Filtro", Filtro = "Ninguno" },
		{ T = en("postit6", 2.05), Accion = "Entorno", Nombre = "SalaEnsayo" },
		{ T = en("postit6", 2.05), Accion = "Camara", Plano = "Personaje", Actor = "Art", Angulo = 0 },
		{ T = en("postit6", 2.1), Accion = "Gesto", Actor = "Art", Gesto = "Idea", Duracion = 1.3 },
		{ T = en("postit6", 2.1), Accion = "Expresion", Actor = "Art", Expresion = "Idea", Duracion = 1.6 },
		{ T = en("postit6", 2.15), Accion = "Texto", Texto = "💡", Estilo = "Icono", Duracion = 1.3, Posicion = Vector2.new(0.72, 0.2) },

		-- «¡Espera! ¿Y si lo utilizo para crear un marcapáginas?»: coge la muestra y la pega en la página
		{ T = en("postit7"), Accion = "Voz", Voz = "postit7" },
		{ T = en("postit7"), Accion = "Camara", Plano = "Personaje", Actor = "Art", Angulo = 8, Acercar = 0.8, TiempoAcercar = 2.2 },
		{ T = en("postit7", 0.65), Accion = "Recoger", Actor = "Art", Objeto = "Muestra" },
		{ T = en("postit7", 1.2), Accion = "Pegar", Actor = "Art", Objeto = "Muestra", En = "CancioneroAbierto", Desplazamiento = Vector3.new(0.55, 0, -0.35) },
		{ T = en("postit7", 1.8), Accion = "Expresion", Actor = "Art", Expresion = "Feliz", Duracion = 1.2 },
		{ T = en("postit7", 1.85), Accion = "Gesto", Actor = "Art", Gesto = "Asentir", Duracion = 0.8 },

		--======================================================================
		-- ESCENA 5 · ¡Funciona! (Laboratorio)
		-- ART: «¡Funciona! ¡No se cae y puedo quitarlo sin romper nada!».
		-- ART (NARRADOR): «Después empezamos a utilizarlos para dejar mensajes.
		--                  ¡Habíamos encontrado algo mucho más útil que un simple marcapáginas!».
		--======================================================================
		{ T = en("postit8", -0.2), Accion = "Fundido", Entrada = 0.15, Mantener = 0.05, Salida = 0.25 },
		{ T = en("postit8"), Accion = "Entorno", Nombre = "Laboratorio" },
		{ T = en("postit8"), Accion = "Objeto", Objeto = "Recuerdo", Visible = false },
		{ T = en("postit8"), Accion = "Colocar", Actor = "Spencer", En = "Pos_TrasMesa" },
		{ T = en("postit8"), Accion = "Colocar", Actor = "Art", En = "Pos_A" },
		{ T = en("postit8"), Accion = "Objeto", Objeto = "CancioneroAbierto", En = "Obj_2" },
		{ T = en("postit8"), Accion = "Objeto", Objeto = "Muestra", En = "CancioneroAbierto", Desplazamiento = Vector3.new(0.55, 0, -0.35) },
		{ T = en("postit8"), Accion = "Camara", Plano = "DosPersonajes", Actores = { "Art", "Spencer" }, Angulo = 0 },
		{ T = en("postit8"), Accion = "Voz", Voz = "postit8" },
		-- «¡Funciona!»: Art señala el papel pegado
		{ T = en("postit8", 0.05), Accion = "Senalar", Actor = "Art", A = "CancioneroAbierto", Duracion = 1.1 },
		{ T = en("postit8", 0.05), Accion = "Expresion", Actor = "Art", Expresion = "Feliz", Duracion = 2.9 },
		{ T = en("postit8", 0.1), Accion = "Mirar", Actor = "Spencer", A = "CancioneroAbierto", SoloCabeza = true },
		-- «¡No se cae y puedo quitarlo sin romper nada!»: Spencer lo quita y lo vuelve a pegar
		{ T = en("postit8", 1.3), Accion = "Camara", Plano = "Personaje", Actor = "Spencer", Angulo = 0 },
		{ T = en("postit8", 1.35), Accion = "Recoger", Actor = "Spencer", Objeto = "Muestra" },
		{ T = en("postit8", 2.1), Accion = "Pegar", Actor = "Spencer", Objeto = "Muestra", En = "CancioneroAbierto", Desplazamiento = Vector3.new(0.55, 0, -0.35) },
		-- Art observa satisfecho
		{ T = en("postit8", 2.7), Accion = "Camara", Plano = "DosPersonajes", Actores = { "Art", "Spencer" }, Angulo = 0, Transicion = 0.5 },
		{ T = en("postit8", 2.75), Accion = "Gesto", Actor = "Art", Gesto = "Asentir", Duracion = 1 },
		{ T = en("postit8", 2.75), Accion = "Expresion", Actor = "Art", Expresion = "Orgullo", Duracion = 2 },
		{ T = en("postit8", 2.75), Accion = "Expresion", Actor = "Spencer", Expresion = "Feliz", Duracion = 2 },

		-- «Después empezamos a utilizarlos para dejar mensajes»: el tablón se llena de notas
		{ T = en("postit9"), Accion = "Voz", Voz = "postit9" },
		{ T = en("postit9", 0.1), Accion = "Camara", Plano = "Fija", Marca = "Cam_Tablon", Acercar = 0.8, TiempoAcercar = 2.4 },
		{ T = en("postit9", 0.3), Accion = "Aparecer", Objeto = "Nota1", En = "Nota_1" },
		{ T = en("postit9", 0.6), Accion = "Aparecer", Objeto = "Nota2", En = "Nota_2" },
		{ T = en("postit9", 0.9), Accion = "Aparecer", Objeto = "Nota3", En = "Nota_3" },
		{ T = en("postit9", 1.2), Accion = "Aparecer", Objeto = "Nota4", En = "Nota_4" },
		{ T = en("postit9", 1.5), Accion = "Aparecer", Objeto = "Nota5", En = "Nota_5" },
		{ T = en("postit9", 1.8), Accion = "Aparecer", Objeto = "Nota6", En = "Nota_6" },
		-- «¡Habíamos encontrado algo mucho más útil...»: se miran, satisfechos
		{ T = en("postit9", 2.35), Accion = "Camara", Plano = "DosPersonajes", Actores = { "Art", "Spencer" }, Angulo = 0, Transicion = 0.5 },
		{ T = en("postit9", 2.4), Accion = "Mirar", Actor = "Art", A = "Spencer" },
		{ T = en("postit9", 2.4), Accion = "Mirar", Actor = "Spencer", A = "Art" },
		{ T = en("postit9", 2.4), Accion = "Expresion", Actor = "Art", Expresion = "Orgullo", Duracion = 1.6 },
		-- «...que un simple marcapáginas!»: celebran
		{ T = en("postit9", 4.05), Accion = "Gesto", Actor = "Spencer", Gesto = "BrazoArriba", Duracion = 1.1 },
		{ T = en("postit9", 4.05), Accion = "Expresion", Actor = "Spencer", Expresion = "Feliz", Duracion = 1.4 },
		{ T = en("postit9", 4.1), Accion = "Gesto", Actor = "Art", Gesto = "Asentir", Duracion = 1 },
		{ T = en("postit9", 4.1), Accion = "Expresion", Actor = "Art", Expresion = "Feliz", Duracion = 1.4 },

		--======================================================================
		-- ESCENA 6 · Un fracaso convertido en éxito (Laboratorio, 1980)
		-- ART (NARRADOR): «En 1980 llegaron oficialmente a las tiendas como Post-it.
		--                  ¡Y todo gracias a un pegamento que parecía inútil!».
		-- SPENCER: «¡Al final sí que servía para algo!».
		--======================================================================
		{ T = en("postit10", -0.4), Accion = "Fundido", Entrada = 0.2, Mantener = 0.2, Salida = 0.35 },
		{ T = en("postit10", -0.2), Accion = "Colocar", Actor = "Art", En = "Pos_C" },
		{ T = en("postit10", -0.2), Accion = "Objeto", Objeto = "Bloc", EnManoDe = "Art" },
		{ T = en("postit10", -0.2), Accion = "Colocar", Actor = "Spencer", En = "Pos_D" },
		{ T = en("postit10", -0.2), Accion = "Objeto", Objeto = "CajaA", En = "Obj_3" },
		{ T = en("postit10", -0.2), Accion = "Objeto", Objeto = "CajaB", En = "Obj_4" },
		{ T = en("postit10", -0.2), Accion = "Objeto", Objeto = "CajaC", En = "Suelo_1" },
		{ T = en("postit10", -0.2), Accion = "Camara", Plano = "Fija", Marca = "Cam_General", Acercar = 2.5, TiempoAcercar = 1.8 },
		{ T = en("postit10"), Accion = "Voz", Voz = "postit10" },
		-- «En 1980...»
		{ T = en("postit10", 0.1), Accion = "Texto", Texto = "1980", Estilo = "Rotulo", Duracion = 2.4 },
		-- «...llegaron oficialmente a las tiendas como Post-it»: Art presenta el bloc
		{ T = en("postit10", 1.65), Accion = "Camara", Plano = "Personaje", Actor = "Art", Angulo = 0, Acercar = 0.8, TiempoAcercar = 2.4 },
		{ T = en("postit10", 1.65), Accion = "Postura", Actor = "Art", Postura = "Mostrar" },
		{ T = en("postit10", 1.65), Accion = "Expresion", Actor = "Art", Expresion = "Orgullo", Duracion = 2.5 },
		-- «¡Y todo gracias a un pegamento...»: Spencer se acerca
		{ T = en("postit10", 4.15), Accion = "Camara", Plano = "DosPersonajes", Actores = { "Art", "Spencer" }, Angulo = 0, Seguir = true },
		{ T = en("postit10", 4.2), Accion = "Caminar", Actor = "Spencer", Hasta = "Art", Distancia = 2.4, MirarA = "Bloc" },
		-- Ambos miran el bloc
		{ T = en("postit10", 5.35), Accion = "Gesto", Actor = "Art", Gesto = "MirarAbajo", Mantener = true },
		{ T = en("postit10", 5.35), Accion = "Mirar", Actor = "Spencer", A = "Bloc", SoloCabeza = true },
		-- «...que parecía inútil!»
		{ T = en("postit10", 7.35), Accion = "Gesto", Actor = "Spencer", Gesto = "Asentir", Duracion = 1 },
		{ T = en("postit10", 7.35), Accion = "Expresion", Actor = "Spencer", Expresion = "Orgullo", Duracion = 1.8 },

		-- SPENCER: «¡Al final sí que servía para algo!» (a cámara)
		{ T = en("postit11", -0.5), Accion = "Mirar", Actor = "Spencer", A = "Camara" },
		{ T = en("postit11", -0.5), Accion = "Gesto", Actor = "Art", Gesto = "Asentir", Duracion = 0.8 },
		{ T = en("postit11", -0.12), Accion = "Camara", Plano = "PrimerPlano", Actor = "Spencer", Angulo = 0 },
		{ T = en("postit11"), Accion = "Voz", Voz = "postit11", Gestos = true },
		{ T = en("postit11"), Accion = "Expresion", Actor = "Spencer", Expresion = "Feliz", Duracion = 1.8 },

		-- «¡DE FRACASO A INVENTO MILLONARIO!»
		{ T = en("postit11", 1.7), Accion = "Camara", Plano = "General", Actores = { "Art", "Spencer" }, Inclinacion = 4, Transicion = 0.6 },
		{ T = en("postit11", 1.75), Accion = "Postura", Actor = "Art", Postura = "Ninguna" },
		{ T = en("postit11", 1.75), Accion = "Gesto", Actor = "Art", Gesto = "BrazoArriba", Mantener = true },
		{ T = en("postit11", 1.75), Accion = "Gesto", Actor = "Spencer", Gesto = "BrazoArriba", Mantener = true },
		{ T = en("postit11", 1.75), Accion = "Expresion", Actor = "Art", Expresion = "Feliz" },
		{ T = en("postit11", 1.75), Accion = "Expresion", Actor = "Spencer", Expresion = "Feliz" },
		{ T = en("postit11", 1.85), Accion = "Texto", Texto = "¡DE FRACASO A INVENTO MILLONARIO!", Estilo = "Titulo", Duracion = FIN - en("postit11", 1.85), Posicion = Vector2.new(0.5, 0.22) },

		{ T = FIN, Accion = "Esperar", Tiempo = 0 },
	},
}
]=======] },
	{ Ruta = "StarterPlayerScripts", Nombre = "StoryRunner", Clase = "LocalScript", Fuente = [=======[
--[[
	STORY RUNNER · LocalScript
	Studio: StarterPlayer > StarterPlayerScripts > StoryRunner

	Al pulsar Play reproduce la escena indicada en StoryTemplate > Config (EscenaActiva).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local raiz = ReplicatedStorage:WaitForChild("StoryTemplate")
local Config = require(raiz:WaitForChild("Config"))
local Director = require(raiz:WaitForChild("Modulos"):WaitForChild("Director"))

Director.Reproducir(Config.EscenaActiva)
]=======] },
	{ Ruta = "ServerScriptService", Nombre = "StoryServer", Clase = "Script", Fuente = [=======[
--[[
	STORY SERVER · Script
	Studio: ServerScriptService > StoryServer

	Red de seguridad: si falta algún personaje de DefPersonajes en
	StoryTemplate > Personajes (por ejemplo, si no se pudo crear al instalar),
	lo construye al pulsar Play. Después avisa al cliente de que puede empezar.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local raiz = ReplicatedStorage:WaitForChild("StoryTemplate")

local ok, err = pcall(function()
	local Fabrica = require(raiz.Modulos.FabricaPersonajes)
	Fabrica.ConstruirTodos(raiz.Personajes, nil, true)
end)
if not ok then
	warn("[Historia] No se pudieron crear los personajes que faltaban: " .. tostring(err))
end

raiz:SetAttribute("PersonajesListos", true)
]=======] },
}

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
