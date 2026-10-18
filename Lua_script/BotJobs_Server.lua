-- ============================================================
--  BotJobs_Server.lua  v0.4.0
--  Eluna — AzerothCore + mod-playerbots + AIO
--
--  Trabajos de PROFESION (recoleccion) para ALTBOTS.
--  Pesca, herbalismo, mineria y desuello.
--  Interaccion: NPC (creature entry CFG.NPC_ENTRY) -> panel AIO.
--  Basado en BotGarrison (Guard, AIO, aparcamiento, correo).
--
--  Requiere un parche de 2 lineas en BotGarrison_Server.lua para que
--  un bot en trabajo no pueda ir a mision y viceversa (ver README.md).
-- ============================================================

local AIO = AIO or require("AIO")
local BJ  = AIO.AddHandlers("BotJobs", {})

-- ============================================================
--  CONFIG
-- ============================================================
local CFG = {
    NPC_ENTRY           = 900200,  -- debe coincidir con el SQL del NPC
    NPC_RANGE           = 12,      -- yardas maximas al NPC para contratar
    PANEL_REMOTE_BOARD  = false,   -- true: se puede contratar desde cualquier sitio (/bj)

    MAX_JOBS_PER_PLAYER = 3,       -- trabajos simultaneos por jugador

    -- Descanso por bot: tras BOT_CD_JOBS trabajos completados, el bot descansa BOT_CD_MULT x el tiempo
    -- trabajado en esa tanda (ej.: 5+5+60 min trabajados -> 70 min x 2 = 140 min de descanso).
    -- Al acabar el descanso (o tras BOT_CD_RESET_HOURS horas sin completar la tanda) el contador vuelve a 0.
    -- Con PERSIST_JOBS = true se guarda en characters.character_bot_job_cd (sobrevive a reinicios).
    BOT_CD_ENABLED     = true,
    BOT_CD_JOBS        = 3,
    BOT_CD_MULT        = 2.0,
    BOT_CD_RESET_HOURS = 24,       -- 0 = nunca se reinicia solo
    PERSIST_JOBS        = true,    -- guarda los trabajos en characters.character_bot_jobs (sobreviven a reinicios)
    DIARY_ENABLED       = true,    -- envia cada trabajo terminado al diario del addon (cliente)

    -- Profesiones activas
    PROFESSIONS_ENABLED = { FISHING = true, HERBALISM = true, MINING = true, SKINNING = true },

    -- Duraciones: min = minutos; priceMult = multiplicador de precio; cap = maximo de puntos de habilidad
    -- por trabajo; loot = multiplicador de botin (los trabajos largos rinden mas por minuto).
    -- Nota: la habilidad nunca sube por encima del rango entrenado del bot (75/150/...), asi que
    -- cap > 75 no aporta nada; los trabajos largos son sobre todo para botin.
    DURATIONS = {
        { min = 5,   priceMult = 1.10, cap = 15, loot = 0.90 },
        { min = 30,  priceMult = 1.00, cap = 50, loot = 1.00 },
        { min = 60,  priceMult = 0.95, cap = 75, loot = 1.15 },
        { min = 180, priceMult = 0.85, cap = 75, loot = 1.40 },
    },

    -- ===== PRECIO (ligado al valor del botin) =====
    -- Precio = valor estimado del botin esperado * PRICE_PCT * priceMult(duracion) * PROF_PRICE_MULT.
    -- Valor estimado de 1 unidad = SellPrice (item_template) * PRICE_VALUE_MULT[profesion]
    --   (el precio de vendedor se queda corto frente al mercado; este multiplicador lo compensa).
    -- Si el objeto no tiene SellPrice: base + req * perSkill (cobre por unidad).
    -- Pon DEBUG_MATERIALS = true para ver en consola el precio de 1 h de cada material.
    PRICE_PCT        = 0.40,   -- fraccion del valor esperado que cuesta el trabajo
    PRICE_VALUE_MULT = { FISHING = 2.0, HERBALISM = 2.5, MINING = 2.0, SKINNING = 2.0 },
    PRICE_FALLBACK   = { base = 30, perSkill = 6 },
    PROF_PRICE_MULT  = { FISHING = 1.0, HERBALISM = 1.0, MINING = 1.0, SKINNING = 1.0 },
    MIN_PRICE        = 10,     -- cobre
    PRICE_ROUND      = 10,     -- se redondea hacia arriba a multiplos de esto (cobre)

    -- ===== BOTIN =====
    -- Material elegido: unidades por minuto * rate del material * loot(duracion) +-QTY_VARIANCE
    ITEMS_PER_MIN = { FISHING = 0.90, HERBALISM = 0.70, MINING = 0.60, SKINNING = 0.50 },
    QTY_VARIANCE  = 0.15,
    -- Extras: ademas llegan otros materiales de la misma profesion (de rango parecido al del bot)
    BYCATCH_PCT   = 0.30,      -- unidades extra = 30 % del botin principal
    BYCATCH_RANGE = 150,       -- extras con req entre (habilidad - RANGE) y habilidad
    DOUBLE_CHANCE = 0.10,      -- probabilidad de botin principal doble
    -- Objetos raros (tabla RARE): chance por hora de trabajo; maximo RARE_MAX por trabajo
    RARE_ENABLED  = true,
    RARE_MAX      = 2,
    RARE_RANGE    = 175,       -- solo cuentan raros con minSkill entre (habilidad - RANGE) y habilidad
    RARE_CHANCE_MULT = 0.70,   -- multiplica todas las probabilidades de la tabla RARE
    STACK_SIZE      = 20,      -- tope de pila al enviar por correo (tambien se respeta el del objeto)
    MAIL_ATTACH_MAX = 8,       -- adjuntos por carta (max. del core: 12)

    -- ===== HABILIDAD =====
    SKILL_PER_MIN      = 1.0,         -- puntos por minuto a habilidad ~0
    SKILL_DECAY_SCALE  = 450,         -- decay = max(FLOOR, 1 - habilidad/SCALE)
    SKILL_DECAY_FLOOR  = 0.10,
    SKILL_BONUS_MIN    = 1,
    SKILL_BONUS_MAX    = 5,
    -- Material "facil" para la habilidad del bot rinde menos (como los colores de WoW):
    -- diff = habilidad - req del material. Primer tramo con diff < upTo.
    SKILL_TIERS = {
        { upTo = 25,   mult = 1.00 },  -- naranja
        { upTo = 50,   mult = 0.75 },  -- amarillo
        { upTo = 100,  mult = 0.50 },  -- verde
        { upTo = 9999, mult = 0.25 },  -- gris
    },

    -- ===== APARCAMIENTO / EFECTOS (igual que BotGarrison) =====
    PARK_MAP = 13, PARK_X = 0, PARK_Y = 0, PARK_Z = 0, PARK_O = 0,
    SALUTE_FACE_PLAYER = true,
    DEPART_FX = true,
    DEPART_FX_CHARGE = { 12042 },
    DEPART_FX_BURST  = {},
    DEPART_FX_FADE   = 66,
    DEPART_FX_CHARGE_AT   = 2400,
    DEPART_FX_FADE_AT     = 3300,
    DEPART_FX_TELEPORT_AT = 4500,
    ARRIVE_BLINK = true,
    ARRIVE_BLINK_SPELL = 1953,
    ARRIVE_BLINK_DIST = 18,
    ARRIVE_BLINK_DELAY_MS = 900,

    -- ===== VIGILANCIA =====
    SWEEP_MS            = 5000,   -- cada cuanto se comprueba si algun trabajo ha terminado
    WATCHDOG_MS         = 5000,   -- re-aparca bots en trabajo que vuelvan; 0 = desactivado
    SUMMON_NEAR_YARDS   = 80,

    DEBUG_MATERIALS = false,      -- true: imprime el nombre real (BD) de cada material al arrancar
}

