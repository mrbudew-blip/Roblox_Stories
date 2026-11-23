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
