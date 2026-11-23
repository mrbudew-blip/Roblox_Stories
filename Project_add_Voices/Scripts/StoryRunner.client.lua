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
