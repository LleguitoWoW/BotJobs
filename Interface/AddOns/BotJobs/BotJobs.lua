-- ============================================================
--  BotJobs Client (3.3.5) v0.4
--  Panel de trabajos de profesion + diario + minimapa
-- ============================================================

local AIO = AIO or require("AIO")
if AIO.AddAddon() then return end

local Handlers = AIO.AddHandlers("BotJobs", {})

local UI = {}
UI.board = nil
UI.selKey, UI.selMat, UI.selDur = nil, nil, 1
UI._dragging = false

local WHITE = "Interface\\Buttons\\WHITE8X8"
local WIN_W, WIN_H = 470, 540
local PANEL_W = 434
local ROW_H = 20
local JOB_ROWS = 5

local PROF_ICON = {
    FISHING   = "Interface\\Icons\\Trade_Fishing",
    HERBALISM = "Interface\\Icons\\Trade_Herbalism",
    MINING    = "Interface\\Icons\\Trade_Mining",
    SKINNING  = "Interface\\Icons\\INV_Misc_Pelt_Wolf_01",
}
local CLASS_FILE = { "WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST", "DEATHKNIGHT", "SHAMAN", "MAGE", "WARLOCK", nil, "DRUID" }
local MATCOL = { [1.0] = "|cffff8040", [0.75] = "|cffffff00", [0.5] = "|cff40c040", [0.25] = "|cff808080" }

-- -------------------- UTILIDADES --------------------
local function FormatTime(secs)
    secs = math.max(0, math.floor(secs or 0))
    local h = math.floor(secs / 3600)
    local m = math.floor((secs % 3600) / 60)
    local s = secs % 60
    if h > 0 then return string.format("%d:%02d:%02d", h, m, s) end
    return string.format("%02d:%02d", m, s)
end

