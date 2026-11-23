--[[
	DIRECTOR · Reproduce una escena paso a paso
	Studio: ReplicatedStorage > StoryTemplate > Modulos > Director

	Lo arranca el LocalScript StarterPlayerScripts > StoryRunner.
	Todo ocurre en el cliente: personajes, objetos y escenario son copias
	locales, sin física ni red, para que el coste sea mínimo.

	La lista completa de acciones está en la documentación (README.md) y en
	Escenas > _PlantillaEscena. No hace falta editar este archivo para crear
	escenas nuevas.
]]

local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local SoundService = game:GetService("SoundService")
local StarterGui = game:GetService("StarterGui")
local UserInputService = game:GetService("UserInputService")

local Modulos = script.Parent
local Raiz = Modulos.Parent
local Config = require(Raiz:WaitForChild("Config"))
local Actor = require(Modulos:WaitForChild("Actor"))
local Camaras = require(Modulos:WaitForChild("Camaras"))
local Guias = require(Modulos:WaitForChild("Guias"))

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
	self.Sonidos = {}
	local viejo = workspace:FindFirstChild("Escenario")
	if viejo then
		viejo:Destroy()
	end
	self.Carpeta = Instance.new("Folder")
	self.Carpeta.Name = "Escenario"
	self.Carpeta.Parent = workspace
	return self
end

-- ENTORNO ----------------------------------------------------------------------

function Contexto:CargarEntorno(nombre)
	local plantilla = Raiz.Entornos:FindFirstChild(tostring(nombre))
	if not plantilla then
		error(("No existe el entorno '%s' en StoryTemplate > Entornos"):format(tostring(nombre)), 0)
	end
	if self.Entorno then
		self.Entorno:Destroy()
		-- Los objetos colocados en el entorno anterior desaparecen con él
		-- (los que lleva un personaje en la mano se quedan).
		for _, objeto in pairs(self.Objetos) do
			local enMano = false
			for _, a in pairs(self.Actores) do
				if a.Objeto == objeto then
					enMano = true
				end
			end
			if not enMano then
				objeto.Parent = nil
			end
		end
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

	-- Iluminación del entorno (atributos del Model). Lo que no indique vuelve
	-- al valor original del lugar.
	Lighting.ClockTime = entorno:GetAttribute("Hora") or LUZ_ORIGINAL.ClockTime
	Lighting.Brightness = entorno:GetAttribute("Brillo") or LUZ_ORIGINAL.Brightness
	Lighting.Ambient = entorno:GetAttribute("Ambiente") or LUZ_ORIGINAL.Ambient
	Lighting.OutdoorAmbient = entorno:GetAttribute("AmbienteExterior") or LUZ_ORIGINAL.OutdoorAmbient

	local audiencia = self:Marca("Audiencia")
	self.Audiencia = audiencia and audiencia.Position or nil
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
		actor:Reanudar()
	end
end

-- POSICIONES -------------------------------------------------------------------