-- ============================================================
--  PROFESIONES Y MATERIALES
--  { itemId, nombre, habilidad minima, rate (multiplicador de unidades) }
--  Los IDs que no existan en item_template se descartan al arrancar (se avisa en consola).
-- ============================================================
local PROF_ORDER = { "FISHING", "HERBALISM", "MINING", "SKINNING" }
local PROFS = {
    FISHING   = { skill = 356, name = "Pesca",      icon = "Interface\\Icons\\Trade_Fishing" },
    HERBALISM = { skill = 182, name = "Herboristería", icon = "Interface\\Icons\\Trade_Herbalism" },
    MINING    = { skill = 186, name = "Minería",    icon = "Interface\\Icons\\Trade_Mining" },
    SKINNING  = { skill = 393, name = "Desuello",   icon = "Interface\\Icons\\INV_Misc_Pelt_Wolf_01" },
}

local MATERIALS = {
    FISHING = {
        { 6291,  "Pececillo brillante crudo",       1,   1.2 },
        { 6303,  "Caballa reptante cruda",          1,   1.2 },
        { 6289,  "Pargo de fango crudo",            20,  1.0 },
        { 6361,  "Albacora aleta arcoíris cruda",   50,  1.0 },
        { 6308,  "Siluro bigotudo crudo",           50,  1.0 },
        { 6358,  "Bocanegra aceitosa",              75,  0.9 },
        { 6359,  "Pargo aleta de fuego",            100, 0.9 },
        { 13754, "Pez poderoso reluciente crudo",   175, 0.8 },
        { 13759, "Pargo aleta nocturna crudo",      225, 0.8 },
        { 13760, "Salmón escama solar crudo",       225, 0.8 },
        { 13889, "Salmón escamablanca crudo",       250, 0.7 },
        { 27425, "Colafeudal moteada",              300, 0.8 },
        { 27438, "Dardo dorado",                    310, 0.8 },
        { 27439, "Cangrejo furioso",                325, 0.7 },
        { 41807, "Salmón glacial",                  380, 0.7 },   -- verificar ID
        { 41808, "Pez ángel aleta de dragón",       380, 0.7 },   -- verificar ID
        { 41802, "Manta imperial",                  400, 0.6 },   -- verificar ID
    },
    HERBALISM = {
        { 2447,  "Flor de paz",            1,   1.2 },
        { 765,   "Hojaplata",              1,   1.2 },
        { 2449,  "Raíz de tierra",         15,  1.1 },
        { 785,   "Magesal",                50,  1.0 },
        { 2450,  "Brezospina",             70,  1.0 },
        { 2453,  "Hierba de contusión",    100, 1.0 },
        { 3355,  "Acero silvestre",        115, 0.9 },
        { 3356,  "Sangreal",               125, 0.9 },
        { 3357,  "Vidarraiz",              150, 0.9 },
        { 3818,  "Pálida",                 150, 0.9 },
        { 3821,  "Espina de oro",          170, 0.9 },
        { 3358,  "Bigote de Khadgar",      185, 0.8 },
        { 3819,  "Mordisco invernal",      195, 0.8 },
        { 4625,  "Flor de fuego",          205, 0.8 },
        { 8831,  "Loto morado",            210, 0.8 },
        { 8836,  "Lágrimas de Arthas",     220, 0.8 },
        { 8838,  "Sol de hierba",          230, 0.8 },
        { 8839,  "Hierba ciega",           235, 0.8 },
        { 8845,  "Hongo fantasma",         245, 0.7 },
        { 8846,  "Gromsanguina",           250, 0.7 },
        { 13464, "Sansam dorado",          260, 0.7 },
        { 13463, "Hoja de sueño",          270, 0.7 },
        { 13465, "Salvia de montaña",      280, 0.6 },
        { 13466, "Flor de plaga",          285, 0.6 },
        { 13467, "Casquete de hielo",      290, 0.6 },
        { 22785, "Hierba vil",             300, 0.9 },
        { 22786, "Gloria de sueño",        315, 0.8 },
        { 22787, "Velo de rasgado",        325, 0.8 },
        { 22789, "Terocono",               325, 0.8 },
        { 22788, "Capuchón de llama",      335, 0.7 },
        { 22790, "Liquen ancestral",       340, 0.7 },
        { 22791, "Flor abisal",            350, 0.6 },
        { 22792, "Vid de pesadilla",       365, 0.6 },
        { 22793, "Cardo de maná",          375, 0.6 },
        { 36901, "Trébol de oro",          350, 0.8 },
        { 36904, "Lirio tigre",            375, 0.7 },
        { 36907, "Rosa de Talandra",       385, 0.7 },
        { 36903, "Lengua de víbora",       400, 0.6 },
        { 36905, "Flor de lich",           425, 0.5 },
        { 36906, "Espina de hielo",        435, 0.5 },
        { 36908, "Loto de escarcha",       450, 0.3 },
    },
    MINING = {
        { 2770,  "Mineral de cobre",       1,   1.2 },
        { 2771,  "Mineral de estaño",      65,  1.0 },
        { 2775,  "Mineral de plata",       75,  0.7 },
        { 2772,  "Mineral de hierro",      125, 1.0 },
        { 2776,  "Mineral de oro",         155, 0.7 },
        { 3858,  "Mineral de mitril",      175, 0.9 },
        { 7911,  "Mineral de veraplata",   230, 0.6 },
        { 10620, "Mineral de torio",       245, 0.9 },
        { 23424, "Mineral de hierro vil",  275, 0.9 },
        { 23425, "Mineral de adamantita",  325, 0.8 },
        { 23426, "Mineral de korio",       375, 0.3 },
        { 36909, "Mineral de cobalto",     350, 0.9 },
        { 36912, "Mineral de saronita",    400, 0.8 },
        { 36910, "Mineral de titanio",     450, 0.5 },
    },
    SKINNING = {
        { 2318,  "Cuero ligero",            1,   1.2 },
        { 2319,  "Cuero medio",             75,  1.0 },
        { 4234,  "Cuero pesado",            125, 1.0 },
        { 4304,  "Cuero grueso",            200, 0.9 },
        { 8170,  "Cuero rugoso",            250, 0.9 },
        { 21887, "Cuero nudoso",            300, 0.9 },
        { 25707, "Cuero nudoso pesado",     330, 0.6 },
        { 33568, "Cuero de la tundra boreal", 350, 0.9 },
        { 38425, "Cuero boreal pesado",     400, 0.6 },
    },
}

-- Se convierten a tablas con campos
for key, list in pairs(MATERIALS) do
    for i, m in ipairs(list) do
        list[i] = { id = m[1], name = m[2], req = m[3], rate = m[4] or 1.0 }
    end
end

-- Datos de item_template (se rellenan al validar los materiales, unos segundos tras arrancar)
local SELL, STACK = {}, {}

-- Objetos raros: { itemId, nombre, habilidad minima, probabilidad por HORA de trabajo }
-- (los IDs inexistentes se descartan al arrancar; con DEBUG_MATERIALS ves el nombre real)
local RARE = {
    FISHING = {
        { 5500,  "Perla iridiscente",   1,   0.10 },
        { 5523,  "Almeja gigante",      50,  0.08 },
        { 7971,  "Perla negra",         100, 0.05 },
        { 13926, "Perla dorada",        200, 0.03 },
    },
    HERBALISM = {
        { 13468, "Loto negro",          275, 0.03 },
        { 36908, "Loto de escarcha",    435, 0.05 },
    },
    MINING = {
        { 774,   "Malaquita",           1,   0.12 },
        { 818,   "Ojo de tigre",        1,   0.12 },
        { 1210,  "Gema de sombra",      75,  0.10 },
        { 1206,  "Ágata musgosa",       75,  0.10 },
        { 1529,  "Jade",                125, 0.08 },
        { 3864,  "Citrino",             125, 0.08 },
        { 7909,  "Aguamarina",          175, 0.07 },
        { 7910,  "Rubí estelar",        175, 0.06 },
        { 12361, "Zafiro azul",         250, 0.05 },
        { 12364, "Esmeralda enorme",    250, 0.05 },
        { 12363, "Cristal arcano",      275, 0.03 },
        { 23117, "Piedra lunar azur",   300, 0.07 },
        { 23077, "Granate sanguíneo",   300, 0.07 },
        { 23079, "Peridoto profundo",   300, 0.07 },
        { 36917, "Piedra de sangre",    350, 0.07 },
        { 36923, "Calcedonia",          350, 0.07 },
        { 36932, "Jade oscuro",         375, 0.06 },
    },
    SKINNING = {
        { 8154,  "Escama de escorpéido",       75,  0.10 },
        { 15408, "Escama de escorpéido pesada", 200, 0.06 },
        { 15417, "Cuero de demosaurio",        250, 0.04 },
        { 25649, "Restos de cuero nudoso",     300, 0.10 },
        { 33567, "Restos de cuero boreal",     350, 0.10 },
        { 44128, "Piel ártica",                400, 0.05 },
    },
}
for _, list in pairs(RARE) do
    for i, r in ipairs(list) do
        list[i] = { id = r[1], name = r[2], min = r[3], chance = r[4] }
    end