local function MoneyText(copper)
    copper = math.floor(copper or 0)
    local g = math.floor(copper / 10000)
    local s = math.floor((copper % 10000) / 100)
    local b = copper % 100
    local t = {}
    if g > 0 then t[#t + 1] = g .. "|cffffd700g|r" end
    if s > 0 then t[#t + 1] = s .. "|cffc7c7cfs|r" end
    if b > 0 or #t == 0 then t[#t + 1] = b .. "|cffeda55fc|r" end
    return table.concat(t, " ")
end

local function FormatDur(min)
    if min >= 60 and min % 60 == 0 then return (min / 60) .. " h" end
    return min .. " min"
end

local function ShortMoney(c)
    c = math.floor(c or 0)
    if c >= 100000 then return string.format("%dg", math.floor(c / 10000 + 0.5)) end
    if c >= 10000 then return string.format("%.1fg", c / 10000) end
    if c >= 100 then return string.format("%ds", math.floor(c / 100 + 0.5)) end
    return c .. "c"
end

local function FormatCD(secs)
    secs = math.max(0, math.ceil(secs or 0))
    local h = math.floor(secs / 3600)
    local m = math.ceil((secs % 3600) / 60)
    if m == 60 then h = h + 1; m = 0 end
    if h > 0 then return string.format("%dh%02d", h, m) end
    return string.format("%dm", math.max(1, m))
end

local function ClassColor(classId)
    local f = CLASS_FILE[classId or 0]
    local c = f and RAID_CLASS_COLORS and RAID_CLASS_COLORS[f]
    if c then return string.format("|cff%02x%02x%02x", c.r * 255, c.g * 255, c.b * 255) end
    return "|cffffffff"
end

-- Misma formula que el servidor
local function CalcGain(base, mult, bonus, cap, room)
    local g = math.floor(base * mult + 0.5) + math.max(1, math.floor(bonus * mult + 0.5))
    g = math.min(g, cap, room)
    return math.max(0, g)
end

local function MakePanel(parent, x, y, w, h)
    local p = CreateFrame("Frame", nil, parent)
    p:SetSize(w, h)
    p:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    p:SetBackdrop({
        bgFile = WHITE, edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = false, edgeSize = 12, insets = { left = 3, right = 3, top = 3, bottom = 3 }
    })
    p:SetBackdropColor(0.04, 0.04, 0.06, 0.75)
    p:SetBackdropBorderColor(0.45, 0.38, 0.22, 1)
    return p
end

local function Label(parent, x, y, text, font, w, justify)
    local fs = parent:CreateFontString(nil, "OVERLAY", font or "GameFontNormal")
    fs:SetPoint("TOPLEFT", x, y)
    if w then fs:SetWidth(w) end
    fs:SetJustifyH(justify or "LEFT")
    fs:SetText(text or "")
    return fs
end

-- -------------------- VENTANA PRINCIPAL --------------------
UI.main = CreateFrame("Frame", "BotJobsMainWindow", UIParent)
UI.main:SetSize(WIN_W, WIN_H)
UI.main:SetPoint("CENTER", 0, 20)
UI.main:SetMovable(true)
UI.main:EnableMouse(true)
UI.main:SetClampedToScreen(true)
UI.main:RegisterForDrag("LeftButton")
UI.main:SetScript("OnDragStart", UI.main.StartMoving)
UI.main:SetScript("OnDragStop", UI.main.StopMovingOrSizing)
UI.main:Hide()
tinsert(UISpecialFrames, "BotJobsMainWindow")
UI.main:SetBackdrop({
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true, tileSize = 32, edgeSize = 32,
    insets = { left = 11, right = 12, top = 12, bottom = 11 }
})
UI.main:SetBackdropColor(1, 1, 1, 1)

UI.header = UI.main:CreateTexture(nil, "ARTWORK")
UI.header:SetTexture("Interface\\DialogFrame\\UI-DialogBox-Header")
UI.header:SetSize(300, 64)
UI.header:SetPoint("TOP", 0, 14)
UI.titleText = UI.main:CreateFontString(nil, "OVERLAY", "GameFontNormal")
UI.titleText:SetPoint("TOP", UI.header, "TOP", 0, -14)
UI.titleText:SetText("Trabajos de Profesión")
UI.close = CreateFrame("Button", nil, UI.main, "UIPanelCloseButton")
UI.close:SetPoint("TOPRIGHT", -4, -4)
UI.close:SetScale(0.85)

-- ====================== TRABAJOS EN CURSO ======================
UI.jobsPanel = MakePanel(UI.main, 18, -44, PANEL_W, 118)
UI.jobsTitle = Label(UI.jobsPanel, 12, -8, "", "GameFontNormal", PANEL_W - 24)
UI.jobRows = {}
for i = 1, JOB_ROWS do
    local r = CreateFrame("Frame", nil, UI.jobsPanel)
    r:SetSize(PANEL_W - 16, 17)
    r:SetPoint("TOPLEFT", 8, -26 - (i - 1) * 17)
    r.icon = r:CreateTexture(nil, "ARTWORK")
    r.icon:SetSize(15, 15)
    r.icon:SetPoint("LEFT", 2, 0)
    r.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    r.text = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    r.text:SetPoint("LEFT", 22, 0)
    r.text:SetWidth(300)
    r.text:SetJustifyH("LEFT")
    r.time = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    r.time:SetPoint("RIGHT", -4, 0)
    r.time:SetWidth(90)
    r.time:SetJustifyH("RIGHT")
    r:Hide()
    UI.jobRows[i] = r
end
UI.jobsEmpty = Label(UI.jobsPanel, 12, -50, "|cff999999Ningún compañero está trabajando ahora mismo.|r", "GameFontHighlightSmall", PANEL_W - 24, "CENTER")

-- ====================== LISTAS CON PAGINAS ======================
local function MakeList(parent, x, y, w, rows, onPick)
    local L = { rows = {}, items = {}, page = 1, per = rows, selKey = nil, onPick = onPick }
    L.frame = MakePanel(parent, x, y, w, rows * ROW_H + 26)
    for i = 1, rows do
        local b = CreateFrame("Button", nil, L.frame)
        b:SetSize(w - 12, ROW_H - 1)
        b:SetPoint("TOPLEFT", 6, -5 - (i - 1) * ROW_H)
        b:SetHighlightTexture(WHITE)
        local hl = b:GetHighlightTexture()
        if hl then hl:SetVertexColor(1, 1, 1, 0.10) end
        b.sel = b:CreateTexture(nil, "BACKGROUND")
        b.sel:SetAllPoints(b)
        b.sel:SetTexture(WHITE)
        b.sel:SetVertexColor(1, 0.8, 0.2, 0.22)
        b.sel:Hide()
        b.fs = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        b.fs:SetPoint("LEFT", 4, 0)
        b.fs:SetWidth(w - 22)
        b.fs:SetHeight(ROW_H - 2)
        b.fs:SetJustifyH("LEFT")
        b:SetScript("OnClick", function(self)
            local item = self.item
            if not item or item.disabled then return end
            L.selKey = item.key
            L.Refresh()
            if L.onPick then L.onPick(item) end
        end)
        b:Hide()
        L.rows[i] = b
    end
    L.prev = CreateFrame("Button", nil, L.frame, "UIPanelButtonTemplate")
    L.prev:SetSize(24, 18)
    L.prev:SetPoint("BOTTOMLEFT", 6, 4)
    L.prev:SetText("<")
    L.next = CreateFrame("Button", nil, L.frame, "UIPanelButtonTemplate")
    L.next:SetSize(24, 18)
    L.next:SetPoint("BOTTOMRIGHT", -6, 4)
    L.next:SetText(">")
    L.pageText = L.frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    L.pageText:SetPoint("BOTTOM", 0, 7)

    function L.Refresh()
        local n = #L.items
        local pages = math.max(1, math.ceil(n / L.per))
        if L.page > pages then L.page = pages end
        for i = 1, L.per do
            local b = L.rows[i]
            local item = L.items[(L.page - 1) * L.per + i]
            b.item = item
            if item then
                b.fs:SetText(item.text)
                if L.selKey and item.key == L.selKey then b.sel:Show() else b.sel:Hide() end
                b:Show()
            else
                b:Hide()
            end
        end
        L.pageText:SetText(pages > 1 and string.format("|cff999999%d/%d|r", L.page, pages) or "")
        if pages > 1 then L.prev:Show(); L.next:Show() else L.prev:Hide(); L.next:Hide() end
    end
    L.prev:SetScript("OnClick", function() if L.page > 1 then L.page = L.page - 1; L.Refresh() end end)
    L.next:SetScript("OnClick", function() L.page = L.page + 1; L.Refresh() end)

    function L.SetItems(items, selKey)
        L.items = items
        L.selKey = selKey
        -- ir a la pagina de la seleccion
        L.page = 1
        if selKey then
            for i, it in ipairs(items) do
                if it.key == selKey then L.page = math.ceil(i / L.per); break end
            end
        end
        L.Refresh()
    end
    return L
end

-- ====================== SELECCION ======================
UI.botHeader = Label(UI.main, 22, -168, "|cffffd100Compañero y oficio|r", "GameFontNormalSmall", 200)
UI.matHeader = Label(UI.main, 242, -168, "|cffffd100Material|r", "GameFontNormalSmall", 200)

local function CurrentCombo()
    local b = UI.board
    if not b or not UI.selKey or not b.bots then return nil end
    for _, bot in ipairs(b.bots) do
        for _, pr in ipairs(bot.profs or {}) do
            if bot.guid .. ":" .. pr.key == UI.selKey then return bot, pr end
        end
    end
    return nil
end

local function CurrentMat()
    local _, pr = CurrentCombo()
    if not pr or not UI.selMat then return nil end
    for _, m in ipairs(pr.mats) do
        if m.id == UI.selMat then return m end
    end
    return nil
end

local UpdateSummary   -- forward

local function BuildMatItems()
    local bot, pr = CurrentCombo()
    local items = {}
    if pr then
        for _, m in ipairs(pr.mats) do
            items[#items + 1] = {
                key = m.id,
                text = (MATCOL[m.mult] or "|cffffffff") .. m.name .. "|r |cff888888[" .. m.req .. "]|r",
            }
        end
    end
    return items
end

UI.matList = MakeList(UI.main, 238, -184, 214, 6, function(item)
    UI.selMat = item.key
    UpdateSummary()
end)

UI.botList = MakeList(UI.main, 18, -184, 214, 6, function(item)
    UI.selKey = item.key
    UI.selMat = nil
    local _, pr = CurrentCombo()
    if pr and #pr.mats > 0 then UI.selMat = pr.mats[#pr.mats].id end   -- por defecto, el mejor material
    UI.matList.SetItems(BuildMatItems(), UI.selMat)
    UpdateSummary()
end)

local function BuildBotItems()
    local items = {}
    local b = UI.board
    for _, bot in ipairs(b and b.bots or {}) do
        for _, pr in ipairs(bot.profs or {}) do
            local it = { key = bot.guid .. ":" .. pr.key }
            if bot.busy then
                it.disabled = true
                it.text = string.format("|cff777777%s - %s (%s)|r", bot.name, pr.name,
                    bot.busy == "job" and "en trabajo" or "de misión")
            elseif (bot.cd or 0) > 0 then
                it.disabled = true
                it.text = string.format("|cff777777%s - %s (desc. %s)|r", bot.name, pr.name, FormatCD(bot.cd))
            else
                local tag = ""
                if b and b.cdOn and (bot.cnt or 0) > 0 then
                    tag = string.format(" |cff888888[%d/%d]|r", bot.cnt, b.cdJobs or 3)
                end
                -- habilidad en naranja si esta al tope de su rango
                it.text = string.format("%s%s|r %s %s%d/%d|r%s",
                    ClassColor(bot.class), bot.name, pr.name,
                    (pr.val >= pr.max) and "|cffff8800" or "|cffffffff", pr.val, pr.max, tag)
            end
            items[#items + 1] = it
        end
    end
    return items
end

-- Duraciones
UI.durLabel = Label(UI.main, 22, -334, "|cffffd100Duración|r", "GameFontNormalSmall", 200)
UI.durBtns = {}
for i = 1, 4 do
    local b = CreateFrame("Button", nil, UI.main, "UIPanelButtonTemplate")
    b:SetSize(104, 22)
    b:SetPoint("TOPLEFT", UI.main, "TOPLEFT", 20 + (i - 1) * 108, -348)
    b:SetScript("OnClick", function()
        UI.selDur = i
        UpdateSummary()
    end)
    b:Hide()
    UI.durBtns[i] = b
end

-- Resumen
UI.sumPanel = MakePanel(UI.main, 18, -378, PANEL_W, 110)
UI.sum = UI.sumPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
UI.sum:SetPoint("TOPLEFT", 12, -9)
UI.sum:SetWidth(PANEL_W - 24)
UI.sum:SetHeight(94)
UI.sum:SetJustifyH("LEFT")
UI.sum:SetJustifyV("TOP")

-- Aviso: lejos del NPC
UI.farPanel = MakePanel(UI.main, 18, -168, PANEL_W, 294)
UI.farText = UI.farPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
UI.farText:SetPoint("CENTER", 0, 0)
UI.farText:SetWidth(PANEL_W - 60)
UI.farText:SetJustifyH("CENTER")
UI.farText:SetText("|cffffd100Estás lejos del pescador Kalu'ak|r\n\n" ..
    "|cffbbbbbbAcércate a él y habla con él para contratar un trabajo de pesca, herboristería, minería o desuello.|r\n\n" ..
    "|cff888888/bj abre este panel.|r")

-- Botones
UI.hireBtn = CreateFrame("Button", nil, UI.main, "UIPanelButtonTemplate")
UI.hireBtn:SetSize(160, 26)
UI.hireBtn:SetPoint("BOTTOMRIGHT", -28, 22)
UI.hireBtn:SetText("Enviar a trabajar")
UI.hireBtn:Disable()
UI.hireBtn:SetScript("OnClick", function()
    local bot, pr = CurrentCombo()
    if bot and pr and UI.selMat and UI.selDur then
        UI.hireBtn:Disable()
        if UI.SaveLast then UI.SaveLast(bot, pr, UI.selMat, UI.selDur) end
        AIO.Handle("BotJobs", "startJob", bot.guid, pr.key, UI.selMat, UI.selDur)
    end
end)

-- ====================== DIARIO ======================
local DIARY_MAX, DIARY_W, DIARY_H, DIARY_ROW_H = 200, 380, 520, 66

local function DiaryDB()
    if type(BotJobsDiary) ~= "table" then BotJobsDiary = {} end
    if type(BotJobsDiary.entries) ~= "table" then BotJobsDiary.entries = {} end
    return BotJobsDiary
end

UI.diary = CreateFrame("Frame", "BotJobsDiaryWindow", UIParent)
UI.diary:SetSize(DIARY_W, DIARY_H)
UI.diary:SetPoint("TOPLEFT", UI.main, "TOPRIGHT", -2, 0)
UI.diary:SetMovable(true)
UI.diary:EnableMouse(true)
UI.diary:SetClampedToScreen(true)
UI.diary:RegisterForDrag("LeftButton")
UI.diary:SetScript("OnDragStart", UI.diary.StartMoving)
UI.diary:SetScript("OnDragStop", UI.diary.StopMovingOrSizing)
UI.diary:Hide()
tinsert(UISpecialFrames, "BotJobsDiaryWindow")
UI.diary:SetBackdrop({
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true, tileSize = 32, edgeSize = 32,
    insets = { left = 11, right = 12, top = 12, bottom = 11 }
})
UI.diary:SetBackdropColor(1, 1, 1, 1)
UI.diaryHeader = UI.diary:CreateTexture(nil, "ARTWORK")
UI.diaryHeader:SetTexture("Interface\\DialogFrame\\UI-DialogBox-Header")
UI.diaryHeader:SetSize(240, 64)
UI.diaryHeader:SetPoint("TOP", 0, 14)
UI.diaryTitle = UI.diary:CreateFontString(nil, "OVERLAY", "GameFontNormal")
UI.diaryTitle:SetPoint("TOP", UI.diaryHeader, "TOP", 0, -14)
UI.diaryTitle:SetText("Diario de Trabajos")
UI.diaryClose = CreateFrame("Button", nil, UI.diary, "UIPanelCloseButton")
UI.diaryClose:SetPoint("TOPRIGHT", -4, -4)
UI.diaryClose:SetScale(0.85)

UI.diarySumPanel = MakePanel(UI.diary, 18, -34, DIARY_W - 36, 56)
UI.diarySum1 = Label(UI.diarySumPanel, 12, -9, "", "GameFontHighlight", DIARY_W - 60)
UI.diarySum2 = Label(UI.diarySumPanel, 12, -30, "", "GameFontHighlightSmall", DIARY_W - 60)

UI.diaryScroll = CreateFrame("ScrollFrame", "BotJobsDiaryScroll", UI.diary, "UIPanelScrollFrameTemplate")
UI.diaryScroll:SetPoint("TOPLEFT", UI.diary, "TOPLEFT", 20, -98)
UI.diaryScroll:SetPoint("BOTTOMRIGHT", UI.diary, "BOTTOMRIGHT", -38, 60)
UI.diaryChild = CreateFrame("Frame", nil, UI.diaryScroll)
UI.diaryChild:SetSize(DIARY_W - 62, 1)
UI.diaryScroll:SetScrollChild(UI.diaryChild)

UI.diaryEmpty = UI.diary:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
UI.diaryEmpty:SetPoint("CENTER", UI.diary, "CENTER", 0, 10)
UI.diaryEmpty:SetWidth(DIARY_W - 80)
UI.diaryEmpty:SetJustifyH("CENTER")
UI.diaryEmpty:SetText("|cff999999Aún no hay trabajos registrados.\nAquí aparecerán los que terminen.|r")
UI.diaryEmpty:Hide()

UI.diaryRows = {}
local function GetDiaryRow(i)
    local r = UI.diaryRows[i]
    if r then return r end
    r = CreateFrame("Frame", nil, UI.diaryChild)
    r:SetSize(DIARY_W - 62, DIARY_ROW_H - 4)
    r:SetPoint("TOPLEFT", 0, -(i - 1) * DIARY_ROW_H)
    r:SetBackdrop({
        bgFile = WHITE, edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = false, edgeSize = 10, insets = { left = 3, right = 3, top = 3, bottom = 3 }
    })
    r:SetBackdropColor(0.04, 0.04, 0.06, 0.75)
    r:SetBackdropBorderColor(0.45, 0.38, 0.22, 1)
    r.l1 = Label(r, 9, -7, "", "GameFontNormal", 190)
    r.date = Label(r, 0, -8, "", "GameFontHighlightSmall", 90, "RIGHT")
    r.date:ClearAllPoints()
    r.date:SetPoint("TOPRIGHT", -9, -8)
    r.l2 = Label(r, 9, -23, "", "GameFontHighlightSmall", DIARY_W - 84)
    r.l3 = Label(r, 9, -36, "", "GameFontHighlightSmall", DIARY_W - 84)
    r.l4 = Label(r, 9, -48, "", "GameFontHighlightSmall", DIARY_W - 84)
    UI.diaryRows[i] = r
    return r
end

local function RefreshDiary()
    local entries = DiaryDB().entries
    local n = #entries
    local spent, gained = 0, 0
    for i = 1, n do
        local e = entries[i]
        local r = GetDiaryRow(i)
        spent = spent + (e.price or 0)
        gained = gained + (e.gain or 0)
        r.l1:SetText("|cffffd100" .. (e.profName or e.prof or "?") .. "|r |cffffffff— " .. (e.bot or "?") .. "|r")
        r.date:SetText("|cffaaaaaa" .. (e.t and date("%d/%m %H:%M", e.t) or "") .. "|r")
        r.l2:SetText(string.format("|cffaaaaaaBotín:|r |cffffffff%s x%d|r%s%s  |cff888888·|r  |cffffffff%s|r",
            e.mat or "?", e.qty or 0,
            e.double and " |cff00ff00(x2)|r" or "",
            (e.extra and e.extra > 0) and string.format(" |cff888888+%d extra|r", e.extra) or "",
            FormatDur(e.minutes or 0)))
        if (e.gain or 0) > 0 then
            r.l3:SetText(string.format("|cffaaaaaaHabilidad:|r |cff00ff00+%d|r |cff888888(%d → %d/%d)|r",
                e.gain, e.from or 0, e.to or 0, e.max or 0))
        elseif (e.max or 0) > 0 and (e.from or 0) >= (e.max or 0) then
            r.l3:SetText("|cffaaaaaaHabilidad:|r |cffff8800al tope de su rango|r")
        else
            r.l3:SetText("|cffaaaaaaHabilidad:|r |cff888888sin cambios|r")
        end
        r.l4:SetText("|cffaaaaaaCoste:|r " .. MoneyText(e.price) ..
            ((e.rare and e.rare ~= "") and ("  |cffa335ee★ " .. e.rare .. "|r") or ""))
        r:Show()
    end
    for i = n + 1, #UI.diaryRows do UI.diaryRows[i]:Hide() end
    UI.diaryChild:SetHeight(math.max(1, n * DIARY_ROW_H))
    if n == 0 then UI.diaryEmpty:Show() else UI.diaryEmpty:Hide() end
    UI.diarySum1:SetText(string.format("|cffffffff%d|r trabajos   |cff00ff00+%d habilidad|r", n, gained))
    UI.diarySum2:SetText("|cffaaaaaaOro gastado:|r " .. MoneyText(spent))
end

local function ToggleDiary()
    if UI.diary:IsShown() then UI.diary:Hide() else RefreshDiary(); UI.diary:Show() end
end

StaticPopupDialogs["BOTJOBS_CLEAR_DIARY"] = {
    text = "¿Borrar todo el diario de trabajos?\n\nEsta acción no se puede deshacer.",
    button1 = YES, button2 = NO,
    OnAccept = function() DiaryDB().entries = {}; RefreshDiary() end,
    timeout = 0, whileDead = true, hideOnEscape = true,
}
UI.diaryClear = CreateFrame("Button", nil, UI.diary, "UIPanelButtonTemplate")
UI.diaryClear:SetSize(120, 24)
UI.diaryClear:SetPoint("BOTTOM", 0, 24)
UI.diaryClear:SetText("Borrar diario")
UI.diaryClear:SetScript("OnClick", function() StaticPopup_Show("BOTJOBS_CLEAR_DIARY") end)

UI.diaryBtn = CreateFrame("Button", nil, UI.main, "UIPanelButtonTemplate")
UI.diaryBtn:SetSize(110, 26)
UI.diaryBtn:SetPoint("BOTTOMLEFT", 28, 22)
UI.diaryBtn:SetText("Diario")
UI.diaryBtn:SetScript("OnClick", ToggleDiary)

-- ====================== REPETIR ULTIMO TRABAJO ======================
function UI.SaveLast(bot, pr, matId, durIdx)
    local d = UI.board and UI.board.durs and UI.board.durs[durIdx]
    DiaryDB().last = { bot = bot.guid, botName = bot.name, prof = pr.key, profName = pr.name, mat = matId, min = d and d.min }
end

-- Devuelve bot, pr, mat, durIdx del ultimo trabajo si se puede repetir ahora mismo
local function FindLast()
    local b, L = UI.board, DiaryDB().last
    if not (b and b.near and b.bots and b.durs and L and L.min) then return nil end
    for _, bot in ipairs(b.bots) do
        if bot.guid == L.bot and not bot.busy and (bot.cd or 0) <= 0 then
            for _, pr in ipairs(bot.profs or {}) do
                if pr.key == L.prof then
                    for _, m in ipairs(pr.mats or {}) do
                        if m.id == L.mat and m.p then
                            for i, d in ipairs(b.durs) do
                                if d.min == L.min then return bot, pr, m, i end
                            end
                        end
                    end
                end
            end
        end
    end
    return nil
end

UI.repeatBtn = CreateFrame("Button", nil, UI.main, "UIPanelButtonTemplate")
UI.repeatBtn:SetSize(120, 26)
UI.repeatBtn:SetPoint("BOTTOMLEFT", 146, 22)
UI.repeatBtn:SetText("Repetir último")
UI.repeatBtn:Hide()
UI.repeatBtn:SetScript("OnClick", function()
    local bot, pr, m, i = FindLast()
    local b = UI.board
    if bot and b and (b.money or 0) >= m.p[i] and (b.used or 0) < (b.maxJobs or 1) then
        UI.repeatBtn:Disable()
        UI.hireBtn:Disable()
        AIO.Handle("BotJobs", "startJob", bot.guid, pr.key, m.id, i)
    end
end)
UI.repeatBtn:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    local bot, pr, m, i = FindLast()
    if bot then
        local d = UI.board.durs[i]
        GameTooltip:AddLine("Repetir último trabajo", 1, 0.85, 0)
        GameTooltip:AddLine(string.format("%s - %s", bot.name, pr.name), 1, 1, 1)
        GameTooltip:AddLine(string.format("%s, %s", m.name, FormatDur(d.min)), 0.8, 0.8, 0.8)
        GameTooltip:AddLine("Coste: " .. MoneyText(m.p[i]), 1, 1, 1)
    else
        GameTooltip:AddLine("Repetir último trabajo", 1, 0.85, 0)
        GameTooltip:AddLine(DiaryDB().last and "Ahora no se puede repetir (compañero ocupado o sin material)." or "Aún no has hecho ningún trabajo.", 0.7, 0.7, 0.7, true)
    end
    GameTooltip:Show()
end)
UI.repeatBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)

local function RefreshRepeat()
    local b = UI.board
    if not (b and b.near) then UI.repeatBtn:Hide(); return end
    UI.repeatBtn:Show()
    local bot, _, m, i = FindLast()
    if bot and (b.money or 0) >= m.p[i] and (b.used or 0) < (b.maxJobs or 1) then
        UI.repeatBtn:Enable()
    else
        UI.repeatBtn:Disable()
    end
end

-- ====================== LOGICA ======================
function UpdateSummary()
    local b = UI.board
    local bot, pr = CurrentCombo()
    local mat = CurrentMat()
    if mat and not (mat.p and mat.q) then mat = nil end

    -- botones de duracion (con el precio del material elegido)
    for i, btn in ipairs(UI.durBtns) do
        local d = b and b.durs and b.durs[i]
        if d and pr then
            local label = FormatDur(d.min)
            if mat then label = label .. " - " .. ShortMoney(mat.p[i]) end
            btn:SetText(label)
            btn:Show()
            if UI.selDur == i then btn:LockHighlight() else btn:UnlockHighlight() end
        else
            btn:Hide()
        end
    end

    if not (bot and pr and mat and b and b.durs and b.durs[UI.selDur]) then
        UI.sum:SetText("|cff999999Elige un compañero, un material y una duración.|r")
        UI.hireBtn:Disable()
        return
    end

    local d = b.durs[UI.selDur]
    local price = mat.p[UI.selDur]
    local qty = mat.q[UI.selDur]
    local extra = math.floor(qty * (b.bycatch or 0) + 0.5)
    local room = pr.max - pr.val
    local lo = CalcGain(pr.gain[UI.selDur], mat.mult, b.bonusMin or 1, d.cap, room)
    local hi = CalcGain(pr.gain[UI.selDur], mat.mult, b.bonusMax or 5, d.cap, room)

    local skillLine
    if room <= 0 then
        skillLine = "|cffff8800Al tope (necesita entrenar): solo botín.|r"
    elseif hi == lo then
        skillLine = string.format("|cff00ff00+%d|r habilidad", lo)
    else
        skillLine = string.format("|cff00ff00+%d a +%d|r habilidad", lo, hi)
    end
    local enough = (b.money or 0) >= price
    UI.sum:SetText(string.format(
        "%s%s|r — %s |cffffffff%d|r|cff888888/%d|r\n" ..
        "|cffaaaaaaMaterial:|r |cffffffff%s|r  |cffaaaaaa~|r|cffffffff%d|r unidades |cff888888(por correo)|r\n" ..
        "|cffaaaaaaExtras:|r |cffffffff~%d|r de otros materiales |cff888888· %d%% botín doble · raros posibles|r\n" ..
        "|cffaaaaaaDuración:|r |cffffffff%s|r    |cffaaaaaaTrabajo:|r %s\n" ..
        "|cffaaaaaaCoste:|r %s%s|r  |cff888888(tienes %s)|r",
        ClassColor(bot.class), bot.name, pr.name, pr.val, pr.max,
        mat.name, qty, extra, math.floor((b.dbl or 0) * 100 + 0.5), FormatDur(d.min), skillLine,
        enough and "|cffffffff" or "|cffff4444", MoneyText(price), MoneyText(b.money or 0)))

    local slots = (b.used or 0) < (b.maxJobs or 1)
    local tail = ""
    if b.cdOn and (bot.cnt or 0) + 1 >= (b.cdJobs or 3) then
        local secs = ((bot.cmin or 0) + d.min) * 60 * (b.cdMult or 2)
        tail = tail .. string.format("\n|cffff8800Completa su tanda: descansará ~%s.|r", FormatCD(secs))
    end
    if not slots then
        tail = tail .. "\n|cffff4444Máximo de trabajos simultáneos alcanzado.|r"
    end
    if tail ~= "" then UI.sum:SetText(UI.sum:GetText() .. tail) end
    if enough and slots and b.near and not bot.busy and (bot.cd or 0) <= 0 then UI.hireBtn:Enable() else UI.hireBtn:Disable() end
end

local function RefreshBoard()
    local b = UI.board
    if not b then return end
    RefreshRepeat()

    -- Trabajos en curso
    UI.jobsTitle:SetText(string.format("|cffffd100Trabajos en curso|r  |cffffffff%d/%d|r", b.used or 0, b.maxJobs or 0))
    local jobs = b.jobs or {}
    for i = 1, JOB_ROWS do
        local r, j = UI.jobRows[i], jobs[i]
        if j then
            r.icon:SetTexture(PROF_ICON[j.prof] or "Interface\\Icons\\INV_Misc_QuestionMark")
            r.text:SetText(string.format("|cffffffff%s|r |cff888888·|r %s |cff888888·|r |cffaaaaaa%s|r",
                j.bot, j.profName, j.mat))
            r:Show()
        else
            r:Hide()
        end
    end
    if #jobs == 0 then UI.jobsEmpty:Show() else UI.jobsEmpty:Hide() end

    -- Seleccion (solo cerca del NPC)
    local near = b.near
    local sel = { UI.botList.frame, UI.matList.frame, UI.botHeader, UI.matHeader, UI.durLabel, UI.sumPanel, UI.hireBtn }
    for _, f in ipairs(sel) do if near then f:Show() else f:Hide() end end
    if near then UI.farPanel:Hide() else
        UI.farPanel:Show()
        for _, btn in ipairs(UI.durBtns) do btn:Hide() end
        return
    end

    local items = BuildBotItems()
    -- conservar la seleccion si sigue existiendo
    local keep = false
    for _, it in ipairs(items) do if it.key == UI.selKey and not it.disabled then keep = true end end
    if not keep then
        UI.selKey, UI.selMat = nil, nil
    end
    UI.botList.SetItems(items, UI.selKey)

    local _, pr = CurrentCombo()
    if pr then
        local ok = false
        for _, m in ipairs(pr.mats) do if m.id == UI.selMat then ok = true end end
        if not ok then UI.selMat = pr.mats[#pr.mats].id end
    else
        UI.selMat = nil
    end
    UI.matList.SetItems(BuildMatItems(), UI.selMat)
    if not (b.durs and b.durs[UI.selDur]) then UI.selDur = 1 end
    UpdateSummary()
end

-- Temporizadores (los jobs llegan con "remaining"; aqui se descuenta en local)
UI.main:SetScript("OnUpdate", function(self, elapsed)
    if not self:IsShown() then return end
    UI._acc = (UI._acc or 0) + elapsed
    if UI._acc < 0.25 then return end
    local dt = UI._acc
    UI._acc = 0

    local b = UI.board
    if b and b.jobs then
        local since = GetTime() - (UI._boardTime or GetTime())
        local anyDone = false
        for i = 1, JOB_ROWS do
            local j = b.jobs[i]
            if j then
                local rem = (j.remaining or 0) - since
                if rem > 0 then
                    UI.jobRows[i].time:SetText("|cffffcc00" .. FormatTime(rem) .. "|r")
                else
                    UI.jobRows[i].time:SetText("|cff00ff00Volviendo...|r")
                    anyDone = true
                end
            end
        end
        UI._poll = (UI._poll or 0) + dt
        if UI._poll >= (anyDone and 4 or 6) then
            UI._poll = 0
            AIO.Handle("BotJobs", "requestBoard")
        end
    end
end)

local function ToggleMain()
    if UI.main:IsShown() then
        UI.main:Hide()
    else
        UI.main:Show()
        AIO.Handle("BotJobs", "requestBoard")
    end
end

-- -------------------- MINIMAPA --------------------
UI.minimap = CreateFrame("Button", "BotJobsMinimapButton", Minimap)
UI.minimap:SetSize(32, 32)
UI.minimap:SetFrameStrata("MEDIUM")
UI.minimap:SetFrameLevel(8)
UI.minimap:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
UI.minimap:RegisterForClicks("AnyUp")
UI.minimap:RegisterForDrag("LeftButton")
UI.minimap:SetMovable(true)
UI.minimapIcon = UI.minimap:CreateTexture(nil, "BACKGROUND")
UI.minimapIcon:SetSize(20, 20)
UI.minimapIcon:SetPoint("CENTER", 0, 1)
UI.minimapIcon:SetTexture("Interface\\Icons\\Trade_Fishing")
UI.minimapGlow = UI.minimap:CreateTexture(nil, "OVERLAY")
UI.minimapGlow:SetSize(28, 28)
UI.minimapGlow:SetPoint("CENTER", 0, 1)
UI.minimapGlow:SetTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
UI.minimapGlow:SetBlendMode("ADD")
UI.minimapGlow:Hide()

UI.minimapBorder = UI.minimap:CreateTexture(nil, "OVERLAY")
UI.minimapBorder:SetSize(52, 52)
UI.minimapBorder:SetPoint("TOPLEFT", 0, 0)
UI.minimapBorder:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")

local minimapAngle = 250
local function UpdateMinimapPos()
    local a = math.rad(minimapAngle)
    UI.minimap:ClearAllPoints()
    UI.minimap:SetPoint("CENTER", Minimap, "CENTER", math.cos(a) * 80, math.sin(a) * 80)
end
UpdateMinimapPos()
UI.minimap:SetScript("OnDragStart", function() UI._dragging = true end)
UI.minimap:SetScript("OnDragStop", function() UI._dragging = false end)
UI.minimap:SetScript("OnClick", function(_, button) if button == "LeftButton" then ToggleMain() end end)
UI.minimap:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:AddLine("BotJobs", 1, 0.85, 0)
    GameTooltip:AddLine("Click: abrir panel", 1, 1, 1)
    if UI._readyAlert then GameTooltip:AddLine("¡Un compañero ha vuelto de su trabajo!", 0, 1, 0) end
    local n = UI.board and UI.board.used or 0
    if n > 0 then GameTooltip:AddLine(n .. " trabajo(s) en curso", 1, 0.8, 0.2) end
    GameTooltip:Show()
end)
UI.minimap:SetScript("OnLeave", function() GameTooltip:Hide() end)
UI._blink = 0
UI.minimap:SetScript("OnUpdate", function(self, elapsed)
    if UI._dragging then
        local mx, my = Minimap:GetCenter()
        local cx, cy = GetCursorPosition()
        local scale = Minimap:GetEffectiveScale()
        cx, cy = cx / scale, cy / scale
        minimapAngle = math.deg(math.atan2(cy - my, cx - mx))
        UpdateMinimapPos()
    end
    if not UI._readyAlert then return end
    UI._blink = UI._blink + elapsed
    local pulse = (math.sin(UI._blink * 6) + 1) * 0.5
    UI.minimapIcon:SetVertexColor(0.3, 1, 0.3)
    UI.minimapGlow:Show()
    UI.minimapGlow:SetAlpha(0.25 + pulse * 0.75)
end)

local function SetAlert(on)
    UI._readyAlert = on and true or false
    if not on then
        UI.minimapIcon:SetVertexColor(1, 1, 1)
        UI.minimapGlow:Hide()
    end
end
UI.main:HookScript("OnShow", function() SetAlert(false) end)

-- -------------------- HANDLERS AIO --------------------
function Handlers.BoardData(player, payload)
    if type(payload) ~= "table" then return end
    UI.board = payload
    UI._boardTime = GetTime()
    RefreshBoard()
    if payload.open then
        UI.main:Show()
    end
end

function Handlers.DiaryEntry(player, entry)
    if type(entry) ~= "table" then return end
    local entries = DiaryDB().entries
    table.insert(entries, 1, entry)
    while #entries > DIARY_MAX do table.remove(entries) end
    if UI.diary:IsShown() then RefreshDiary() end
    if not UI.main:IsShown() then
        SetAlert(true)
        pcall(PlaySound, "QUESTCOMPLETED")
    end
end

SLASH_BOTJOBS1 = "/bj"
SLASH_BOTJOBS2 = "/oficios"
SlashCmdList["BOTJOBS"] = function(msg)
    msg = msg and msg:lower() or ""
    if msg == "diario" or msg == "diary" then ToggleDiary() return end
    ToggleMain()
end

local boot = CreateFrame("Frame")
boot:RegisterEvent("ADDON_LOADED")
boot:SetScript("OnEvent", function(self, event, arg1)
    if arg1 == "BotJobs" then DiaryDB() end
end)

DEFAULT_CHAT_FRAME:AddMessage("|cff00ccff[BotJobs]|r v0.4 |cffffffff/bj|r  |cffffffff/bj diario|r")
