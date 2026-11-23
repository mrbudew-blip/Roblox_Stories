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