--[[
	Convierte un destino en un punto del suelo. "valor" puede ser:
	  · nombre de marca del entorno ("Pos_A", "Entrada_Izq", "Obj_1"...)
	  · rol de un actor visible ("Protagonista") → se queda a "distancia" de él
	  · nombre de un objeto en escena ("Caja") → se queda a "distancia" de él
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
		local p = objeto:GetPivot().Position
		if desde then
			local suelo = Vector3.new(p.X, desde.Y, p.Z)
			return suelo + plano(desde - suelo) * (distancia or 1.6), nil
		end
		return p, nil
	end
	local marca = self:Marca(nombre)
	if marca then
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
		-- Posición a la que va la cámara (aunque todavía no se haya dibujado)
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
	local pos, marca = self:Pos(valor)
	if marca then
		return marca.Position
	end
	return pos
end

-- OBJETOS ----------------------------------------------------------------------

function Contexto:ObtenerObjeto(nombre)
	if self.Objetos[nombre] then
		return self.Objetos[nombre]
	end
	local def = (self.Escena.Objetos or {})[nombre]
	local nombreModelo = (type(def) == "table" and def.Modelo) or nombre
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

function Contexto:ColocarObjeto(nombre, donde)
	local objeto = self:ObtenerObjeto(nombre)
	self:QuitarDeManos(objeto)
	local pos, marca = self:Pos(donde)
	fijarObjeto(objeto, true)
	local dir = marca and plano(marca.CFrame.LookVector) or Vector3.new(0, 0, -1)
	objeto:PivotTo(CFrame.lookAt(pos, pos + dir))
	local cf, tam = objeto:GetBoundingBox()
	objeto:PivotTo(objeto:GetPivot() + Vector3.new(0, pos.Y - (cf.Position.Y - tam.Y / 2), 0))
	objeto.Parent = self.Carpeta
end

function Contexto:DarObjeto(nombre, actor)
	local objeto = self:ObtenerObjeto(nombre)
	self:QuitarDeManos(objeto)
	objeto.Parent = self.Carpeta
	actor:Sostener(objeto)
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
	self.Carpeta:Destroy()
end

--==============================================================================
-- ACCIONES: cada una devuelve los segundos que dura (el Director espera ese
-- tiempo salvo que el paso tenga Paralelo = true).
--==============================================================================

local Acciones = {}

Acciones.Esperar = function(_, p)
	return p.Tiempo or p[2] or 1
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
		actor.Modelo.Parent = nil
	end
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

Acciones.Senalar = function(ctx, p)
	local actor = ctx:ActorVisible(p.Actor)
	local giro = 0
	if p.A then
		giro = actor:MirarHacia(ctx:PuntoMirada(p.A))
	end
	local duracion = p.Duracion or 1.5
	task.delay(giro, function()
		actor:Gesto("Senalar", duracion, p.Mantener)
	end)
	return giro + duracion
end

Acciones.Sorpresa = function(ctx, p)
	return ctx:ActorVisible(p.Actor):Gesto("Sorpresa", p.Duracion, p.Mantener)
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

Acciones.Recoger = function(ctx, p)
	local actor = ctx:ActorVisible(p.Actor)
	local objeto = ctx:ObtenerObjeto(p.Objeto)
	local giro = 0
	if objeto.Parent then
		giro = actor:MirarHacia(objeto:GetPivot().Position)
	end
	task.spawn(function()
		task.wait(giro)
		actor:Gesto("Agacharse", 0.8)
		task.wait(0.5)
		ctx:DarObjeto(p.Objeto, actor)
	end)
	return giro + 1.2
end

Acciones.Soltar = function(ctx, p)
	local actor = ctx:ActorVisible(p.Actor)
	local objeto = actor.Objeto
	if not objeto then
		return 0
	end
	if p.En then
		local donde = p.En
		task.spawn(function()
			actor:Gesto("Agacharse", 0.7)
			task.wait(0.45)
			ctx:ColocarObjeto(objeto.Name, donde)
		end)
		return 1
	end
	actor:Soltar()
	objeto.Parent = nil
	return 0
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
	ctx:ColocarObjeto(p.Objeto, p.En or p.Marca)
	return 0
end

Acciones.Camara = function(ctx, p)
	ctx:Camara(p)
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
	local ok, duracion = pcall(accion, ctx, paso)
	if not ok then
		warn(("[Historia] Paso %d (%s): %s"):format(i, tostring(nombre), tostring(duracion)))
		return
	end
	if not paso.Paralelo and type(duracion) == "number" and duracion > 0 then
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
		Acciones.Colocar(ctx, { Actor = rol, En = d.Marca or d.En })
	end

	ctx:Camara(escena.Camara or { Plano = "General" })

	for rol, def in pairs(posiciones) do
		if type(def) == "table" and def.MirarA then
			ctx:ActorVisible(rol):MirarHacia(ctx:PuntoMirada(def.MirarA), 0)
		end
	end

	for nombre, def in pairs(escena.Objetos or {}) do
		local d = type(def) == "table" and def or { En = def }
		if d.EnManoDe then
			ctx:DarObjeto(nombre, ctx:ActorVisible(d.EnManoDe))
		elseif d.En or d.Marca then
			ctx:ColocarObjeto(nombre, d.En or d.Marca)
		end
	end
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
		task.wait(Config.RetrasoInicio or 0)

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
		print(("[Historia] Escena '%s' terminada"):format(modulo.Name))

		if Config.Repetir then
			task.wait(2)
			ctx:Destruir()
		end
	until not Config.Repetir
end

return Director