end

local NAMES = {}
for _, list in pairs(MATERIALS) do for _, m in ipairs(list) do NAMES[m.id] = m.name end end
for _, list in pairs(RARE)      do for _, r in ipairs(list) do NAMES[r.id] = r.name end end
local function ItemName(id) return NAMES[id] or ("objeto #" .. tostring(id)) end

-- ============================================================
--  UTILIDADES
-- ============================================================
local function Guard(label, fn)
    return function(...)
        local args = { ... }
        local n = select("#", ...)
        local ok, err = xpcall(function() return fn(unpack(args, 1, n)) end, function(e)
            local tb = (debug and debug.traceback) and debug.traceback("", 2) or ""
            return tostring(e) .. tb
        end)
        if not ok then print("[BotJobs] ERROR en " .. label .. ": " .. tostring(err)) end
    end
end

local function Esc(s) return (tostring(s or ""):gsub("'", "''")) end

local function FormatCopper(c)
    c = math.max(0, math.floor(c or 0))
    local g = math.floor(c / 10000)
    local s = math.floor((c % 10000) / 100)
    local b = c % 100
    local parts = {}
    if g > 0 then parts[#parts+1] = g .. " oro" end
    if s > 0 then parts[#parts+1] = s .. " plata" end
    if b > 0 or #parts == 0 then parts[#parts+1] = b .. " bronce" end
    return table.concat(parts, " ")
end

local function GuidKey(player) return tostring(player:GetGUIDLow()) end

local function FindMaterial(profKey, itemId)
    for _, m in ipairs(MATERIALS[profKey] or {}) do
        if m.id == itemId then return m end
    end
    return nil
end

-- ============================================================
--  ESTADO
-- ============================================================
local Jobs     = {}   -- [playerGuidStr] = { [botLowStr] = job }
local BotIndex = {}   -- [botLowStr] = playerGuidStr
local Session  = {}   -- [playerGuidStr] = { t, map, x, y }
local BOARD_TTL = 1800

-- Para BotGarrison (parche): ¿este bot esta en un trabajo?
function BotJobs_IsBotOnJob(guidLow)
    return BotIndex[tostring(guidLow)] ~= nil
end

local function CountJobs(guidStr)
    local n = 0
    for _ in pairs(Jobs[guidStr] or {}) do n = n + 1 end
    return n
end

-- Razon por la que un bot no esta libre (nil = libre)
local function BotBusyReason(guidLow)
    if BotIndex[tostring(guidLow)] then return "job" end
    if BotGarrison_IsBotOnMission and BotGarrison_IsBotOnMission(guidLow) then return "mission" end
    return nil
end

-- ============================================================
--  DESCANSO POR BOT
-- ============================================================
local BotCD = {}   -- [botLowStr] = { jobs, minutes, cdUntil, last }

local function FmtDur(secs)
    secs = math.max(0, math.ceil(secs or 0))
    local h = math.floor(secs / 3600)
    local m = math.ceil((secs % 3600) / 60)
    if m == 60 then h = h + 1; m = 0 end
    if h > 0 then return string.format("%d h %02d min", h, m) end
    return string.format("%d min", math.max(1, m))
end

local function CDDelete(botLow)
    if not CFG.PERSIST_JOBS then return end
    CharDBExecute(string.format("DELETE FROM character_bot_job_cd WHERE bot_guid = %d", botLow))
end

local function CDSave(botLow, masterLow, cd)
    if not CFG.PERSIST_JOBS then return end
    CharDBExecute(string.format(
        "REPLACE INTO character_bot_job_cd (bot_guid, player_guid, jobs, minutes, cd_until, last_time) " ..
        "VALUES (%d, %d, %d, %d, %d, %d)", botLow, masterLow, cd.jobs, cd.minutes, cd.cdUntil, cd.last))
end

--- Estado de descanso de un bot (carga de BD la primera vez y reinicia si ya caduco)
local function CDGet(botLow)
    local bk = tostring(botLow)
    local cd = BotCD[bk]
    if not cd then
        cd = { jobs = 0, minutes = 0, cdUntil = 0, last = 0 }
        if CFG.PERSIST_JOBS then
            local ok, res = pcall(function()
                return CharDBQuery(string.format(
                    "SELECT jobs, minutes, cd_until, last_time FROM character_bot_job_cd WHERE bot_guid = %d", botLow))
            end)
            if ok and res then
                cd.jobs, cd.minutes = res:GetUInt32(0), res:GetUInt32(1)
                cd.cdUntil, cd.last = res:GetUInt32(2), res:GetUInt32(3)
            end
        end
        BotCD[bk] = cd
    end
    local now = os.time()
    local stale = false
    if cd.cdUntil > 0 and now >= cd.cdUntil then
        stale = true
    elseif cd.cdUntil == 0 and cd.jobs > 0 and (CFG.BOT_CD_RESET_HOURS or 0) > 0
        and now - cd.last >= CFG.BOT_CD_RESET_HOURS * 3600 then
        stale = true
    end
    if stale then
        cd.jobs, cd.minutes, cd.cdUntil, cd.last = 0, 0, 0, 0
        CDDelete(botLow)
    end
    return cd
end

--- Segundos de descanso que le quedan al bot (0 = libre)
local function CDRemaining(botLow)
    if not CFG.BOT_CD_ENABLED then return 0 end
    local cd = CDGet(botLow)
    return math.max(0, cd.cdUntil - os.time())
end

--- Anota un trabajo completado. Devuelve los segundos de descanso si completa la tanda (0 si no).
local function CDRegisterJob(job)
    if not CFG.BOT_CD_ENABLED then return 0 end
    local cd = CDGet(job.botLow)
    local now = os.time()
    cd.jobs = cd.jobs + 1
    cd.minutes = cd.minutes + job.minutes
    cd.last = now
    local secs = 0
    if cd.jobs >= CFG.BOT_CD_JOBS then
        secs = math.floor(cd.minutes * 60 * CFG.BOT_CD_MULT)
        cd.cdUntil = now + secs
    end
    CDSave(job.botLow, job.masterLow, cd)
    return secs
end

-- ============================================================
--  ALTBOTS (de BotGarrison)
-- ============================================================
local function SafeIsAltBot(unit)
    if not unit then return false end
    if unit.IsAltBot then
        local ok, res = pcall(function() return unit:IsAltBot() end)
        if ok and res then return true end
    end
    if unit.IsPlayerbot then
        local ok, res = pcall(function() return unit:IsPlayerbot() end)
        if ok and res then return true end
    end
    return false
end

local function GetMasterBotMgr(player)
    if not GetPlayerbotsMgr then return nil end
    local ok, mgr = pcall(function()
        local pbm = GetPlayerbotsMgr()
        if pbm and pbm.GetPlayerbotMgr then return pbm:GetPlayerbotMgr(player) end
        return nil
    end)
    if ok then return mgr end
    return nil
end

--- Todos los altbots online del jugador (grupo + gestor), sin duplicados
local function CollectBots(player)
    local bots, seen = {}, {}
    local me = player:GetGUIDLow()
    local function add(bot)
        if not bot or not bot.GetGUIDLow then return end
        local g = bot:GetGUIDLow()
        if seen[g] or g == me then return end
        if not SafeIsAltBot(bot) then return end
        seen[g] = true
        bots[#bots+1] = bot
    end
    local group = player:GetGroup()
    if group then
        local members = group:GetMembers()
        if members then for _, m in pairs(members) do add(m) end end
    end
    local mgr = GetMasterBotMgr(player)
    if mgr and mgr.GetPlayerBots then
        local ok, list = pcall(function() return mgr:GetPlayerBots() end)
        if ok and list then for _, b in pairs(list) do add(b) end end
    end
    return bots
end

local function FindOnlineBot(player, guidLow, name)
    for _, b in ipairs(CollectBots(player)) do
        if b:GetGUIDLow() == guidLow then return b end
    end
    if name and GetPlayerByName then
        local ok, b = pcall(function() return GetPlayerByName(name) end)
        if ok and b then return b end
    end
    return nil
end

-- ============================================================
--  HABILIDADES
-- ============================================================
local function CallFirst(unit, names, ...)
    for _, n in ipairs(names) do
        if unit[n] then
            local ok, r = pcall(unit[n], unit, ...)
            if ok and type(r) == "number" then return r end
        end
    end
    return nil
end

--- Habilidad de un bot ONLINE: val, max (nil si no tiene la profesion)
local function ReadSkillOnline(bot, skillId)
    local okH, has = pcall(function() return bot:HasSkill(skillId) end)
    if not (okH and has) then return nil end
    local val = CallFirst(bot, { "GetPureSkillValue", "GetBaseSkillValue", "GetSkillValue" }, skillId) or 0
    local max = CallFirst(bot, { "GetPureMaxSkillValue", "GetMaxSkillValue" }, skillId) or 0
    if max <= 0 then max = math.max(75, math.ceil(val / 75) * 75) end
    return val, max
end

--- Habilidad de un bot OFFLINE (desde character_skills)
local function ReadSkillDB(guidLow, skillId)
    local ok, res = pcall(function()
        return CharDBQuery(string.format(
            "SELECT value, max FROM character_skills WHERE guid = %d AND skill = %d", guidLow, skillId))
    end)
    if not ok or not res then return nil end
    return res:GetUInt32(0), res:GetUInt32(1)
end

local function SkillMult(skill, req)
    local diff = skill - req
    for _, t in ipairs(CFG.SKILL_TIERS) do
        if diff < t.upTo then return t.mult end
    end
    return CFG.SKILL_TIERS[#CFG.SKILL_TIERS].mult
end

local function GainBase(skill, minutes)
    local decay = math.max(CFG.SKILL_DECAY_FLOOR, 1 - skill / CFG.SKILL_DECAY_SCALE)
    return minutes * CFG.SKILL_PER_MIN * decay
end

--- Formula unica (el cliente usa la misma para la estimacion)
local function CalcGain(base, mult, bonus, cap, room)
    local g = math.floor(base * mult + 0.5) + math.max(1, math.floor(bonus * mult + 0.5))
    g = math.min(g, cap, room)
    return math.max(0, g)
end

-- Valor estimado de 1 unidad (cobre)
local function UnitValue(profKey, mat)
    local sp = SELL[mat.id]
    if sp and sp > 0 then return sp * (CFG.PRICE_VALUE_MULT[profKey] or 1) end
    return CFG.PRICE_FALLBACK.base + mat.req * CFG.PRICE_FALLBACK.perSkill
end

-- Materiales que pueden llegar como extra para un bot de habilidad `val`
local function BycatchPool(profKey, val, excludeId)
    local pool, lo = {}, val - CFG.BYCATCH_RANGE
    for _, m in ipairs(MATERIALS[profKey] or {}) do
        if m.req <= val and m.req >= lo and m.id ~= excludeId then pool[#pool + 1] = m end
    end
    return pool
end

-- Valor medio (ponderado por rate) de un extra; nil si no hay extras posibles
local function PoolAvg(profKey, val)
    local sum, w = 0, 0
    for _, m in ipairs(BycatchPool(profKey, val, nil)) do
        sum = sum + UnitValue(profKey, m) * m.rate
        w = w + m.rate
    end
    if w <= 0 then return nil end
    return sum / w
end

local function PickWeighted(pool)
    local total = 0
    for _, m in ipairs(pool) do total = total + m.rate end
    local r = math.random() * total
    for _, m in ipairs(pool) do
        r = r - m.rate
        if r <= 0 then return m end
    end
    return pool[#pool]
end

--- Unidades esperadas del material elegido (sin variacion ni doble)
local function ExpectedMain(profKey, mat, dur)
    return dur.min * (CFG.ITEMS_PER_MIN[profKey] or 0.3) * mat.rate * (dur.loot or 1)
end

--- Precio del trabajo (cobre). Misma funcion para el panel y para cobrar.
local function JobPrice(profKey, mat, dur, poolAvg)
    local q = ExpectedMain(profKey, mat, dur)
    local value = q * (1 + CFG.DOUBLE_CHANCE) * UnitValue(profKey, mat)
    if poolAvg then value = value + q * CFG.BYCATCH_PCT * poolAvg end
    local p = value * CFG.PRICE_PCT * dur.priceMult * (CFG.PROF_PRICE_MULT[profKey] or 1)
    local r = math.max(1, CFG.PRICE_ROUND or 1)
    p = math.ceil(p / r) * r
    return math.max(CFG.MIN_PRICE, p)
end

-- ============================================================
--  EFECTOS / APARCAMIENTO (de BotGarrison)
-- ============================================================
local function BotSalute(unit, label)
    if not unit then return false end
    pcall(function() if unit.EmoteState then unit:EmoteState(0) end end)
    local ok, err = pcall(function() unit:PerformEmote(66) end)
    if not ok then print("[BotJobs] Saludo de '" .. tostring(label) .. "' fallo: " .. tostring(err)) end
    return ok
end

local function FxCastSelf(unit, list)
    for _, id in ipairs(list or {}) do pcall(function() unit:CastSpell(unit, id, true) end) end
end

local function FxClear(unit)
    if not unit then return end
    pcall(function()
        if CFG.DEPART_FX_FADE then unit:RemoveAura(CFG.DEPART_FX_FADE) end
        for _, id in ipairs(CFG.DEPART_FX_CHARGE or {}) do unit:RemoveAura(id) end
        for _, id in ipairs(CFG.DEPART_FX_BURST or {}) do unit:RemoveAura(id) end
    end)
end

local function BotFinder(botGuid, name)
    return function()
        local b = GetPlayerByGUID and GetPlayerByGUID(botGuid) or nil
        if not b and GetPlayerByName then
            local ok, bb = pcall(function() return GetPlayerByName(name) end)
            if ok then b = bb end
        end
        return b
    end
end

--- Saludo + efecto + teleport al aparcamiento
local function ParkBot(master, bot)
    local masterGuid = master:GetGUID()
    local name = bot:GetName()
    local find = BotFinder(bot:GetGUID(), name)

    pcall(function()
        local mgr = GetMasterBotMgr(master)
        if mgr and mgr.HandlePlayerbotCommand then mgr:HandlePlayerbotCommand("bot " .. name .. " stay") end
    end)

    local faceOn = (CFG.SALUTE_FACE_PLAYER ~= false)
    if faceOn then
        CreateLuaEvent(Guard("job-face", function()
            local b, pl = find(), GetPlayerByGUID(masterGuid)
            if b and pl and b.SetFacingToObject then pcall(function() b:SetFacingToObject(pl) end) end
        end), 400, 1)
    end
    CreateLuaEvent(Guard("job-salute", function()
        local b = find()
        if b then BotSalute(b, name) end
    end), faceOn and 1100 or 500, 1)

    local fx = (CFG.DEPART_FX ~= false)
    if fx then
        CreateLuaEvent(Guard("job-fx-charge", function()
            local b = find()
            if b then FxCastSelf(b, CFG.DEPART_FX_CHARGE) end
        end), CFG.DEPART_FX_CHARGE_AT, 1)
        CreateLuaEvent(Guard("job-fx-fade", function()
            local b = find()
            if not b then return end
            FxCastSelf(b, CFG.DEPART_FX_BURST)
            if CFG.DEPART_FX_FADE then pcall(function() b:CastSpell(b, CFG.DEPART_FX_FADE, true) end) end
        end), CFG.DEPART_FX_FADE_AT, 1)
    end

    CreateLuaEvent(Guard("job-park-teleport", function()
        local b = find()
        if not b then return end
        if fx then FxClear(b) end
        pcall(function() b:Teleport(CFG.PARK_MAP, CFG.PARK_X, CFG.PARK_Y, CFG.PARK_Z, CFG.PARK_O) end)
    end), fx and CFG.DEPART_FX_TELEPORT_AT or 3500, 1)
end

local function ForceParkBot(master, bot)
    pcall(function()
        local mgr = GetMasterBotMgr(master)
        local name = bot:GetName()
        if mgr and mgr.HandlePlayerbotCommand and name then
            pcall(function() mgr:HandlePlayerbotCommand("bot " .. name .. " stay") end)
        end
        bot:Teleport(CFG.PARK_MAP, CFG.PARK_X, CFG.PARK_Y, CFG.PARK_Z, CFG.PARK_O)
    end)
end

--- Trae al bot de vuelta con Traslacion (Blink) y lo pone a seguir
local function RecallBot(master, bot)
    local masterGuid = master:GetGUID()
    local name = bot:GetName()
    local find = BotFinder(bot:GetGUID(), name)
    local px, py, pz, po = master:GetX(), master:GetY(), master:GetZ(), master:GetO()
    local pmap = master:GetMapId()
    local blink = (CFG.ARRIVE_BLINK ~= false)

    FxClear(bot)
    local tx, ty, tz, to = px + math.random(-3, 3), py + math.random(-3, 3), pz, po
    if blink then
        local ang = po + math.pi + (math.random() - 0.5) * 1.6
        tx, ty = px + CFG.ARRIVE_BLINK_DIST * math.cos(ang), py + CFG.ARRIVE_BLINK_DIST * math.sin(ang)
        pcall(function()
            local map = master:GetMap()
            if map and map.GetHeight then
                local h = map:GetHeight(tx, ty)
                if type(h) == "number" and h > -500 and math.abs(h - pz) < 15 then tz = h + 0.5 end
            end
        end)
        to = math.atan2(py - ty, px - tx)
    end
    local ok = pcall(function() bot:Teleport(pmap, tx, ty, tz, to) end)

    local function followAndSalute(b)
        pcall(function()
            local mgr = GetMasterBotMgr(GetPlayerByGUID(masterGuid))
            if mgr and mgr.HandlePlayerbotCommand then mgr:HandlePlayerbotCommand("bot " .. name .. " follow") end
        end)
        BotSalute(b, name)
    end

    if ok and blink then
        CreateLuaEvent(Guard("job-arrive-blink", function()
            local b, pl = find(), GetPlayerByGUID(masterGuid)
            if not b or not pl then return end
            pcall(function() if b.SetFacingToObject then b:SetFacingToObject(pl) end end)
            pcall(function() b:CastSpell(b, CFG.ARRIVE_BLINK_SPELL, true) end)
            CreateLuaEvent(Guard("job-arrive-settle", function()
                local b2, pl2 = find(), GetPlayerByGUID(masterGuid)
                if not b2 or not pl2 then return end
                local okD, d = pcall(function() return b2:GetDistance(pl2) end)
                if okD and type(d) == "number" and d > 10 then
                    pcall(function()
                        b2:Teleport(pl2:GetMapId(), pl2:GetX() + math.random(-2, 2),
                            pl2:GetY() + math.random(-2, 2), pl2:GetZ(), pl2:GetO())
                    end)
                end
                followAndSalute(b2)
            end), 700, 1)
        end), CFG.ARRIVE_BLINK_DELAY_MS, 1)
    else
        followAndSalute(bot)
    end
end

-- ============================================================
--  PERSISTENCIA (characters.character_bot_jobs)
-- ============================================================
local function SaveJob(job)
    if not CFG.PERSIST_JOBS then return end
    CharDBExecute(string.format(
        "REPLACE INTO character_bot_jobs (player_guid, bot_guid, bot_name, prof, item_id, minutes, price, start_time, end_time) " ..
        "VALUES (%d, %d, '%s', '%s', %d, %d, %d, %d, %d)",
        job.masterLow, job.botLow, Esc(job.botName), job.prof, job.itemId, job.minutes, job.price, job.startTime, job.endTime))
end

local function DeleteJob(job)
    if not CFG.PERSIST_JOBS then return end
    CharDBExecute(string.format(
        "DELETE FROM character_bot_jobs WHERE player_guid = %d AND bot_guid = %d", job.masterLow, job.botLow))
end

local function RegisterJob(job)
    local pk, bk = tostring(job.masterLow), tostring(job.botLow)
    Jobs[pk] = Jobs[pk] or {}
    Jobs[pk][bk] = job
    BotIndex[bk] = pk
end

local function UnregisterJob(job)
    local pk, bk = tostring(job.masterLow), tostring(job.botLow)
    if Jobs[pk] then Jobs[pk][bk] = nil end
    BotIndex[bk] = nil
end

local function LoadJobsFromDB(player)
    if not CFG.PERSIST_JOBS then return end
    local low = player:GetGUIDLow()
    local ok, res = pcall(function()
        return CharDBQuery(string.format(
            "SELECT bot_guid, bot_name, prof, item_id, minutes, price, start_time, end_time " ..
            "FROM character_bot_jobs WHERE player_guid = %d", low))
    end)
    if not ok or not res then return end
    repeat
        local job = {
            masterLow = low, masterGuid = player:GetGUID(),
            botLow = res:GetUInt32(0), botName = res:GetString(1), prof = res:GetString(2),
            itemId = res:GetUInt32(3), minutes = res:GetUInt32(4), price = res:GetUInt32(5),
            startTime = res:GetUInt32(6), endTime = res:GetUInt32(7),
        }
        local pk, bk = tostring(low), tostring(job.botLow)
        if PROFS[job.prof] and not (Jobs[pk] and Jobs[pk][bk]) then
            RegisterJob(job)
        end
    until not res:NextRow()
end

-- ============================================================
--  BOTIN / CORREO
-- ============================================================
--- loot = array { {id=, qty=}, ... }. Devuelve true si todo se envio.
local function MailLoot(masterLow, jobName, loot)
    local stacks = {}
    for _, it in ipairs(loot) do
        local maxS = math.max(1, math.min(CFG.STACK_SIZE, STACK[it.id] or CFG.STACK_SIZE))
        local left = it.qty
        while left > 0 do
            local n = math.min(left, maxS)
            stacks[#stacks + 1] = { it.id, n }
            left = left - n
        end
    end
    local per = CFG.MAIL_ATTACH_MAX
    local total = math.ceil(#stacks / per)
    local i, part = 1, 1
    while i <= #stacks do
        local args, sums, order = {}, {}, {}
        for k = i, math.min(i + per - 1, #stacks) do
            args[#args + 1] = stacks[k][1]
            args[#args + 1] = stacks[k][2]
            if not sums[stacks[k][1]] then order[#order + 1] = stacks[k][1] end
            sums[stacks[k][1]] = (sums[stacks[k][1]] or 0) + stacks[k][2]
        end
        local lines = {}
        for _, id in ipairs(order) do lines[#lines + 1] = string.format("- %s x%d", ItemName(id), sums[id]) end
        local subj = "Trabajo terminado: " .. jobName
        if total > 1 then subj = subj .. string.format(" (%d/%d)", part, total) end
        local body = "Tu compañero ha vuelto de su trabajo.\n" .. table.concat(lines, "\n")
        local ok, err = pcall(function()
            SendMail(subj, body, masterLow, 0, 41, 0, 0, 0, unpack(args))
        end)
        if not ok then
            print("[BotJobs] SendMail fallo: " .. tostring(err))
            return false
        end
        i = i + per
        part = part + 1
    end
    return true
end

--- Genera el botin de un trabajo.
--- Devuelve: lootMap {id->qty}, base (principal sin doblar), main (principal final), doubled, extraUnits, rares {r,...}
local function BuildLoot(job, val, mat, dur)
    local prof = job.prof
    local skillRef = val or (mat and mat.req) or 1
    local ipm = CFG.ITEMS_PER_MIN[prof] or 0.3
    local var = 1 + (math.random() * 2 - 1) * CFG.QTY_VARIANCE
    local base = math.max(1, math.floor(job.minutes * ipm * (mat and mat.rate or 1) * (dur.loot or 1) * var + 0.5))
    local doubled = math.random() < CFG.DOUBLE_CHANCE
    local main = doubled and base * 2 or base
    local loot = { [job.itemId] = main }

    local extraUnits = 0
    if mat and CFG.BYCATCH_PCT > 0 then
        local pool = BycatchPool(prof, skillRef, mat.id)
        if #pool > 0 then
            local n = math.min(100, math.floor(base * CFG.BYCATCH_PCT + 0.5))
            for _ = 1, n do
                local m = PickWeighted(pool)
                loot[m.id] = (loot[m.id] or 0) + 1
                extraUnits = extraUnits + 1
            end
        end
    end

    local rares = {}
    if CFG.RARE_ENABLED then
        local hours = job.minutes / 60
        local cands = {}
        for _, r in ipairs(RARE[prof] or {}) do
            if skillRef >= r.min and skillRef - r.min <= CFG.RARE_RANGE
               and math.random() < 1 - (1 - r.chance * CFG.RARE_CHANCE_MULT) ^ hours then
                cands[#cands + 1] = r
            end
        end
        while #cands > 0 and #rares < (CFG.RARE_MAX or 2) do
            local r = table.remove(cands, math.random(#cands))
            loot[r.id] = (loot[r.id] or 0) + 1
            rares[#rares + 1] = r
        end
    end
    return loot, base, main, doubled, extraUnits, rares
end

-- ============================================================
--  AIO: envio de estado
-- ============================================================
local SendBoard   -- definida abajo

local function JobsPayload(guidStr)
    local list, now = {}, os.time()
    for _, j in pairs(Jobs[guidStr] or {}) do
        local m = FindMaterial(j.prof, j.itemId)
        list[#list+1] = {
            bot       = j.botName,
            prof      = j.prof,
            profName  = PROFS[j.prof].name,
            mat       = m and m.name or ("objeto #" .. j.itemId),
            minutes   = j.minutes,
            remaining = math.max(0, j.endTime - now),
            total     = math.max(1, j.endTime - j.startTime),
        }
    end
    table.sort(list, function(a, b) return a.remaining < b.remaining end)
    return list
end

local function SendDiary(player, entry)
    if CFG.DIARY_ENABLED then AIO.Handle(player, "BotJobs", "DiaryEntry", entry) end
end

-- ============================================================
--  FINALIZAR TRABAJO
-- ============================================================
local function FinishJob(p, job)
    local prof = PROFS[job.prof]
    local mat  = FindMaterial(job.prof, job.itemId)
    local matName = ItemName(job.itemId)
    local dur
    for _, d in ipairs(CFG.DURATIONS) do if d.min == job.minutes then dur = d; break end end
    dur = dur or { min = job.minutes, cap = 9999, loot = 1.0, priceMult = 1.0 }   -- trabajo guardado con una duracion que ya no existe
    local cap = dur.cap or 9999

    -- Estado de la habilidad (online por API, offline por BD)
    local bot = FindOnlineBot(p, job.botLow, job.botName)
    local val, max
    if bot then val, max = ReadSkillOnline(bot, prof.skill) else val, max = ReadSkillDB(job.botLow, prof.skill) end

    -- Botin
    local lootMap, base, main, doubled, extraUnits, rares = BuildLoot(job, val, mat, dur)
    local rareSet = {}
    for _, r in ipairs(rares) do rareSet[r.id] = true end

    -- Habilidad
    local gain, newVal = 0, val
    if val and max and val < max then
        local mult = mat and SkillMult(val, mat.req) or 1
        local bonus = math.random(CFG.SKILL_BONUS_MIN, CFG.SKILL_BONUS_MAX)
        gain = CalcGain(GainBase(val, job.minutes), mult, bonus, cap, max - val)
        newVal = val + gain
        if gain > 0 then
            if bot then
                local step = math.max(1, math.floor(max / 75))
                local ok, err = pcall(function() bot:SetSkill(prof.skill, step, newVal, max) end)
                if not ok then
                    print("[BotJobs] SetSkill fallo: " .. tostring(err))
                    gain, newVal = 0, val
                end
            else
                CharDBExecute(string.format(
                    "UPDATE character_skills SET value = %d WHERE guid = %d AND skill = %d", newVal, job.botLow, prof.skill))
            end
        end
    end

    -- Correo (principal primero, luego por id)
    local list = {}
    for id, q in pairs(lootMap) do list[#list + 1] = { id = id, qty = q } end
    table.sort(list, function(a, b)
        local ra, rb = (a.id == job.itemId) and 0 or 1, (b.id == job.itemId) and 0 or 1
        if ra ~= rb then return ra < rb end
        return a.id < b.id
    end)
    local mailed = MailLoot(job.masterLow, prof.name, list)
    if not mailed then
        for _, it in ipairs(list) do pcall(function() p:AddItem(it.id, it.qty) end) end
    end

    -- Cerrar trabajo
    UnregisterJob(job)
    DeleteJob(job)
    if bot then RecallBot(p, bot) end
    local cdSecs = CDRegisterJob(job)

    p:SendBroadcastMessage(string.format(
        "|cff00ff00[BotJobs]|r ¡|cffffcc00%s|r ha vuelto de su trabajo de %s!", job.botName, prof.name))
    p:SendBroadcastMessage(string.format(
        "  |cffffcc00Botín:|r |cffffffff%s x%d|r%s %s", matName, main,
        doubled and " |cff00ff00(¡doble!)|r" or "",
        mailed and "(enviado por |cffffffffcorreo|r)" or "|cffff8800(entregado en mochila: fallo el correo)|r"))
    if extraUnits > 0 then
        local names, shown = {}, 0
        for _, it in ipairs(list) do
            if it.id ~= job.itemId and not rareSet[it.id] then
                shown = shown + 1
                if shown <= 4 then names[#names + 1] = string.format("%s x%d", ItemName(it.id), it.qty) end
            end
        end
        p:SendBroadcastMessage("  |cffffcc00Extras:|r |cffffffff" .. table.concat(names, ", ") ..
            (shown > 4 and string.format(" y %d más", shown - 4) or "") .. "|r")
    end
    local rareNames = {}
    for _, r in ipairs(rares) do rareNames[#rareNames + 1] = r.name end
    if #rareNames > 0 then
        p:SendBroadcastMessage("  |cffa335ee¡Hallazgo raro!|r |cffffffff" .. table.concat(rareNames, ", ") .. "|r")
    end
    if val then
        if gain > 0 then
            p:SendBroadcastMessage(string.format(
                "  |cffffcc00%s:|r |cff00ff00+%d|r (%d → %d/%d)", prof.name, gain, val, newVal, max))
        elseif val >= max then
            p:SendBroadcastMessage(string.format(
                "  |cffffcc00%s:|r al tope de su rango (%d/%d). Necesita entrenar para seguir subiendo.", prof.name, val, max))
        else
            p:SendBroadcastMessage("  |cffff8800No ha aprendido nada de este trabajo.|r")
        end
    else
        p:SendBroadcastMessage("|cffff8800[BotJobs]|r No se pudo leer la habilidad del compañero (no se aplicó subida).")
    end

    if cdSecs and cdSecs > 0 then
        p:SendBroadcastMessage(string.format(
            "|cffff8800[BotJobs]|r |cffffcc00%s|r ha completado su tanda de %d trabajos y descansará |cffffffff%s|r.",
            job.botName, CFG.BOT_CD_JOBS, FmtDur(cdSecs)))
    end

    SendDiary(p, {
        t = os.time(), bot = job.botName, prof = job.prof, profName = prof.name,
        mat = matName, itemId = job.itemId, qty = main, extra = extraUnits, double = doubled,
        rare = table.concat(rareNames, ", "),
        cd = cdSecs or 0,
        minutes = job.minutes, price = job.price,
        from = val or 0, to = newVal or 0, gain = gain, max = max or 0,
    })
    SendBoard(p, false)
    print(string.format("[BotJobs] Fin '%s' %s %s x%d (+%d extras, %d raros) skill +%d",
        job.botName, job.prof, matName, main, extraUnits, #rares, gain))
end

-- ============================================================
--  EMPEZAR TRABAJO
-- ============================================================
local function BoardNear(player, s)
    if CFG.PANEL_REMOTE_BOARD then return true end
    if not s or not s.t then return false end
    if os.time() - s.t > BOARD_TTL then return false end
    local range = CFG.NPC_RANGE
    local ok, res = pcall(function()
        if player:GetMapId() ~= s.map then return false end
        local dx, dy = player:GetX() - s.x, player:GetY() - s.y
        return (dx * dx + dy * dy) <= (range * range)
    end)
    return ok and res or false
end

local function SendBoardLater(player, ms)
    local guid = player:GetGUID()
    CreateLuaEvent(Guard("board-later", function()
        local p = GetPlayerByGUID(guid)
        if p then SendBoard(p, false) end
    end), ms or 1200, 1)
end

local function StartJob(player, botLow, profKey, itemId, durIdx)
    local guidStr = GuidKey(player)
    local function warn(msg) player:SendBroadcastMessage("|cffff8800[BotJobs]|r " .. msg) end

    if not BoardNear(player, Session[guidStr]) then
        warn("Debes estar junto al NPC para contratar un trabajo.")
        return false
    end
    local prof = PROFS[profKey]
    if not prof or not CFG.PROFESSIONS_ENABLED[profKey] then warn("Profesión no disponible."); return false end
    local dur = CFG.DURATIONS[durIdx]
    if not dur then warn("Duración no válida."); return false end
    if CountJobs(guidStr) >= CFG.MAX_JOBS_PER_PLAYER then
        warn(string.format("Ya tienes %d trabajos en curso (máximo).", CFG.MAX_JOBS_PER_PLAYER))
        return false
    end

    local bot = FindOnlineBot(player, botLow, nil)
    if not bot then warn("Ese compañero no está disponible (¿está conectado y en tu grupo?)."); return false end
    local busy = BotBusyReason(botLow)
    if busy then
        warn(busy == "job" and "Ese compañero ya está en un trabajo." or "Ese compañero está de misión.")
        return false
    end
    local cdLeft = CDRemaining(botLow)
    if cdLeft > 0 then
        warn("Ese compañero está descansando: podrá trabajar de nuevo en " .. FmtDur(cdLeft) .. ".")
        return false
    end

    local val, max = ReadSkillOnline(bot, prof.skill)
    if not val then warn("Ese compañero no tiene la profesión " .. prof.name .. "."); return false end
    local mat = FindMaterial(profKey, itemId)
    if not mat or mat.req > val then warn("Material no disponible para su habilidad."); return false end

    local price = JobPrice(profKey, mat, dur, PoolAvg(profKey, val))
    if player:GetCoinage() < price then
        warn("No tienes suficiente oro: se necesitan " .. FormatCopper(price) .. ".")
        return false
    end
    player:ModifyMoney(-price)

    local now = os.time()
    local job = {
        masterLow = player:GetGUIDLow(), masterGuid = player:GetGUID(),
        botLow = botLow, botName = bot:GetName(), prof = profKey, itemId = itemId,
        minutes = dur.min, price = price, startTime = now, endTime = now + dur.min * 60,
        graceUntil = now + 10,
    }
    RegisterJob(job)
    SaveJob(job)
    ParkBot(player, bot)

    player:SendBroadcastMessage(string.format(
        "|cff00ccff[BotJobs]|r |cffffcc00%s|r parte a %s: |cffffffff%s|r durante |cffffffff%d min|r. Coste: |cffffffff%s|r.",
        job.botName, string.lower(prof.name), mat.name, dur.min, FormatCopper(price)))
    return true
end

-- ============================================================
--  PAYLOAD DEL PANEL
-- ============================================================
local CLASS_NAMES = {}  -- reservado

local function BuildBoard(player, open, creature)
    local guidStr = GuidKey(player)

    local s = Session[guidStr]
    if open or (CFG.PANEL_REMOTE_BOARD and not s) then
        local map, x, y = player:GetMapId(), player:GetX(), player:GetY()
        if creature then
            pcall(function() map, x, y = creature:GetMapId(), creature:GetX(), creature:GetY() end)
        end
        s = { t = os.time(), map = map, x = x, y = y }
        Session[guidStr] = s
    end

    local payload = {
        open  = open and true or false,
        near  = false,
        money = player:GetCoinage(),
        used  = CountJobs(guidStr),
        maxJobs = CFG.MAX_JOBS_PER_PLAYER,
        bonusMin = CFG.SKILL_BONUS_MIN,
        bonusMax = CFG.SKILL_BONUS_MAX,
        bycatch = CFG.BYCATCH_PCT,
        cdOn = CFG.BOT_CD_ENABLED and true or false,
        cdJobs = CFG.BOT_CD_JOBS,
        cdMult = CFG.BOT_CD_MULT,
        dbl = CFG.DOUBLE_CHANCE,
        jobs  = JobsPayload(guidStr),
        durs  = {},
        bots  = {},
    }

    if not (s and BoardNear(player, s)) then return payload end
    payload.near = true

    for _, d in ipairs(CFG.DURATIONS) do
        payload.durs[#payload.durs+1] = { min = d.min, cap = d.cap, loot = d.loot }
    end

    for _, bot in ipairs(CollectBots(player)) do
        local low = bot:GetGUIDLow()
        local entry = {
            guid = low, name = bot:GetName(), class = bot:GetClass(), level = bot:GetLevel(),
            busy = BotBusyReason(low), profs = {},
        }
        if CFG.BOT_CD_ENABLED then
            local cds = CDGet(low)
            entry.cd  = math.max(0, cds.cdUntil - os.time())   -- segundos de descanso restantes
            entry.cnt = cds.jobs                               -- trabajos hechos en la tanda
            entry.cmin = cds.minutes                           -- minutos trabajados en la tanda
        end
        for _, key in ipairs(PROF_ORDER) do
            if CFG.PROFESSIONS_ENABLED[key] then
                local prof = PROFS[key]
                local val, max = ReadSkillOnline(bot, prof.skill)
                if val then
                    local mats = {}
                    local poolAvg = PoolAvg(key, val)
                    for _, m in ipairs(MATERIALS[key]) do
                        if m.req <= val then
                            local pr, qt = {}, {}
                            for i, d in ipairs(CFG.DURATIONS) do
                                pr[i] = JobPrice(key, m, d, poolAvg)
                                qt[i] = math.max(1, math.floor(ExpectedMain(key, m, d) + 0.5))
                            end
                            mats[#mats+1] = { id = m.id, name = m.name, req = m.req, mult = SkillMult(val, m.req), p = pr, q = qt }
                        end
                    end
                    if #mats > 0 then
                        local gains = {}
                        for i, d in ipairs(CFG.DURATIONS) do gains[i] = GainBase(val, d.min) end
                        entry.profs[#entry.profs+1] = {
                            key = key, name = prof.name, val = val, max = max,
                            mats = mats, gain = gains,
                        }
                    end
                end
            end
        end
        if #entry.profs > 0 then payload.bots[#payload.bots+1] = entry end
    end
    return payload
end

SendBoard = function(player, open, creature)
    local ok, payload = pcall(BuildBoard, player, open, creature)
    if not ok then
        print("[BotJobs] Error construyendo el panel: " .. tostring(payload))
        return false
    end
    AIO.Handle(player, "BotJobs", "BoardData", payload)
    return true
end

-- ============================================================
--  HANDLERS AIO
-- ============================================================
BJ.requestBoard = Guard("requestBoard", function(player)
    if not Jobs[GuidKey(player)] then LoadJobsFromDB(player) end
    SendBoard(player, false)
end)

BJ.startJob = Guard("startJob", function(player, botLow, profKey, itemId, durIdx)
    botLow, itemId, durIdx = tonumber(botLow), tonumber(itemId), tonumber(durIdx)
    if not botLow or not itemId or not durIdx or type(profKey) ~= "string" then return end
    local started = StartJob(player, botLow, profKey, itemId, durIdx)
    SendBoard(player, false)
end)

-- ============================================================
--  NPC
-- ============================================================
local function OnHello(event, player, creature)
    if not Jobs[GuidKey(player)] then LoadJobsFromDB(player) end
    if BotJobs_NpcGreet then pcall(BotJobs_NpcGreet, creature, player) end   -- saludo (BotJobs_Npc.lua, opcional)
    if not SendBoard(player, true, creature) then
        player:SendBroadcastMessage("|cffff4444[BotJobs]|r El panel no está disponible (¿AIO activo?).")
    end
    player:GossipComplete()
    return true
end
RegisterCreatureGossipEvent(CFG.NPC_ENTRY, 1, OnHello)
RegisterCreatureGossipEvent(CFG.NPC_ENTRY, 2, function(event, player)
    player:GossipComplete()
    return true
end)

-- ============================================================
--  LOGIN / BARRIDO / WATCHDOG
-- ============================================================
RegisterPlayerEvent(3, Guard("login", function(event, player)
    if SafeIsAltBot(player) then return end
    local guidStr = GuidKey(player)
    if not Jobs[guidStr] then LoadJobsFromDB(player) end
    local set = Jobs[guidStr]
    if not set or next(set) == nil then return end
    local guid = player:GetGUID()
    local now = os.time()
    for _, job in pairs(set) do
        job.masterGuid = guid
        job.finishAfter = now + 8      -- dar tiempo a que cargue el mundo
        job.graceUntil  = now + 10
    end
    player:SendBroadcastMessage(string.format(
        "|cff00ccff[BotJobs]|r Tienes %d trabajo(s) en curso. /bj para verlos.", CountJobs(guidStr)))
end))

local function Sweep()
    local now = os.time()
    for _, set in pairs(Jobs) do
        for _, job in pairs(set) do
            if now >= job.endTime and now >= (job.finishAfter or 0) and not job.finishing then
                local p = job.masterGuid and GetPlayerByGUID(job.masterGuid) or nil
                if p then
                    job.finishing = true
                    local ok, err = pcall(FinishJob, p, job)
                    if not ok then
                        job.tries = (job.tries or 0) + 1
                        print("[BotJobs] FinishJob fallo (" .. job.tries .. "): " .. tostring(err))
                        if job.tries < 3 then job.finishing = false end
                    end
                end
            end
        end
    end
end
CreateLuaEvent(Guard("sweep", Sweep), CFG.SWEEP_MS, 0)

local function Watchdog()
    local near = CFG.SUMMON_NEAR_YARDS
    local now = os.time()
    for _, set in pairs(Jobs) do
        for _, job in pairs(set) do
            if now < job.endTime and now >= (job.graceUntil or 0) and not job.finishing then
                local p = job.masterGuid and GetPlayerByGUID(job.masterGuid) or nil
                if p then
                    local bot = FindOnlineBot(p, job.botLow, job.botName)
                    if bot then
                        local needPark = false
                        local okM, bmap = pcall(function() return bot:GetMapId() end)
                        if okM and bmap ~= CFG.PARK_MAP then needPark = true end
                        if not needPark then
                            local okD, dist = pcall(function() return p:GetDistance(bot) end)
                            if okD and dist and dist < near then needPark = true end
                        end
                        if needPark then
                            ForceParkBot(p, bot)
                            p:SendBroadcastMessage("|cffff8800[BotJobs]|r " .. job.botName .. " sigue trabajando: volverá al terminar.")
                        end
                    end
                end
            end
        end
    end
end
if (CFG.WATCHDOG_MS or 0) > 0 then
    CreateLuaEvent(Guard("watchdog", Watchdog), CFG.WATCHDOG_MS, 0)
end

-- ============================================================
--  VALIDACION DE MATERIALES (al arrancar)
-- ============================================================
CreateLuaEvent(Guard("validate-materials", function()
    local ids, seen = {}, {}
    local function addId(id) if not seen[id] then seen[id] = true; ids[#ids + 1] = id end end
    for _, list in pairs(MATERIALS) do for _, m in ipairs(list) do addId(m.id) end end
    for _, list in pairs(RARE)      do for _, r in ipairs(list) do addId(r.id) end end
    local res = WorldDBQuery("SELECT entry, name, SellPrice, stackable FROM item_template WHERE entry IN (" .. table.concat(ids, ",") .. ")")
    if not res then
        print("[BotJobs] AVISO: no se pudo validar item_template; se usan todos los materiales y precios de reserva.")
        return
    end
    local exist = {}
    repeat
        local id = res:GetUInt32(0)
        exist[id] = res:GetString(1)
        SELL[id]  = res:GetUInt32(2)
        STACK[id] = math.max(1, res:GetUInt32(3))
    until not res:NextRow()
    local removed = 0
    for key, list in pairs(MATERIALS) do
        local keep = {}
        for _, m in ipairs(list) do
            if exist[m.id] then
                keep[#keep + 1] = m
            else
                removed = removed + 1
                print(string.format("[BotJobs] AVISO: item %d (%s) no existe en item_template: descartado.", m.id, m.name))
            end
        end
        MATERIALS[key] = keep
    end
    for key, list in pairs(RARE) do
        local keep = {}
        for _, r in ipairs(list) do
            if exist[r.id] then
                keep[#keep + 1] = r
            else
                removed = removed + 1
                print(string.format("[BotJobs] AVISO: objeto raro %d (%s) no existe en item_template: descartado.", r.id, r.name))
            end
        end
        RARE[key] = keep
    end
    if CFG.DEBUG_MATERIALS then
        local d = CFG.DURATIONS[3] or CFG.DURATIONS[#CFG.DURATIONS]
        for key, list in pairs(MATERIALS) do
            local pa
            for _, m in ipairs(list) do
                pa = PoolAvg(key, m.req)
                print(string.format("[BotJobs] %s %d '%s' <- BD: '%s' | SellPrice %d | %d min: ~%d uds, precio %s",
                    key, m.id, m.name, exist[m.id], SELL[m.id] or 0, d.min,
                    math.floor(ExpectedMain(key, m, d) + 0.5), FormatCopper(JobPrice(key, m, d, pa))))
            end
        end
        for key, list in pairs(RARE) do
            for _, r in ipairs(list) do
                print(string.format("[BotJobs] RARO %s %d '%s' <- BD: '%s'", key, r.id, r.name, exist[r.id]))
            end
        end
    end
    print(string.format("[BotJobs] Materiales validados (%d descartados).", removed))
end), 3000, 1)

print("[BotJobs] v0.4.0 cargado — NPC " .. CFG.NPC_ENTRY)
