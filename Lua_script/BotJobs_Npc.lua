-- ============================================================
--  BotJobs_Npc.lua
--  Nerrak (Kalu'ak) entry 900200  — animacion y frases
--  - Frases periodicas (SAY + gesto) mientras haya jugadores cerca
--  - Saludo al abrir el panel (lo llama BotJobs_Server.lua)
--  El gossip/panel NO se registra aqui: lo gestiona BotJobs_Server.lua.
-- ============================================================

local NPC_ENTRY   = 900200      -- debe coincidir con CFG.NPC_ENTRY de BotJobs_Server.lua
local INTERVAL_MS = 45000       -- cada cuanto habla
local FIRST_MS    = 7000        -- primera frase tras aparecer
local LANG        = 0           -- 0 = universal
local HEAR_RANGE  = 40          -- solo habla si hay algun jugador a menos de estas yardas (0 = siempre)
local GREET_CD    = 12          -- segundos minimos entre saludos

-- Gestos (emotes): 1 hablar, 3 saludar, 5 exclamar, 6 preguntar, 11 reir
local TALK_GESTURES  = { 1, 1, 1, 5, 6 }
local GREET_GESTURES = { 3, 1 }

local LINES = {
    "Mar tranquilo, red llena. Así me gusta el día. ¿Mandas a tus compañeros a trabajar?",
    "Pesca, hierbas, minerales, pieles... Tus compañeros trabajan y yo solo cobro un poquito.",
    "¿Compañeros de brazos cruzados? Aquí siempre hay trabajo honrado.",
    "Un buen pescador tiene paciencia. Un buen compañero también. Y cobra por horas.",
    "El correo trae el botín y la práctica sube la habilidad. Todos contentos.",
    "Cinco minutos para un recado, tres horas para un buen cargamento. Tú eliges.",
    "Los de mi pueblo sabemos esperar a que piquen. Tus compañeros, también.",
    "¡Eh, tú! Un oficio sin practicar se oxida, como un anzuelo olvidado.",
    "Si ya no suben más, llévalos con su maestro a entrenar. Luego vuelven aquí a por más práctica.",
}

local GREETINGS = {
    "¡%s! Pasa, pasa. ¿Qué oficio toca hoy?",
    "Bienvenido, %s. Los compañeros ya huelen a trabajo.",
    "¡Ah, %s! Justo hablaba de ti.",
}

local lastLine  = {}   -- [creatureGuidLow] = ultimo indice dicho
local lastGreet = {}   -- [creatureGuidLow] = os.time() del ultimo saludo

local function Gesture(creature, list)
    local id = list[math.random(1, #list)]
    pcall(function()
        if creature.PerformEmote then creature:PerformEmote(id)
        elseif creature.HandleEmoteCommand then creature:HandleEmoteCommand(id)
        elseif creature.Emote then creature:Emote(id)
        end
    end)
end

local function SayText(creature, text)
    local ok = pcall(function() creature:SendUnitSay(text, LANG) end)
    if not ok then pcall(function() creature:Say(text, LANG) end) end
end

local function PlayersNear(creature)
    if HEAR_RANGE <= 0 then return true end
    if not creature.GetPlayersInRange then return true end   -- API no disponible: habla igual
    local ok, list = pcall(function() return creature:GetPlayersInRange(HEAR_RANGE) end)
    if not ok or type(list) ~= "table" then return true end
    return #list > 0
end

local function GuidOf(creature)
    local ok, g = pcall(function() return creature:GetGUIDLow() end)
    return ok and g or 0
end

local function Speak(creature)
    if not creature or #LINES < 1 then return end
    if not PlayersNear(creature) then return end
    local g = GuidOf(creature)
    local idx = math.random(1, #LINES)
    if #LINES > 1 and idx == lastLine[g] then idx = (idx % #LINES) + 1 end   -- no repetir la misma
    lastLine[g] = idx
    Gesture(creature, TALK_GESTURES)
    SayText(creature, LINES[idx])
end

local function StartTalking(event, creature)
    if not creature or not creature.RegisterEvent then return end
    pcall(function() if creature.RemoveEvents then creature:RemoveEvents() end end)
    creature:RegisterEvent(function(_, _, _, cre) Speak(cre) end, FIRST_MS, 1)
    creature:RegisterEvent(function(_, _, _, cre) Speak(cre) end, INTERVAL_MS, 0)
end

-- 5 = CREATURE_EVENT_ON_SPAWN (tras .reload eluna hay que respawnear al NPC para que empiece a hablar)
RegisterCreatureEvent(NPC_ENTRY, 5, StartTalking)

--- Saludo al abrir el panel (global: lo llama BotJobs_Server.lua si existe)
function BotJobs_NpcGreet(creature, player)
    if not creature then return end
    local g = GuidOf(creature)
    local now = os.time()
    if lastGreet[g] and now - lastGreet[g] < GREET_CD then return end
    lastGreet[g] = now
    Gesture(creature, GREET_GESTURES)
    local name = "viajero"
    if player then
        local ok, n = pcall(function() return player:GetName() end)
        if ok and n then name = n end
    end
    SayText(creature, string.format(GREETINGS[math.random(1, #GREETINGS)], name))
end

print("[BotJobs] Nerrak animado entry=" .. NPC_ENTRY)
