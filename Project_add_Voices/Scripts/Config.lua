--[[
	CONFIG · Ajustes generales de la plantilla
	Studio: ReplicatedStorage > StoryTemplate > Config

	Es el único archivo que hace falta tocar para elegir qué escena se
	reproduce al pulsar Play y cómo se comporta la grabación.
]]

local Config = {}

-- Escena que se reproduce al pulsar Play.
-- Es el nombre de un ModuleScript dentro de StoryTemplate > Escenas.
Config.EscenaActiva = "Prueba_Plantilla"

-- FORMATO VERTICAL ---------------------------------------------------------
Config.Aspecto = 9 / 16 -- proporción del vídeo (ancho / alto)
Config.BandasNegras = true -- tapa en negro todo lo que queda fuera del 9:16
Config.MostrarGuias = true -- dibuja la zona segura. Ponlo en false para grabar
Config.CampoVision = 40 -- campo de visión vertical de la cámara (grados)
Config.TransicionCamara = 0 -- transición por defecto entre planos (0 = corte)

-- REPRODUCCIÓN -------------------------------------------------------------
Config.RetrasoInicio = 2 -- segundos de espera antes del primer paso (para empezar a grabar)
Config.Repetir = false -- vuelve a empezar la escena al terminar
Config.OcultarInterfazRoblox = true -- oculta chat, lista de jugadores, etc.
Config.OcultarRaton = true -- oculta el cursor dentro del juego

-- MOVIMIENTO ---------------------------------------------------------------
Config.VelocidadCaminar = 7 -- studs por segundo
Config.VelocidadCorrer = 16

return Config
