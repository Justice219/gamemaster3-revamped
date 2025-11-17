gm3 = gm3
lyx = lyx

lyx:HookOnce("InitPostEntity", function()
    CamAngle = Angle()
    CamOriginalAngle = Angle(LocalPlayer():EyeAngles())
    CamPos = Vector(LocalPlayer():EyePos())
    CamOriginalPos = Vector(LocalPlayer():EyePos())
    CamSpeed = 2
    CamFOV = 90
    CamLock = false
    CamSensitivity = .02
    EnabledCam = false
    EnabledCamConfirm = false
end)

-- client ConVars
local gm3ZeusCam = {}
local CVCamFOV = CreateClientConVar("gm3Cam_fov", 90, true, false, "FOV of Simple FreeCam", 25, 179)
local CVCamSpeed = CreateClientConVar("gm3Cam_speed", 2, true, false, "Movement speed of Simple FreeCam", 0.1, 10)
local CVCamLock = CreateClientConVar("gm3Cam_lock", 0, true, false, "Lock Simple FreeCam", 0, 1)
local CVCamSens = CreateClientConVar("gm3Cam_sens", 0.02, true, false, "Mouse sensitivity of Simple FreeCam", 0.001, 1)
local CVCamArtilleryDelay = CreateClientConVar("gm3Cam_artilleryDelay", 6, true, false, "Seconds before artillery impacts", 1, 120)
local gm3_selectedEntities = {}
local gm3_selectionCount = 0
local gm3_moveOrders = {}
local gm3_spawnMode = false
local gm3_spawnToolbar
local gm3_spawnNextClick = 0
local gm3_spawnConfig = {
    class = "npc_combine_s",
    weapon = "weapon_smg1",
    count = 1,
    relationship = "hostile"
}
local gm3_spawnPresets = gm3_spawnPresets or {}
local gm3_formations = {}
local gm3_formationSpacing = 80
local gm3_selectionBox = {
    active = false,
    dragging = false,
    startX = 0,
    startY = 0,
    currentX = 0,
    currentY = 0
}
local gm3_hoveredEntity = nil
local gm3_contextMenu = nil
local gm3_cursorMode = false
local gm3_rightMouseHeld = false
local gm3CamPanel = nil
local gm3_zeusAllowed = false
local gm3_selectionGroups = gm3_selectionGroups or {}
local gm3_cameraBookmarks = gm3_cameraBookmarks or {}
local gm3_waypointMode = false
local gm3_waypoints = gm3_waypoints or {}
local gm3_waypointLoop = true
local gm3_nextWaypointClick = 0
local gm3_waypointPreviewPos = nil
local gm3_waypointClearHeld = false
local gm3_reconPings = gm3_reconPings or {}
local gm3_signalMarkers = gm3_signalMarkers or {}
local gm3_lastReconRequest = 0
local gm3_routeVisuals = gm3_routeVisuals or {}
local vector_origin = vector_origin or Vector(0, 0, 0)
local gm3_artilleryPreviews = gm3_artilleryPreviews or {}
local gm3_lastContextTrace = nil
local gm3_followTarget = nil
local gm3_followOffset = Vector(0, 0, 0)
local gm3_followYaw = nil
local gm3_routeLineOffsets = {
    Vector(0, 0, 2),
    Vector(0, 0, 3.5),
    Vector(0, 0, 5)
}
local gm3_routeBoxMins = Vector(-2, -2, -1)
local gm3_routeBoxMaxs = Vector(2, 2, 1)
local function gm3_NormalizeArtilleryDelay(value)
    value = tonumber(value) or CVCamArtilleryDelay:GetFloat() or 6
    return math.Clamp(math.floor(value + 0.5), 1, 120)
end

local function gm3_UpdateArtilleryDelay(value, skipCommand)
    local delay = gm3_NormalizeArtilleryDelay(value)
    if not skipCommand then
        RunConsoleCommand("gm3Cam_artilleryDelay", tostring(delay))
    end
    gm3ZeusCam._artilleryDelay = delay

    local slider = gm3ZeusCam.FireSupportSlider
    if IsValid(slider) and slider:GetValue() ~= delay then
        slider._suppress = true
        slider:SetValue(delay)
        slider._suppress = false
    end

    local spawnSlider = gm3ZeusCam.SpawnArtillerySlider
    if IsValid(spawnSlider) and spawnSlider:GetValue() ~= delay then
        spawnSlider._suppress = true
        spawnSlider:SetValue(delay)
        spawnSlider._suppress = false
    end
end

cvars.AddChangeCallback("gm3Cam_artilleryDelay", function(_, _, new)
    gm3_UpdateArtilleryDelay(new, true)
end, "gm3ZeusCam_artillerySync")

gm3_UpdateArtilleryDelay(CVCamArtilleryDelay:GetFloat(), true)

local gm3_fireSupportProfiles = {
    precision = {
        label = "Precision Strike",
        radius = 160,
        shells = 1,
        delay = 0.35,
        warning = 5
    },
    barrage = {
        label = "Heavy Barrage",
        radius = 340,
        shells = 5,
        delay = 0.7,
        warning = 8
    },
    carpet = {
        label = "Carpet Bomb",
        radius = 520,
        shells = 8,
        delay = 1.1,
        warning = 10
    },
    smoke = {
        label = "Smoke Screen",
        radius = 260,
        shells = 4,
        delay = 0.5,
        smoke = true,
        warning = 6
    },
    incendiary = {
        label = "Incendiary Strike",
        radius = 260,
        shells = 4,
        delay = 0.5,
        incendiary = true,
        warning = 7
    },
    emp = {
        label = "EMP Blast",
        radius = 220,
        shells = 2,
        delay = 0.8,
        emp = true,
        warning = 6
    }
}

local gm3_reconColors = {
    player = Color(90, 200, 255),
    npc = Color(255, 180, 80),
    prop = Color(200, 200, 200),
    unknown = Color(180, 180, 255),
    friendly = Color(140, 255, 160)
}

local gm3_routeColors = {
    move = Color(90, 200, 255),
    formation = Color(255, 180, 80),
    patrol = Color(90, 220, 150),
    default = Color(255, 255, 255)
}

local gm3_logisticsOptions = {
    {key = "ammo", label = "Ammo Drop", icon = "icon16/box.png"},
    {key = "medical", label = "Medical Drop", icon = "icon16/medkit.png"},
    {key = "tech", label = "Technology Drop", icon = "icon16/wrench.png"},
    {key = "shield", label = "Shield Drop", icon = "icon16/shield.png"},
    {key = "turret", label = "Turret Drop", icon = "icon16/lightning.png"}
}

local gm3_screenMessageColors = {
    {name = "White", color = Color(255, 255, 255)},
    {name = "Amber", color = Color(255, 200, 100)},
    {name = "Red", color = Color(255, 80, 80)},
    {name = "Blue", color = Color(90, 160, 255)},
    {name = "Green", color = Color(120, 255, 120)}
}

local gm3_signalPalette = {
    {name = "Gold", color = Color(255, 200, 80)},
    {name = "Scarlet", color = Color(255, 90, 90)},
    {name = "Cyan", color = Color(90, 200, 255)},
    {name = "Emerald", color = Color(120, 255, 150)},
    {name = "Violet", color = Color(190, 140, 255)}
}

local gm3_artilleryColors = {
    precision = Color(255, 255, 200),
    barrage = Color(255, 170, 50),
    carpet = Color(255, 120, 120),
    smoke = Color(160, 220, 255),
    incendiary = Color(255, 120, 60),
    emp = Color(160, 200, 255),
    default = Color(255, 200, 140)
}

local function gm3_GetEffectiveTrace(tr)
    if tr and tr.Hit then return tr end
    return gm3ZeusCam:GetCursorTrace()
end

local function DrawThickBeam(startPos, endPos, _, color)
    if not startPos or not endPos then return end
    color = color or color_white
    for _, offset in ipairs(gm3_routeLineOffsets) do
        render.DrawLine(startPos + offset, endPos + offset, color)
    end

    local mid = LerpVector(0.5, startPos, endPos)
    local dir = endPos - startPos
    if dir:IsZero() then return end
    local ang = dir:Angle()
    render.DrawWireframeBox(mid, Angle(0, ang.y, 0), gm3_routeBoxMins, gm3_routeBoxMaxs, Color(color.r, color.g, color.b, math.floor((color.a or 255) * 0.6)))
end

local function ClearRouteVisuals()
    table.Empty(gm3_routeVisuals)
end

function gm3ZeusCam:SaveCameraBookmark(slot)
    if not slot then return end
    gm3_cameraBookmarks[slot] = {
        pos = Vector(CamPos),
        ang = Angle(CamAngle)
    }
    notification.AddLegacy("Saved camera bookmark #" .. slot, NOTIFY_GENERIC, 2)
end

function gm3ZeusCam:LoadCameraBookmark(slot)
    local data = gm3_cameraBookmarks[slot]
    if not data then
        notification.AddLegacy("Bookmark #" .. slot .. " is empty.", NOTIFY_HINT, 2)
        return
    end
    CamPos = Vector(data.pos)
    CamAngle = Angle(data.ang)
    notification.AddLegacy("Loaded camera bookmark #" .. slot, NOTIFY_GENERIC, 2)
end

surface.CreateFont("GM3_Cam_Subtitle", {
    font = "Roboto",
    size = 20,
    weight = 500,
    antialias = true,
    shadow = false
})
surface.CreateFont("GM3_Cam_Title", {
    font = "Roboto",
    size = 30,
    weight = 500,
    antialias = true,
    shadow = false,
    bold = true,
})

gm3ZeusCam.hooks = gm3ZeusCam.hooks or {}

function gm3ZeusCam:AddHook(name, func)
    self.hooks = self.hooks or {}
    local id = lyx:HookStart(name, func)
    table.insert(self.hooks, {name = name, id = id})
    return id
end

function gm3ZeusCam:ClearHooks()
    if not self.hooks then return end
    for _, data in ipairs(self.hooks) do
        lyx:HookRemove(data.name, data.id)
    end
    table.Empty(self.hooks)
end

function gm3ZeusCam:RequestToggle(state)
    state = state ~= nil and state or not EnabledCam
    lyx:NetSend("gm3ZeusCam_toggleRequest", function()
        net.WriteBool(state and true or false)
    end)
end

local function IsSelectableEntity(ent)
    if not IsValid(ent) then return false end
    if ent:IsPlayer() and ent ~= LocalPlayer() then return true end
    if ent:IsNPC() or ent:IsNextBot() then return true end
    local class = ent:GetClass()
    if class == "prop_physics" or class == "prop_dynamic" then return true end
    return false
end

local function GetSelectionList()
    local list = {}
    for ent, _ in pairs(gm3_selectedEntities) do
        if IsValid(ent) then
            table.insert(list, ent)
        else
            gm3_selectedEntities[ent] = nil
        end
    end
    gm3_selectionCount = #list
    return list
end

local function ClearSelection()
    table.Empty(gm3_selectedEntities)
    gm3_selectionCount = 0
end

local function RestoreSelection(list)
    ClearSelection()
    for _, ent in ipairs(list or {}) do
        if IsValid(ent) then
            gm3_selectedEntities[ent] = true
        end
    end
    gm3_selectionCount = table.Count(gm3_selectedEntities)
end

local function AddToSelection(ent)
    if not IsSelectableEntity(ent) then return end
    if gm3_selectedEntities[ent] then return end
    gm3_selectedEntities[ent] = true
    gm3_selectionCount = gm3_selectionCount + 1
end

local function RemoveFromSelection(ent)
    if gm3_selectedEntities[ent] then
        gm3_selectedEntities[ent] = nil
        gm3_selectionCount = math.max(gm3_selectionCount - 1, 0)
    end
end

local function DrawOutlinedRect(x, y, w, h, thickness)
    thickness = thickness or 1
    for i = 0, thickness - 1 do
        surface.DrawOutlinedRect(x - i, y - i, w + i * 2, h + i * 2)
    end
end

local function GetEntityScreenBounds(ent)
    if not IsValid(ent) then return end
    local mins, maxs = ent:OBBMins(), ent:OBBMaxs()
    local corners = {
        Vector(mins.x, mins.y, mins.z),
        Vector(mins.x, mins.y, maxs.z),
        Vector(mins.x, maxs.y, mins.z),
        Vector(mins.x, maxs.y, maxs.z),
        Vector(maxs.x, mins.y, mins.z),
        Vector(maxs.x, mins.y, maxs.z),
        Vector(maxs.x, maxs.y, mins.z),
        Vector(maxs.x, maxs.y, maxs.z)
    }

    local minX, minY = math.huge, math.huge
    local maxX, maxY = -math.huge, -math.huge
    local anyVisible = false

    for _, corner in ipairs(corners) do
        local screen = ent:LocalToWorld(corner):ToScreen()
        if screen.visible then
            anyVisible = true
        end
        minX = math.min(minX, screen.x)
        minY = math.min(minY, screen.y)
        maxX = math.max(maxX, screen.x)
        maxY = math.max(maxY, screen.y)
    end

    if maxX <= minX or maxY <= minY then return end
    return minX, minY, maxX - minX, maxY - minY, anyVisible
end

local function SelectionHasNPCs()
    for ent, _ in pairs(gm3_selectedEntities) do
        if IsValid(ent) and (ent:IsNPC() or ent:IsNextBot()) then
            return true
        end
    end
    return false
end

local function SelectionHasProps()
    for ent, _ in pairs(gm3_selectedEntities) do
        if IsValid(ent) and not (ent:IsNPC() or ent:IsNextBot()) then
            return true
        end
    end
    return false
end

gm3_formations.line = function(count, spacing)
    local offsets = {}
    local start = -spacing * (count - 1) * 0.5
    local right = CamAngle:Right()
    for i = 0, count - 1 do
        offsets[#offsets + 1] = right * (start + i * spacing)
    end
    return offsets
end

gm3_formations.column = function(count, spacing)
    local offsets = {}
    local start = -spacing * (count - 1) * 0.5
    local forward = CamAngle:Forward()
    for i = 0, count - 1 do
        offsets[#offsets + 1] = forward * (start + i * spacing)
    end
    return offsets
end

gm3_formations.wedge = function(count, spacing)
    local offsets = {}
    local forward = CamAngle:Forward()
    local right = CamAngle:Right()
    local half = math.floor(count / 2)
    local index = 0
    for i = -half, half do
        index = index + 1
        local offset = forward * (-math.abs(i) * spacing * 0.5) + right * (i * spacing)
        offsets[index] = offset
    end
    while #offsets < count do
        offsets[#offsets + 1] = offsets[#offsets]
    end
    return offsets
end

gm3_formations.circle = function(count, spacing)
    local offsets = {}
    local radius = math.max(spacing, spacing * count / math.pi)
    for i = 1, count do
        local angle = (i / count) * math.pi * 2
        local dir = (CamAngle:Forward() * math.sin(angle)) + (CamAngle:Right() * math.cos(angle))
        offsets[#offsets + 1] = dir * radius
    end
    return offsets
end

function gm3ZeusCam:BuildNPCCache()
    if self.NPCCache then return self.NPCCache end
    local npcList = list.Get and list.Get("NPC") or {}
    local categories = {}
    for class, data in pairs(npcList) do
        local cat = data.Category or "Other"
        categories[cat] = categories[cat] or {}
        table.insert(categories[cat], {
            name = data.Name or class,
            class = class,
            data = data
        })
    end
    for _, entries in pairs(categories) do
        table.sort(entries, function(a, b) return tostring(a.name) < tostring(b.name) end)
    end
    self.NPCCache = categories
    return categories
end

function gm3ZeusCam:FindNPCEntry(class)
    if not class then return end
    local cache = self:BuildNPCCache()
    for category, entries in pairs(cache) do
        for _, entry in ipairs(entries) do
            if entry.class == class then
                return category, entry
            end
        end
    end
end

function gm3ZeusCam:RefreshSpawnControls()
    if not self.SpawnControls then return end
    self._refreshingSpawn = true
    local controls = self.SpawnControls

    if IsValid(controls.classEntry) and controls.classEntry:GetValue() ~= (gm3_spawnConfig.class or "") then
        controls.classEntry:SetValue(gm3_spawnConfig.class or "")
    end
    if IsValid(controls.weaponCombo) then
        local value = gm3_spawnConfig.weapon or ""
        if value == "" then
            value = "Default Weapon"
        end
        if controls.weaponCombo:GetValue() ~= value then
            controls.weaponCombo:SetValue(value)
        end
    end
    if IsValid(controls.countEntry) then
        controls.countEntry:SetValue(tostring(gm3_spawnConfig.count or 1))
    end
    if IsValid(controls.relationship) then
        controls.relationship:SetValue(string.upper(string.sub(gm3_spawnConfig.relationship or "hostile", 1, 1)) .. string.sub(gm3_spawnConfig.relationship or "hostile", 2))
    end

    if IsValid(controls.categoryCombo) and IsValid(controls.npcCombo) then
        local cat, entry = self:FindNPCEntry(gm3_spawnConfig.class)
        if cat then
            if controls.populateNPCCombo then
                controls.populateNPCCombo(cat)
            end
            controls.categoryCombo:SetValue(cat)
            if entry then
                controls.npcCombo:SetValue(entry.name or entry.class)
            end
        end
    end

    if controls.PresetButtons then
        for slot, btn in ipairs(controls.PresetButtons) do
            if IsValid(btn) then
                local preset = gm3_spawnPresets[slot]
                local labelText
                if preset and preset.class and preset.class ~= "" then
                    labelText = "Slot " .. slot .. ": " .. preset.class
                elseif preset then
                    labelText = "Slot " .. slot .. ": (custom)"
                else
                    labelText = "Slot " .. slot .. ": empty"
                end
                btn:SetText(labelText)
            end
        end
    end

    self._refreshingSpawn = false
end

function gm3ZeusCam:SaveSpawnPreset(slot)
    gm3_spawnPresets[slot] = table.Copy(gm3_spawnConfig)
    notification.AddLegacy("Saved spawn preset #" .. slot, NOTIFY_GENERIC, 2)
    self:RefreshSpawnControls()
end

function gm3ZeusCam:LoadSpawnPreset(slot)
    local preset = gm3_spawnPresets[slot]
    if not preset then
        notification.AddLegacy("Preset slot #" .. slot .. " is empty", NOTIFY_HINT, 2)
        return
    end
    gm3_spawnConfig = table.Copy(preset)
    notification.AddLegacy("Loaded spawn preset #" .. slot, NOTIFY_GENERIC, 2)
    self:RefreshSpawnControls()
end

function gm3ZeusCam:FocusSelection()
    local selection = GetSelectionList()
    if #selection == 0 then
        notification.AddLegacy("No entities selected.", NOTIFY_HINT, 2)
        return
    end
    local center = Vector()
    local valid = 0
    for _, ent in ipairs(selection) do
        if IsValid(ent) then
            center:Add(ent:WorldSpaceCenter())
            valid = valid + 1
        end
    end
    if valid == 0 then return end
    center = center / valid
    CamPos = center + Vector(0, 0, 300)
    CamAngle = Angle(60, CamAngle.y, 0)
    CamOriginalAngle = CamAngle
end

function gm3ZeusCam:ShockwaveAtCursor(traceOverride)
    local tr = gm3_GetEffectiveTrace(traceOverride)
    if not tr.Hit then
        notification.AddLegacy("Aim at a location to trigger the shockwave.", NOTIFY_HINT, 2)
        return
    end
    lyx:NetSend("gm3ZeusCam_shockwave", function()
        net.WriteVector(tr.HitPos)
        net.WriteUInt(400, 16)
    end)
end

local function SelectionHasPlayers()
    for ent, _ in pairs(gm3_selectedEntities) do
        if IsValid(ent) and ent:IsPlayer() and ent ~= LocalPlayer() then
            return true
        end
    end
    return false
end

local function GetSelectionCounts()
    local counts = {
        players = 0,
        npcs = 0,
        props = 0,
        totalHealth = 0
    }
    for ent, _ in pairs(gm3_selectedEntities) do
        if IsValid(ent) then
            if ent:IsPlayer() and ent ~= LocalPlayer() then
                counts.players = counts.players + 1
            elseif ent:IsNPC() or ent:IsNextBot() then
                counts.npcs = counts.npcs + 1
                counts.totalHealth = counts.totalHealth + math.max(ent:Health() or 0, 0)
            else
                counts.props = counts.props + 1
            end
        end
    end
    counts.avgHealth = counts.npcs > 0 and math.floor(counts.totalHealth / counts.npcs) or 0
    return counts
end

local function GetSelectionColor(ent)
    if not IsValid(ent) then return Color(255, 50, 50) end
    if ent:IsPlayer() and ent ~= LocalPlayer() then
        return Color(0, 200, 255)
    elseif ent:IsNPC() or ent:IsNextBot() then
        return Color(255, 80, 80)
    else
        return Color(200, 140, 255)
    end
end

local function DrawSelectionSummaryPanel(counts)
    if gm3_selectionCount == 0 then return end
    local panelW = lyx.ScaleW(240)
    local panelH = lyx.Scale(90)
    local x = ScrW() - panelW - lyx.ScaleW(20)
    local y = ScrH() - panelH - lyx.Scale(120)
    surface.SetDrawColor(15, 15, 15, 200)
    surface.DrawRect(x, y, panelW, panelH)
    surface.SetDrawColor(90, 200, 255, 200)
    surface.DrawOutlinedRect(x, y, panelW, panelH)
    draw.SimpleText("Selection Summary", "GM3_Cam_Subtitle", x + lyx.Scale(8), y + lyx.Scale(6), color_white, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
    local rowY = y + lyx.Scale(28)
    draw.SimpleText("Members: " .. gm3_selectionCount, "GM3_Cam_Subtitle", x + lyx.Scale(10), rowY, color_white, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
    rowY = rowY + lyx.Scale(18)
    draw.SimpleText(string.format("Players %d · NPCs %d · Props %d", counts.players, counts.npcs, counts.props), "GM3_Cam_Subtitle", x + lyx.Scale(10), rowY, Color(220, 220, 220), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
    rowY = rowY + lyx.Scale(18)
    draw.SimpleText("Avg NPC Health: " .. counts.avgHealth, "GM3_Cam_Subtitle", x + lyx.Scale(10), rowY, Color(200, 255, 200), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
end

local function DrawSignalMarkersHUD()
    if #gm3_signalMarkers == 0 then return end
    local now = CurTime()
    local displayY = ScrH() * 0.35
    for i = #gm3_signalMarkers, 1, -1 do
        local marker = gm3_signalMarkers[i]
        if not marker or marker.expire <= now then
            table.remove(gm3_signalMarkers, i)
        else
            local screen = marker.pos:ToScreen()
            local txt = string.format("%s (%.0fs)", marker.label or "Marker", marker.expire - now)
            draw.SimpleText(txt, "GM3_Cam_Subtitle", screen.x, screen.y, marker.color or color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            surface.SetDrawColor(marker.color.r, marker.color.g, marker.color.b, 180)
            surface.DrawLine(screen.x - 20, screen.y, screen.x + 20, screen.y)
            surface.DrawLine(screen.x, screen.y - 20, screen.x, screen.y + 20)
            draw.SimpleText(txt, "GM3_Cam_Subtitle", ScrW() - lyx.ScaleW(10), displayY, marker.color or color_white, TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP)
            displayY = displayY + lyx.Scale(18)
        end
    end
end

function gm3ZeusCam:GetCursorPos()
    local x, y = gui.MousePos()
    return math.Clamp(x or ScrW() * 0.5, 0, ScrW()), math.Clamp(y or ScrH() * 0.5, 0, ScrH())
end

function gm3ZeusCam:ScreenToWorldDirection(x, y)
    local w, h = ScrW(), ScrH()
    local ndcX = (x / w) * 2 - 1
    local ndcY = (y / h) * 2 - 1
    local fov = math.rad(CamFOV or 90)
    local aspect = w / h
    local tanHalf = math.tan(fov * 0.5)

    local forward = CamAngle:Forward()
    local right = CamAngle:Right()
    local up = CamAngle:Up()

    local dir = forward
        + right * ndcX * tanHalf * aspect
        - up * ndcY * tanHalf
    return dir:GetNormalized()
end

function gm3ZeusCam:GetCursorTrace(maxDistance)
    maxDistance = maxDistance or 20000
    local x, y = self:GetCursorPos()
    local dir = self:ScreenToWorldDirection(x, y)
    return util.TraceLine({
        start = CamPos,
        endpos = CamPos + dir * maxDistance,
        filter = function(ent) return ent ~= LocalPlayer() end
    })
end

function gm3ZeusCam:SetCursorMode(state)
    if gm3_cursorMode == state then return end
    gm3_cursorMode = state
    gui.EnableScreenClicker(state)
    if not state then
        gm3_selectionBox.active = false
        gm3_selectionBox.dragging = false
        gm3_hoveredEntity = nil
        if IsValid(gm3_contextMenu) then
            gm3_contextMenu:Remove()
            gm3_contextMenu = nil
        end
    end
end

function gm3ZeusCam:TrackMoveOrders(targetPos, entities, skipVisual)
    if not targetPos or skipVisual then return end
    local now = CurTime()
    for _, ent in ipairs(entities or {}) do
        if IsValid(ent) then
            table.insert(gm3_moveOrders, {
                ent = ent,
                target = targetPos,
                created = now,
                expire = now + 6
            })
        end
    end
end

local function CleanupMoveOrders()
    local now = CurTime()
    for i = #gm3_moveOrders, 1, -1 do
        local data = gm3_moveOrders[i]
        if not data or now > data.expire or not IsValid(data.ent) then
            table.remove(gm3_moveOrders, i)
        end
    end
end

function gm3ZeusCam:SaveSelectionGroup(slot)
    local selection = GetSelectionList()
    if #selection == 0 then
        notification.AddLegacy("Select entities before saving a group.", NOTIFY_HINT, 2)
        return
    end
    gm3_selectionGroups[slot] = table.Copy(selection)
    notification.AddLegacy("Saved selection group #" .. slot, NOTIFY_GENERIC, 2)
end

function gm3ZeusCam:LoadSelectionGroup(slot)
    local group = gm3_selectionGroups[slot]
    if not group then
        notification.AddLegacy("Selection group #" .. slot .. " is empty.", NOTIFY_HINT, 2)
        return
    end
    RestoreSelection(group)
    notification.AddLegacy("Loaded selection group #" .. slot, NOTIFY_GENERIC, 2)
end

local function ClearWaypoints()
    table.Empty(gm3_waypoints)
end

local function UpdateRouteVisualProgress()
    local now = CurTime()
    for ent, data in pairs(gm3_routeVisuals) do
        if not IsValid(ent) or not istable(data) or not istable(data.nodes) or #data.nodes == 0 then
            gm3_routeVisuals[ent] = nil
        else
            data.currentIndex = math.Clamp(data.currentIndex or 1, 1, #data.nodes)
            local target = data.nodes[data.currentIndex]
            local entPos = ent:WorldSpaceCenter()
            if target and entPos:DistToSqr(target) < (data.threshold or 6400) then
                data.currentIndex = data.currentIndex + 1
                if data.currentIndex > #data.nodes then
                    if data.loop then
                        data.currentIndex = 1
                    else
                        gm3_routeVisuals[ent] = nil
                    end
                end
            end
            if data.expires and data.expires < now then
                gm3_routeVisuals[ent] = nil
            end
        end
    end
end

function gm3ZeusCam:CreateRouteVisualFor(selection, baseData, perEntityNodes)
    baseData = baseData or {}
    for _, ent in ipairs(selection or {}) do
        if IsValid(ent) then
            local route = table.Copy(baseData)
            local nodes = perEntityNodes and perEntityNodes[ent]
            nodes = nodes or baseData.nodes
            if nodes and #nodes > 0 then
                route.nodes = table.Copy(nodes)
                route.loop = baseData.loop or false
                route.currentIndex = 1
                route.routeType = baseData.routeType or "move"
                route.color = baseData.color or gm3_routeColors[route.routeType] or GetSelectionColor(ent) or gm3_routeColors.default
                route.thickness = baseData.thickness or 4
                route.threshold = baseData.threshold or 6400
                route.label = baseData.label or string.upper(string.sub(route.routeType, 1, 1)) .. string.sub(route.routeType, 2)
                route.expires = baseData.persistent == false and (CurTime() + 6) or nil
                gm3_routeVisuals[ent] = route
            end
        end
    end
end

function gm3ZeusCam:SetWaypointMode(state)
    state = state and true or false
    if state and not SelectionHasNPCs() then
        notification.AddLegacy("Select NPCs before entering waypoint mode.", NOTIFY_HINT, 2)
        return
    end
    if state then
        gm3_spawnMode = false
        self:SetSpawnMode(false)
        ClearWaypoints()
        gm3_waypointPreviewPos = nil
    end
    if not state then
        ClearWaypoints()
        gm3_waypointPreviewPos = nil
    end
    gm3_waypointMode = state
    if IsValid(self.WaypointModeButton) then
        self.WaypointModeButton:SetText(state and "Waypoint Mode (ON)" or "Waypoint Mode (OFF)")
        self.WaypointModeButton:SetBackgroundColor(state and Color(30, 160, 210) or Color(90, 90, 90))
    end
end

function gm3ZeusCam:RefreshWaypointLoopButton()
    if IsValid(self.WaypointLoopButton) then
        self.WaypointLoopButton:SetText(gm3_waypointLoop and "Loop Patrol (ON)" or "Loop Patrol (OFF)")
        self.WaypointLoopButton:SetBackgroundColor(gm3_waypointLoop and Color(50, 160, 80) or Color(120, 60, 60))
    end
end

function gm3ZeusCam:ToggleWaypointLoop(forceState)
    if forceState ~= nil then
        gm3_waypointLoop = forceState and true or false
    else
        gm3_waypointLoop = not gm3_waypointLoop
    end
    self:RefreshWaypointLoopButton()
end

function gm3ZeusCam:AddWaypoint(pos)
    if not gm3_waypointMode then return end
    if #gm3_waypoints >= 8 then
        notification.AddLegacy("Waypoint limit reached (8).", NOTIFY_HINT, 2)
        return
    end
    gm3_waypoints[#gm3_waypoints + 1] = pos
    surface.PlaySound("buttons/lightswitch2.wav")
end

function gm3ZeusCam:CommitWaypoints()
    if not gm3_waypointMode then return end
    if not SelectionHasNPCs() then
        notification.AddLegacy("Waypoint mode requires NPC selection.", NOTIFY_HINT, 2)
        self:SetWaypointMode(false)
        return
    end
    if #gm3_waypoints == 0 then
        notification.AddLegacy("Add waypoints with LMB before finalizing.", NOTIFY_HINT, 2)
        return
    end

    local finalTarget = gm3_waypoints[#gm3_waypoints]
    local selection = self:SendSelectionCommand("gm3ZeusCam_setPatrolRoute", nil, function()
        net.WriteUInt(#gm3_waypoints, 6)
        for _, waypoint in ipairs(gm3_waypoints) do
            net.WriteVector(waypoint)
        end
        net.WriteBool(gm3_waypointLoop)
    end)

    if selection then
        self:TrackMoveOrders(finalTarget, selection, true)
        notification.AddLegacy("Issued patrol route to " .. tostring(#selection) .. " units.", NOTIFY_GENERIC, 3)
        self:CreateRouteVisualFor(selection, {
            routeType = "patrol",
            nodes = table.Copy(gm3_waypoints),
            loop = gm3_waypointLoop,
            label = gm3_waypointLoop and "Patrol Loop" or "Patrol",
            thickness = 5,
            persistent = true,
            threshold = 9000
        })
    end

    self:SetWaypointMode(false)
end

function gm3ZeusCam:CancelWaypoints(silent)
    if #gm3_waypoints > 0 and not silent then
        notification.AddLegacy("Cleared staged waypoints.", NOTIFY_HINT, 2)
    end
    ClearWaypoints()
    gm3_waypointPreviewPos = nil
end

function gm3ZeusCam:HandleWaypointInput()
    if not SelectionHasNPCs() then
        self:SetWaypointMode(false)
        notification.AddLegacy("Waypoint mode cancelled: no NPCs selected.", NOTIFY_HINT, 2)
        return
    end
    local tr = self:GetCursorTrace()
    gm3_waypointPreviewPos = tr.Hit and tr.HitPos or nil

    if input.IsMouseDown(MOUSE_LEFT) and CurTime() > gm3_nextWaypointClick then
        gm3_nextWaypointClick = CurTime() + 0.2
        if tr.Hit then
            self:AddWaypoint(tr.HitPos + Vector(0, 0, 2))
        else
            notification.AddLegacy("Waypoint must be placed on valid geometry.", NOTIFY_HINT, 2)
        end
    elseif not input.IsMouseDown(MOUSE_LEFT) then
        gm3_nextWaypointClick = math.max(gm3_nextWaypointClick - FrameTime(), 0)
    end

    if input.IsMouseDown(MOUSE_RIGHT) then
        gm3_rightMouseHeld = true
    elseif gm3_rightMouseHeld then
        gm3_rightMouseHeld = false
        if #gm3_waypoints > 0 then
            self:CommitWaypoints()
        else
            self:SetWaypointMode(false)
        end
        return true
    end

    if input.IsKeyDown(KEY_BACKSPACE) then
        if not gm3_waypointClearHeld and #gm3_waypoints > 0 then
            table.remove(gm3_waypoints)
            notification.AddLegacy("Removed last waypoint.", NOTIFY_HINT, 1)
        end
        gm3_waypointClearHeld = true
        return
    elseif input.IsKeyDown(KEY_DELETE) then
        if not gm3_waypointClearHeld and #gm3_waypoints > 0 then
            self:CancelWaypoints()
        end
        gm3_waypointClearHeld = true
        return
    else
        gm3_waypointClearHeld = false
    end
end

function gm3ZeusCam:SetSpawnMode(state)
    gm3_spawnMode = state and true or false
    if gm3_spawnMode then
        self:SetWaypointMode(false)
    end
    if IsValid(self.SpawnModeButton) then
        self.SpawnModeButton:SetText(gm3_spawnMode and "Spawn Mode (ON)" or "Spawn Mode (OFF)")
        self.SpawnModeButton:SetBackgroundColor(gm3_spawnMode and Color(30, 160, 110) or Color(90, 90, 90))
    end
end

function gm3ZeusCam:CreateSpawnToolbar(parent)
    if IsValid(self.SpawnToolbar) then
        self.SpawnToolbar:Remove()
        self.SpawnToolbar = nil
        self.SpawnArtillerySlider = nil
    end

    local panel = vgui.Create("DPanel", parent)
    panel:SetSize(lyx.ScaleW(320), lyx.Scale(520))
    panel:SetPos(ScrW() - lyx.ScaleW(340), lyx.Scale(120))
    panel.Paint = function(s, w, h)
        surface.SetDrawColor(gm3_spawnMode and Color(20, 80, 60, 230) or Color(30, 30, 30, 220))
        surface.DrawRect(0, 0, w, h)
        surface.SetDrawColor(70, 70, 70, 255)
        surface.DrawOutlinedRect(0, 0, w, h)
        draw.SimpleText("Spawn Toolbar", "GM3_Cam_Subtitle", lyx.Scale(10), lyx.Scale(6), color_white)
        draw.SimpleText("Shift+Click preset to save, click to load", "GM3_Cam_Subtitle", lyx.Scale(10), lyx.Scale(24), Color(200, 200, 200))
    end

    local cache = self:BuildNPCCache()

    local catLabel = vgui.Create("DLabel", panel)
    catLabel:Dock(TOP)
    catLabel:DockMargin(lyx.Scale(8), lyx.Scale(46), lyx.Scale(8), lyx.Scale(2))
    catLabel:SetFont("GM3_Cam_Subtitle")
    catLabel:SetText("NPC Category")
    catLabel:SetTextColor(color_white)
    catLabel:SetTall(lyx.Scale(18))

    local categoryCombo = vgui.Create("DComboBox", panel)
    categoryCombo:Dock(TOP)
    categoryCombo:DockMargin(lyx.Scale(8), 0, lyx.Scale(8), lyx.Scale(4))
    categoryCombo:SetTall(lyx.Scale(24))
    categoryCombo:SetValue("Category")

    local npcLabel = vgui.Create("DLabel", panel)
    npcLabel:Dock(TOP)
    npcLabel:DockMargin(lyx.Scale(8), 0, lyx.Scale(8), lyx.Scale(2))
    npcLabel:SetFont("GM3_Cam_Subtitle")
    npcLabel:SetText("NPC Entry")
    npcLabel:SetTextColor(color_white)
    npcLabel:SetTall(lyx.Scale(18))

    local npcCombo = vgui.Create("DComboBox", panel)
    npcCombo:Dock(TOP)
    npcCombo:DockMargin(lyx.Scale(8), 0, lyx.Scale(8), lyx.Scale(6))
    npcCombo:SetTall(lyx.Scale(24))
    npcCombo:SetValue("NPC")

    local function PopulateNPCCombo(category)
        npcCombo:Clear()
        npcCombo.ClassMap = {}
        npcCombo:SetValue("NPC")
        local entries = cache[category] or {}
        for _, entry in ipairs(entries) do
            npcCombo:AddChoice(entry.name, entry)
            npcCombo.ClassMap[entry.name] = entry
        end
    end

    for category, _ in SortedPairs(cache) do
        categoryCombo:AddChoice(category)
    end

    categoryCombo.OnSelect = function(_, _, value)
        PopulateNPCCombo(value)
    end

    local SetWeaponChoices

    npcCombo.OnSelect = function(_, _, _, entry)
        if not entry or self._refreshingSpawn then return end
        gm3_spawnConfig.class = entry.class
        local weapons = entry.data and entry.data.Weapons
        if istable(weapons) and weapons[1] then
            gm3_spawnConfig.weapon = weapons[1]
        else
            gm3_spawnConfig.weapon = ""
        end
        if SetWeaponChoices then
            SetWeaponChoices(weapons)
        end
        self:RefreshSpawnControls()
    end

    local classLabel = vgui.Create("DLabel", panel)
    classLabel:Dock(TOP)
    classLabel:DockMargin(lyx.Scale(8), 0, lyx.Scale(8), lyx.Scale(2))
    classLabel:SetFont("GM3_Cam_Subtitle")
    classLabel:SetText("NPC Class Override")
    classLabel:SetTextColor(color_white)
    classLabel:SetTall(lyx.Scale(18))

    local classEntry = vgui.Create("lyx.TextEntry2", panel)
    classEntry:Dock(TOP)
    classEntry:DockMargin(lyx.Scale(8), 0, lyx.Scale(8), lyx.Scale(4))
    classEntry:SetPlaceholderText("NPC Class")
    classEntry:SetValue(gm3_spawnConfig.class)
    classEntry.OnChange = function(s)
        if self._refreshingSpawn then return end
        gm3_spawnConfig.class = string.Trim(s:GetValue() or "")
    end

    local weaponLabel = vgui.Create("DLabel", panel)
    weaponLabel:Dock(TOP)
    weaponLabel:DockMargin(lyx.Scale(8), 0, lyx.Scale(8), lyx.Scale(2))
    weaponLabel:SetFont("GM3_Cam_Subtitle")
    weaponLabel:SetText("Weapon Override")
    weaponLabel:SetTextColor(color_white)
    weaponLabel:SetTall(lyx.Scale(18))

    local defaultWeaponLabel = "Default Weapon"
    local weaponCombo = vgui.Create("DComboBox", panel)
    weaponCombo:Dock(TOP)
    weaponCombo:DockMargin(lyx.Scale(8), 0, lyx.Scale(8), lyx.Scale(4))
    weaponCombo:SetTall(lyx.Scale(24))
    weaponCombo:SetValue(gm3_spawnConfig.weapon ~= "" and gm3_spawnConfig.weapon or defaultWeaponLabel)
    if IsValid(weaponCombo.TextEntry) and weaponCombo.TextEntry.SetEditable then
        weaponCombo.TextEntry:SetEditable(true)
    end
    weaponCombo.OnSelect = function(_, _, value, data)
        if self._refreshingSpawn then return end
        local result = data ~= nil and data or value or ""
        if result == defaultWeaponLabel then
            result = ""
        end
        gm3_spawnConfig.weapon = string.Trim(result or "")
    end
    weaponCombo.OnChange = function(combo)
        if self._refreshingSpawn then return end
        local val = string.Trim(combo:GetValue() or "")
        if val == defaultWeaponLabel then
            val = ""
        end
        gm3_spawnConfig.weapon = val
    end

    SetWeaponChoices = function(weapons)
        weaponCombo:Clear()
        weaponCombo:AddChoice(defaultWeaponLabel, "")
        if istable(weapons) then
            for _, weaponName in ipairs(weapons) do
                if isstring(weaponName) and weaponName ~= "" then
                    weaponCombo:AddChoice(weaponName, weaponName)
                end
            end
        end
        local current = gm3_spawnConfig.weapon or ""
        if current == "" then
            weaponCombo:SetValue(defaultWeaponLabel)
        else
            weaponCombo:SetValue(current)
        end
    end

    local initialCategory, initialEntry = self:FindNPCEntry(gm3_spawnConfig.class)
    if not initialCategory then
        initialCategory = next(cache)
    end
    if initialCategory then
        PopulateNPCCombo(initialCategory)
        categoryCombo:SetValue(initialCategory)
        if initialEntry then
            npcCombo:SetValue(initialEntry.name or initialEntry.class)
        end
    end
    if SetWeaponChoices then
        if initialEntry then
            SetWeaponChoices(initialEntry.data and initialEntry.data.Weapons)
        else
            SetWeaponChoices(nil)
        end
    end

    local countLabel = vgui.Create("DLabel", panel)
    countLabel:Dock(TOP)
    countLabel:DockMargin(lyx.Scale(8), 0, lyx.Scale(8), lyx.Scale(2))
    countLabel:SetFont("GM3_Cam_Subtitle")
    countLabel:SetText("Spawn Count")
    countLabel:SetTextColor(color_white)
    countLabel:SetTall(lyx.Scale(18))

    local countEntry = vgui.Create("lyx.TextEntry2", panel)
    countEntry:Dock(TOP)
    countEntry:DockMargin(lyx.Scale(8), 0, lyx.Scale(8), lyx.Scale(4))
    countEntry:SetPlaceholderText("Count (1-20)")
    countEntry:SetValue(tostring(gm3_spawnConfig.count))
    countEntry:SetNumeric(true)
    countEntry.OnChange = function(s)
        if self._refreshingSpawn then return end
        local val = tonumber(s:GetValue()) or 1
        gm3_spawnConfig.count = math.Clamp(math.floor(val), 1, 20)
    end

    local relationship = vgui.Create("DComboBox", panel)
    relationship:Dock(TOP)
    relationship:DockMargin(lyx.Scale(8), 0, lyx.Scale(8), lyx.Scale(8))
    relationship:AddChoice("Hostile", "hostile", gm3_spawnConfig.relationship == "hostile")
    relationship:AddChoice("Friendly", "friendly", gm3_spawnConfig.relationship == "friendly")
    relationship:AddChoice("Neutral", "neutral", gm3_spawnConfig.relationship == "neutral")
    relationship.OnSelect = function(_, _, value)
        gm3_spawnConfig.relationship = value
    end

    local presetPanel = vgui.Create("DPanel", panel)
    presetPanel:Dock(TOP)
    presetPanel:DockMargin(lyx.Scale(8), 0, lyx.Scale(8), lyx.Scale(6))
    presetPanel:SetTall(lyx.Scale(190))
    presetPanel.Paint = nil

    local presetButtons = {}
    for slot = 1, 5 do
        local row = vgui.Create("DPanel", presetPanel)
        row:Dock(TOP)
        row:DockMargin(0, 0, 0, lyx.Scale(4))
        row:SetTall(lyx.Scale(26))
        row.Paint = nil

        local btn = vgui.Create("lyx.TextButton2", row)
        btn:Dock(FILL)
        btn:SetText("Slot " .. slot .. ": empty")
        btn.DoClick = function()
            gm3ZeusCam:LoadSpawnPreset(slot)
        end
        presetButtons[slot] = btn

        local reset = vgui.Create("lyx.TextButton2", row)
        reset:Dock(RIGHT)
        reset:DockMargin(lyx.Scale(4), 0, 0, 0)
        reset:SetWide(lyx.Scale(40))
        reset:SetText("✕")
        reset.DoClick = function()
            gm3_spawnPresets[slot] = nil
            gm3ZeusCam:RefreshSpawnControls()
            notification.AddLegacy("Cleared spawn preset #" .. slot, NOTIFY_GENERIC, 2)
        end
        reset:SetBackgroundColor(Color(150, 50, 50))

        local save = vgui.Create("lyx.TextButton2", row)
        save:Dock(RIGHT)
        save:SetWide(lyx.Scale(60))
        save:SetText("Save")
        save.DoClick = function()
            gm3ZeusCam:SaveSpawnPreset(slot)
        end
    end

    local artilleryLabel = vgui.Create("DLabel", panel)
    artilleryLabel:Dock(TOP)
    artilleryLabel:DockMargin(lyx.Scale(8), lyx.Scale(6), lyx.Scale(8), 0)
    artilleryLabel:SetFont("GM3_Cam_Subtitle")
    artilleryLabel:SetText("Artillery Warning Delay (sec)")
    artilleryLabel:SetTextColor(color_white)
    artilleryLabel:SetTall(lyx.Scale(20))

    local artillerySlider = vgui.Create("DNumSlider", panel)
    artillerySlider:Dock(TOP)
    artillerySlider:DockMargin(lyx.Scale(8), 0, lyx.Scale(8), lyx.Scale(4))
    artillerySlider:SetMin(1)
    artillerySlider:SetMax(120)
    artillerySlider:SetDecimals(0)
    artillerySlider:SetValue(gm3_NormalizeArtilleryDelay(CVCamArtilleryDelay:GetFloat()))
    artillerySlider:SetText("Fire Support Delay")
    artillerySlider:SetTall(lyx.Scale(30))
    if artillerySlider.Label then
        artillerySlider.Label:SetFont("GM3_Cam_Subtitle")
        artillerySlider.Label:SetTextColor(color_white)
    end
    artillerySlider.OnValueChanged = function(slider, value)
        if slider._suppress then return end
        gm3_UpdateArtilleryDelay(value)
    end
    gm3ZeusCam.SpawnArtillerySlider = artillerySlider

    local toggle = vgui.Create("lyx.TextButton2", panel)
    toggle:Dock(BOTTOM)
    toggle:DockMargin(lyx.Scale(8), 0, lyx.Scale(8), lyx.Scale(8))
    toggle:SetTall(lyx.Scale(32))
    toggle:SetText("Spawn Mode (OFF)")
    toggle.DoClick = function()
        self:SetSpawnMode(not gm3_spawnMode)
    end

    self.SpawnToolbar = panel
    self.SpawnModeButton = toggle
    self.SpawnControls = {
        categoryCombo = categoryCombo,
        npcCombo = npcCombo,
        classEntry = classEntry,
        weaponCombo = weaponCombo,
        weaponChoices = SetWeaponChoices,
        countEntry = countEntry,
        relationship = relationship,
        PresetButtons = presetButtons,
        populateNPCCombo = PopulateNPCCombo
    }
    self:SetSpawnMode(false)
    self:SetWaypointMode(false)
    self:RefreshWaypointLoopButton()
    self:RefreshSpawnControls()
end

function gm3ZeusCam:OpenFireSupportPanel()
    if IsValid(self.FireSupportPanel) then
        self.FireSupportPanel:MakePopup()
        self.FireSupportPanel:MoveToFront()
        return
    end

    local frame = vgui.Create("lyx.Frame2")
    if not IsValid(frame) then return end
    frame:SetTitle("Fire Support Console")
    frame:SetSize(lyx.ScaleW(320), lyx.Scale(380))
    frame:Center()
    frame:MakePopup()
    frame:DockPadding(lyx.Scale(8), lyx.Scale(30), lyx.Scale(8), lyx.Scale(8))
    self.FireSupportPanel = frame

    local hint = vgui.Create("DLabel", frame)
    hint:Dock(TOP)
    hint:SetTall(lyx.Scale(20))
    hint:SetFont("GM3_Cam_Subtitle")
    hint:SetTextColor(color_white)
    hint:SetText("Adjust warning delay, then pick a strike profile.")

    local slider = vgui.Create("DNumSlider", frame)
    slider:Dock(TOP)
    slider:DockMargin(0, lyx.Scale(4), 0, lyx.Scale(6))
    slider:SetMin(1)
    slider:SetMax(120)
    slider:SetDecimals(0)
    slider:SetValue(gm3_NormalizeArtilleryDelay(CVCamArtilleryDelay:GetFloat()))
    slider:SetText("Impact Warning (sec)")
    if slider.Label then
        slider.Label:SetFont("GM3_Cam_Subtitle")
        slider.Label:SetTextColor(color_white)
    end
    if slider.TextArea then
        slider.TextArea:SetDrawLanguageID(false)
        slider.TextArea:SetFont("GM3_Cam_Subtitle")
        slider.TextArea:SetTextColor(color_white)
        slider.TextArea:SetPaintBackground(false)
    end
    slider.OnValueChanged = function(s, value)
        if s._suppress then return end
        gm3_UpdateArtilleryDelay(value)
    end
    gm3ZeusCam.FireSupportSlider = slider

    local traceInfo = vgui.Create("DLabel", frame)
    traceInfo:Dock(TOP)
    traceInfo:SetTall(lyx.Scale(20))
    traceInfo:SetFont("GM3_Cam_Subtitle")
    traceInfo:SetTextColor(Color(200, 200, 200))
    traceInfo:SetText("Using latest cursor target when opened.")

    local scroll = vgui.Create("DScrollPanel", frame)
    scroll:Dock(FILL)
    scroll:DockMargin(0, lyx.Scale(6), 0, 0)

    for key, profile in SortedPairs(gm3_fireSupportProfiles) do
        local btn = vgui.Create("lyx.TextButton2", scroll)
        btn:Dock(TOP)
        btn:DockMargin(0, 0, 0, lyx.Scale(4))
        btn:SetTall(lyx.Scale(32))
        btn:SetText(string.format("%s • %d shells", profile.label, profile.shells or 1))
        btn.DoClick = function()
            local trace = gm3ZeusCam._pendingFireSupportTrace
            if not trace or not trace.Hit then
                trace = gm3ZeusCam:GetCursorTrace()
            end
            gm3ZeusCam:CallFireSupport(key, trace)
            frame:Close()
        end
    end

    frame.OnRemove = function()
        if gm3ZeusCam.FireSupportSlider == slider then
            gm3ZeusCam.FireSupportSlider = nil
        end
        if gm3ZeusCam.FireSupportPanel == frame then
            gm3ZeusCam.FireSupportPanel = nil
        end
    end
end

function gm3ZeusCam:SpawnAtCursor()
    local tr = self:GetCursorTrace()
    if not tr.Hit then
        notification.AddLegacy("Aim at the ground to spawn NPCs.", NOTIFY_ERROR, 2)
        return
    end

    local class = string.Trim(gm3_spawnConfig.class or "")
    if class == "" then
        notification.AddLegacy("NPC class cannot be empty.", NOTIFY_ERROR, 2)
        return
    end

    local weapon = string.Trim(gm3_spawnConfig.weapon or "")
    local count = math.Clamp(gm3_spawnConfig.count or 1, 1, 20)
    local spawnPos = tr.HitPos + tr.HitNormal * 80
    local yaw = (CamAngle and CamAngle.y) or 0
    local spawnAng = Angle(0, yaw, 0)

    lyx:NetSend("gm3ZeusCam_spawnNPCs", function()
        net.WriteString(class)
        net.WriteString(weapon)
        net.WriteUInt(count, 6)
        net.WriteVector(spawnPos)
        net.WriteAngle(spawnAng)
        net.WriteString(gm3_spawnConfig.relationship or "hostile")
    end)
end

function gm3ZeusCam:CallFireSupport(profileKey, traceOverride)
    local profile = gm3_fireSupportProfiles[profileKey]
    if not profile then return end
    local tr = gm3_GetEffectiveTrace(traceOverride)
    if not tr.Hit then
        notification.AddLegacy("Aim at terrain before calling fire support.", NOTIFY_ERROR, 2)
        return
    end

    local impactDelay = math.Clamp(CVCamArtilleryDelay:GetFloat() or profile.warning or 5, 1, 120)
    lyx:NetSend("gm3ZeusCam_callArtillery", function()
        net.WriteVector(tr.HitPos)
        net.WriteUInt(math.Clamp(profile.radius, 50, 1023), 12)
        net.WriteUInt(math.Clamp(profile.shells, 1, 12), 4)
        net.WriteFloat(math.Clamp(profile.delay or 0.5, 0.1, 3))
        net.WriteBool(profile.smoke and true or false)
        net.WriteFloat(impactDelay)
        net.WriteString(profileKey or "")
    end)

    notification.AddLegacy(string.format("%s inbound in %ds.", profile.label, math.Round(impactDelay)), NOTIFY_GENERIC, 3)
end

function gm3ZeusCam:RequestSupplyDrop(dropType, traceOverride)
    dropType = dropType or "ammo"
    local tr = gm3_GetEffectiveTrace(traceOverride)
    if not tr.Hit then
        notification.AddLegacy("Aim at terrain before requesting a drop.", NOTIFY_ERROR, 2)
        return
    end

    lyx:NetSend("gm3ZeusCam_supplyDrop", function()
        net.WriteVector(tr.HitPos)
        net.WriteString(dropType)
    end)
    notification.AddLegacy(string.upper(string.sub(dropType, 1, 1)) .. string.sub(dropType, 2) .. " drop inbound.", NOTIFY_GENERIC, 3)
end

function gm3ZeusCam:CreateDefenseZone(radius, posture, traceOverride)
    if not SelectionHasNPCs() then
        notification.AddLegacy("Select NPCs to assign a defense zone.", NOTIFY_HINT, 2)
        return
    end
    local tr = gm3_GetEffectiveTrace(traceOverride)
    if not tr.Hit then
        notification.AddLegacy("Aim at terrain before defining a zone.", NOTIFY_ERROR, 2)
        return
    end
    posture = posture or "defensive"
    radius = math.Clamp(math.floor(radius or 300), 100, 2000)

    self:SendSelectionCommand("gm3ZeusCam_createDefenseZone", tr.HitPos, function()
        net.WriteUInt(radius, 12)
        net.WriteString(posture)
    end)
    notification.AddLegacy("Defense zone established (" .. posture .. ")", NOTIFY_GENERIC, 3)
end

function gm3ZeusCam:RequestReconPulse(radius, traceOverride)
    local now = CurTime()
    if now < gm3_lastReconRequest then
        notification.AddLegacy("Recon systems recharging...", NOTIFY_HINT, 2)
        return
    end
    radius = math.Clamp(math.floor(radius or 500), 100, 2000)
    local tr = gm3_GetEffectiveTrace(traceOverride)
    if not tr.Hit then
        notification.AddLegacy("Aim at terrain before pinging recon.", NOTIFY_ERROR, 2)
        return
    end

    gm3_lastReconRequest = now + 5
    lyx:NetSend("gm3ZeusCam_reconPulse", function()
        net.WriteVector(tr.HitPos)
        net.WriteUInt(radius, 12)
    end)
    notification.AddLegacy("Recon pulse launched (" .. radius .. " units).", NOTIFY_HINT, 2)
end

function gm3ZeusCam:DeploySensorBeacon(duration, radius, traceOverride)
    duration = duration or 45
    radius = radius or 600
    local tr = gm3_GetEffectiveTrace(traceOverride)
    if not tr.Hit then
        notification.AddLegacy("Aim at terrain before deploying a sensor.", NOTIFY_ERROR, 2)
        return
    end
    lyx:NetSend("gm3ZeusCam_deploySensor", function()
        net.WriteVector(tr.HitPos)
        net.WriteUInt(math.Clamp(radius, 200, 1500), 12)
        net.WriteUInt(math.Clamp(duration, 10, 180), 12)
    end)
    notification.AddLegacy("Sensor beacon deploying...", NOTIFY_GENERIC, 2)
end

function gm3ZeusCam:SendFormationCommand(name, traceOverride)
    if not SelectionHasNPCs() then
        notification.AddLegacy("Select NPCs to use formations.", NOTIFY_HINT, 2)
        return
    end
    local formation = gm3_formations[name]
    if not formation then return end
    local tr = gm3_GetEffectiveTrace(traceOverride)
    if not tr.Hit then
        notification.AddLegacy("Aim at a location to send the formation.", NOTIFY_ERROR, 2)
        return
    end
    local selection = GetSelectionList()
    local offsets = formation(#selection, gm3_formationSpacing)
    local targetPositions = {}
    local perEntityNodes = {}
    for i, ent in ipairs(selection) do
        local offset = offsets[i] or offsets[#offsets]
        targetPositions[i] = tr.HitPos + offset
        if IsValid(ent) then
            perEntityNodes[ent] = {tr.HitPos + offset}
        end
    end

    lyx:NetSend("gm3ZeusCam_moveFormation", function()
        net.WriteUInt(#selection, 12)
        for i, ent in ipairs(selection) do
            net.WriteEntity(ent)
            net.WriteVector(targetPositions[i])
        end
    end)

    self:CreateRouteVisualFor(selection, {
        routeType = "formation",
        label = "Formation",
        thickness = 5,
        persistent = true
    }, perEntityNodes)
end

function gm3ZeusCam:FinalizeSelectionBox()
    local box = gm3_selectionBox
    local addMode = input.IsKeyDown(KEY_LSHIFT) or input.IsKeyDown(KEY_RSHIFT)

    if box.dragging then
        local minX, maxX = math.min(box.startX, box.currentX), math.max(box.startX, box.currentX)
        local minY, maxY = math.min(box.startY, box.currentY), math.max(box.startY, box.currentY)

        if not addMode then
            ClearSelection()
        end

        local candidates = ents.GetAll()
        for _, ent in ipairs(candidates) do
            if IsSelectableEntity(ent) then
                local screen = ent:WorldSpaceCenter():ToScreen()
                if screen.visible and screen.x >= minX and screen.x <= maxX and screen.y >= minY and screen.y <= maxY then
                    AddToSelection(ent)
                end
            end
        end
    else
        local tr = self:GetCursorTrace()
        if IsSelectableEntity(tr.Entity) then
            if not addMode then
                ClearSelection()
            end
            if addMode and gm3_selectedEntities[tr.Entity] then
                RemoveFromSelection(tr.Entity)
            else
                AddToSelection(tr.Entity)
            end
        elseif not addMode then
            ClearSelection()
        end
    end

    box.active = false
    box.dragging = false
end

function gm3ZeusCam:OpenContextMenu()
    if IsValid(gm3_contextMenu) then
        gm3_contextMenu:Remove()
    end

    local menu = vgui.Create("lyx.Menu2")
    gm3_contextMenu = menu
    gm3_lastContextTrace = self:GetCursorTrace()
    if gm3_lastContextTrace and not gm3_lastContextTrace.Hit then
        gm3_lastContextTrace = nil
    end
    menu.OnRemove = function()
        if gm3_contextMenu == menu then
            gm3_contextMenu = nil
        end
        gm3_lastContextTrace = nil
    end

    if gm3_selectionCount > 0 then
        local hasNPCs = SelectionHasNPCs()
        local hasPlayers = SelectionHasPlayers()
        local hasProps = SelectionHasProps()

        local removeOption = menu:AddOption("Remove Selected", function()
            self:RemoveSelectedEntities()
        end)
        removeOption:SetIcon("icon16/delete.png")

        if hasNPCs then
            menu:AddSpacer()
            menu:AddOption("NPCs → Camera", function()
                self:SendNPCsToCamera()
            end):SetIcon("icon16/arrow_up.png")

            menu:AddOption("NPCs → Cursor", function()
                self:SendNPCsToCursor(gm3_lastContextTrace)
            end):SetIcon("icon16/arrow_out.png")

            menu:AddOption("NPCs → Stop", function()
                self:StopSelectedNPCs()
            end):SetIcon("icon16/control_pause.png")
            
            menu:AddOption("NPCs → Heal", function()
                self:HealNPCs()
            end):SetIcon("icon16/heart.png")

            local formationMenu, parentOption = menu:AddSubMenu("NPC Formations")
            parentOption:SetIcon("icon16/chart_line.png")
            formationMenu:AddOption("Line", function()
                self:SendFormationCommand("line", gm3_lastContextTrace)
            end):SetIcon("icon16/shape_align_left.png")
            formationMenu:AddOption("Column", function()
                self:SendFormationCommand("column", gm3_lastContextTrace)
            end):SetIcon("icon16/shape_align_bottom.png")
            formationMenu:AddOption("Wedge", function()
                self:SendFormationCommand("wedge", gm3_lastContextTrace)
            end):SetIcon("icon16/shape_move_forwards.png")
            formationMenu:AddOption("Circle", function()
                self:SendFormationCommand("circle", gm3_lastContextTrace)
            end):SetIcon("icon16/shape_ungroup.png")

            local behaviorMenu, behaviorOption = menu:AddSubMenu("NPC Behavior")
            behaviorOption:SetIcon("icon16/cog.png")
            behaviorMenu:AddOption("Hold Position", function()
                self:SetNPCState("hold")
            end):SetIcon("icon16/flag_red.png")
            behaviorMenu:AddOption("Defensive", function()
                self:SetNPCState("defend")
            end):SetIcon("icon16/lock.png")
            behaviorMenu:AddOption("Free Roam", function()
                self:SetNPCState("patrol")
            end):SetIcon("icon16/world.png")
            behaviorMenu:AddOption("Aggressive", function()
                self:SetNPCState("aggressive")
            end):SetIcon("icon16/exclamation.png")

            local areaMenu, areaOption = menu:AddSubMenu("Area Control")
            areaOption:SetIcon("icon16/shape_handles.png")
            areaMenu:AddOption("Defense Zone · Small", function()
                self:CreateDefenseZone(300, "defensive", gm3_lastContextTrace)
            end):SetIcon("icon16/shield.png")
            areaMenu:AddOption("Defense Zone · Large", function()
                self:CreateDefenseZone(600, "aggressive", gm3_lastContextTrace)
            end):SetIcon("icon16/shield_add.png")
            areaMenu:AddOption("Begin Waypoint Mode", function()
                self:SetWaypointMode(true)
            end):SetIcon("icon16/map_edit.png")
        end

        if hasPlayers then
            menu:AddSpacer()
            menu:AddOption("Players → Camera", function()
                self:SendPlayersToCamera()
            end):SetIcon("icon16/user_go.png")

            menu:AddOption("Players → Cursor", function()
                self:SendPlayersToCursor(gm3_lastContextTrace)
            end):SetIcon("icon16/user_green.png")

            local interactMenu, interactOption = menu:AddSubMenu("Player Interactions")
            interactOption:SetIcon("icon16/group.png")
            interactMenu:AddOption("Inspire (HP + Armor)", function()
                self:SendPlayerBuff()
            end):SetIcon("icon16/heart.png")
            interactMenu:AddOption("Screen Message (Selected)", function()
                self:OpenScreenMessagePrompt(true)
            end):SetIcon("icon16/comment_edit.png")
        end

        if hasProps then
            menu:AddSpacer()
            menu:AddOption("Freeze Props", function()
                self:TogglePropsFrozen(true)
            end):SetIcon("icon16/asterisk_orange.png")

            menu:AddOption("Unfreeze Props", function()
                self:TogglePropsFrozen(false)
            end):SetIcon("icon16/asterisk_yellow.png")

            menu:AddOption("Props → Camera", function()
                self:SendPropsToCamera()
            end):SetIcon("icon16/box.png")

            menu:AddOption("Props → Cursor", function()
                self:SendPropsToCursor(gm3_lastContextTrace)
            end):SetIcon("icon16/box_world.png")
        end
    end

    if gm3_selectionCount > 0 then
        menu:AddSpacer()
        local groupMenu, groupOption = menu:AddSubMenu("Selection Groups")
        groupOption:SetIcon("icon16/group.png")
        for slot = 1, 3 do
            groupMenu:AddOption("Save Group " .. slot, function()
                self:SaveSelectionGroup(slot)
            end):SetIcon("icon16/disk.png")
            groupMenu:AddOption("Load Group " .. slot, function()
                self:LoadSelectionGroup(slot)
            end):SetIcon("icon16/folder.png")
        end

        menu:AddOption("Focus Camera on Selection", function()
            self:FocusSelection()
        end):SetIcon("icon16/camera.png")
    end

    menu:AddSpacer()
    menu:AddOption("Shockwave at Cursor", function()
        self:ShockwaveAtCursor(gm3_lastContextTrace)
    end):SetIcon("icon16/lightning.png")

    local fireMenu, fireOption = menu:AddSubMenu("Fire Support")
    fireOption:SetIcon("icon16/bomb.png")
    for key, profile in pairs(gm3_fireSupportProfiles) do
        fireMenu:AddOption(profile.label, function()
            self:CallFireSupport(key, gm3_lastContextTrace)
        end):SetIcon("icon16/arrow_down.png")
    end

    local logisticsMenu, logOption = menu:AddSubMenu("Logistics")
    logOption:SetIcon("icon16/box.png")
    for _, option in ipairs(gm3_logisticsOptions) do
        local opt = logisticsMenu:AddOption(option.label, function()
            self:RequestSupplyDrop(option.key, gm3_lastContextTrace)
        end)
        opt:SetIcon(option.icon or "icon16/box.png")
    end

    local intelMenu, intelOption = menu:AddSubMenu("Recon Tools")
    intelOption:SetIcon("icon16/radar.png")
    intelMenu:AddOption("Recon Pulse (Short)", function()
        self:RequestReconPulse(400, gm3_lastContextTrace)
    end):SetIcon("icon16/eye.png")
    intelMenu:AddOption("Recon Pulse (Long)", function()
        self:RequestReconPulse(800, gm3_lastContextTrace)
    end):SetIcon("icon16/eye.png")
    intelMenu:AddOption("Recon Pulse (Wide)", function()
        self:RequestReconPulse(1200, gm3_lastContextTrace)
    end):SetIcon("icon16/world.png")
    intelMenu:AddOption("Sensor Beacon (45s)", function()
        self:DeploySensorBeacon(45, 600, gm3_lastContextTrace)
    end):SetIcon("icon16/transmit_blue.png")
    intelMenu:AddOption("Sensor Beacon (120s)", function()
        self:DeploySensorBeacon(120, 900, gm3_lastContextTrace)
    end):SetIcon("icon16/transmit.png")

    menu:AddOption("Rapid Redeploy", function()
        self:RedeploySelection(gm3_lastContextTrace)
    end):SetIcon("icon16/arrow_refresh.png")

    menu:AddOption("Place Signal Marker", function()
        self:PromptSignalMarker(gm3_lastContextTrace)
    end):SetIcon("icon16/flag_red.png")

    menu:AddOption("Clear Selection", function()
        ClearSelection()
    end):SetIcon("icon16/cancel.png")

    menu:AddOption("Broadcast Screen Message", function()
        self:OpenScreenMessagePrompt(false)
    end):SetIcon("icon16/comment.png")

    menu:Open()
    local x, y = self:GetCursorPos()
    menu:SetPos(x, y)
end

function gm3ZeusCam:SendSelectionCommand(netMsg, vec, extraWriter)
    local selection = GetSelectionList()
    if #selection == 0 then
        notification.AddLegacy("No entities selected.", NOTIFY_HINT, 2)
        return
    end
    
    lyx:NetSend(netMsg, function()
        net.WriteUInt(#selection, 12)
        for _, ent in ipairs(selection) do
            net.WriteEntity(ent)
        end
        if vec then
            net.WriteVector(vec)
        end
        if extraWriter then
            extraWriter()
        end
    end)
    return selection
end

function gm3ZeusCam:RemoveSelectedEntities()
    self:SendSelectionCommand("gm3ZeusCam_removeSelected")
end

function gm3ZeusCam:SendNPCsToCamera()
    if not SelectionHasNPCs() then
        notification.AddLegacy("Selection has no NPCs.", NOTIFY_HINT, 2)
        return
    end
    local selection = self:SendSelectionCommand("gm3ZeusCam_moveToCamera", CamPos)
    if selection then
        self:TrackMoveOrders(CamPos, selection, true)
        self:CreateRouteVisualFor(selection, {
            routeType = "move",
            nodes = {CamPos},
            label = "Camera",
            thickness = 5,
            persistent = true
        })
    end
end

function gm3ZeusCam:SendNPCsToCursor(traceOverride)
    if not SelectionHasNPCs() then
        notification.AddLegacy("Selection has no NPCs.", NOTIFY_HINT, 2)
        return
    end
    local tr = gm3_GetEffectiveTrace(traceOverride)
    if not tr.Hit then
        notification.AddLegacy("No target position under cursor.", NOTIFY_ERROR, 2)
        return
    end
    local selection = self:SendSelectionCommand("gm3ZeusCam_moveToClick", tr.HitPos)
    if selection then
        self:TrackMoveOrders(tr.HitPos, selection, true)
        self:CreateRouteVisualFor(selection, {
            routeType = "move",
            nodes = {tr.HitPos},
            label = "Cursor",
            thickness = 5,
            persistent = true
        })
    end
end

function gm3ZeusCam:SendPlayersToCamera()
    if not SelectionHasPlayers() then
        notification.AddLegacy("Selection has no players.", NOTIFY_HINT, 2)
        return
    end
    local selection = self:SendSelectionCommand("gm3ZeusCam_playersToCamera", CamPos)
    if selection then
        self:TrackMoveOrders(CamPos, selection, true)
        self:CreateRouteVisualFor(selection, {
            routeType = "move",
            nodes = {CamPos},
            label = "Camera",
            persistent = true
        })
    end
end

function gm3ZeusCam:SendPlayersToCursor(traceOverride)
    if not SelectionHasPlayers() then
        notification.AddLegacy("Selection has no players.", NOTIFY_HINT, 2)
        return
    end
    local tr = gm3_GetEffectiveTrace(traceOverride)
    if not tr.Hit then
        notification.AddLegacy("No target position under cursor.", NOTIFY_ERROR, 2)
        return
    end
    local selection = self:SendSelectionCommand("gm3ZeusCam_playersToCursor", tr.HitPos)
    if selection then
        self:TrackMoveOrders(tr.HitPos, selection, true)
        self:CreateRouteVisualFor(selection, {
            routeType = "move",
            nodes = {tr.HitPos},
            label = "Cursor",
            persistent = true
        })
    end
end

function gm3ZeusCam:SendPlayerBuff()
    local targets = {}
    for _, ent in ipairs(GetSelectionList()) do
        if IsValid(ent) and ent:IsPlayer() and ent ~= LocalPlayer() then
            table.insert(targets, ent)
        end
    end
    if #targets == 0 then
        notification.AddLegacy("Select players to inspire.", NOTIFY_HINT, 2)
        return
    end
    lyx:NetSend("gm3ZeusCam_buffPlayers", function()
        net.WriteUInt(#targets, 8)
        for _, ply in ipairs(targets) do
            net.WriteEntity(ply)
        end
    end)
end

function gm3ZeusCam:StopSelectedNPCs()
    if not SelectionHasNPCs() then
        notification.AddLegacy("Selection has no NPCs.", NOTIFY_HINT, 2)
        return
    end
    self:SendSelectionCommand("gm3ZeusCam_stopNPCs")
end

function gm3ZeusCam:OpenScreenMessagePrompt(targetPlayersOnly)
    local targets = {}
    if targetPlayersOnly then
        for _, ent in ipairs(GetSelectionList()) do
            if IsValid(ent) and ent:IsPlayer() and ent ~= LocalPlayer() then
                table.insert(targets, ent)
            end
        end
        if #targets == 0 then
            notification.AddLegacy("Select players to target a message.", NOTIFY_HINT, 2)
            return
        end
    end

    local frame = vgui.Create("lyx.Frame2")
    frame:SetTitle(targetPlayersOnly and "Message Selected Players" or "Broadcast Screen Message")
    frame:SetSize(540, 400)
    frame:Center()
    frame:MakePopup()
    frame:DockPadding(12, 40, 12, 12)

    local textEntry = vgui.Create("DTextEntry", frame)
    textEntry:Dock(TOP)
    textEntry:DockMargin(0, 0, 0, 8)
    textEntry:SetTall(70)
    textEntry:SetMultiline(true)
    textEntry:SetPlaceholderText("Enter message...")

    local selectedColor = table.Copy(gm3_screenMessageColors[1].color)

    local contentPanel = vgui.Create("DPanel", frame)
    contentPanel:Dock(FILL)
    contentPanel.Paint = nil

    local colorPicker = vgui.Create("lyx.ColorPicker2", contentPanel)
    colorPicker:Dock(LEFT)
    colorPicker:SetWide(lyx.Scale(220))
    colorPicker:DockMargin(0, 0, 10, 0)
    colorPicker:SetColor(selectedColor)

    local controlsPanel = vgui.Create("DPanel", contentPanel)
    controlsPanel:Dock(FILL)
    controlsPanel.Paint = nil

    local colorPreview = vgui.Create("DPanel", controlsPanel)
    colorPreview:Dock(TOP)
    colorPreview:SetTall(lyx.Scale(60))
    colorPreview:DockMargin(0, 0, 0, 5)
    colorPreview.Paint = function(s, w, h)
        draw.RoundedBox(6, 0, 0, w, h, selectedColor)
    end

    local colorCombo = vgui.Create("DComboBox", controlsPanel)
    colorCombo:Dock(TOP)
    colorCombo:DockMargin(0, 0, 0, 5)
    for _, entry in ipairs(gm3_screenMessageColors) do
        colorCombo:AddChoice(entry.name, entry.color, entry == gm3_screenMessageColors[1])
        if entry == gm3_screenMessageColors[1] then
            colorCombo:SetValue(entry.name)
        end
    end
    colorCombo.OnSelect = function(_, _, _, data)
        if not data then return end
        selectedColor.r = data.r
        selectedColor.g = data.g
        selectedColor.b = data.b
        colorPicker:SetColor(selectedColor)
        colorPreview:InvalidateLayout(true)
    end

    local alphaSlider = vgui.Create("DNumSlider", controlsPanel)
    alphaSlider:Dock(TOP)
    alphaSlider:DockMargin(0, 0, 0, 8)
    alphaSlider:SetDecimals(0)
    alphaSlider:SetMin(0)
    alphaSlider:SetMax(255)
    alphaSlider:SetValue(selectedColor.a or 255)
    alphaSlider:SetText("Alpha")
    alphaSlider.OnValueChanged = function(_, value)
        selectedColor.a = math.Clamp(math.floor(value or 255), 0, 255)
        colorPreview:InvalidateLayout(true)
    end

    local durationSlider = vgui.Create("DNumSlider", controlsPanel)
    durationSlider:Dock(TOP)
    durationSlider:DockMargin(0, 0, 0, 5)
    durationSlider:SetDecimals(0)
    durationSlider:SetMin(3)
    durationSlider:SetMax(20)
    durationSlider:SetValue(6)
    durationSlider:SetText("Duration (seconds)")

    local fadeSlider = vgui.Create("DNumSlider", controlsPanel)
    fadeSlider:Dock(TOP)
    fadeSlider:DockMargin(0, 0, 0, 5)
    fadeSlider:SetDecimals(0)
    fadeSlider:SetMin(50)
    fadeSlider:SetMax(200)
    fadeSlider:SetValue(90)
    fadeSlider:SetText("Fade Speed")

    colorPicker.OnChange = function(_, col)
        selectedColor.r = col.r
        selectedColor.g = col.g
        selectedColor.b = col.b
        colorPreview:InvalidateLayout(true)
    end

    local buttonBar = vgui.Create("DPanel", frame)
    buttonBar:Dock(BOTTOM)
    buttonBar:SetTall(45)
    buttonBar.Paint = nil

    local sendBtn = vgui.Create("lyx.TextButton2", buttonBar)
    sendBtn:Dock(RIGHT)
    sendBtn:SetText("Send")
    sendBtn:SetWide(160)
    sendBtn.DoClick = function()
        local msg = string.Trim(textEntry:GetValue() or "")
        if msg == "" then
            notification.AddLegacy("Message cannot be empty.", NOTIFY_HINT, 2)
            return
        end
        lyx:NetSend("gm3ZeusCam_screenMessage", function()
            net.WriteBool(targetPlayersOnly and true or false)
            if targetPlayersOnly then
                net.WriteUInt(#targets, 8)
                for _, ply in ipairs(targets) do
                    net.WriteEntity(ply)
                end
            end
            net.WriteString(msg)
            net.WriteColor(selectedColor or gm3_screenMessageColors[1].color)
            net.WriteFloat(durationSlider:GetValue())
            net.WriteFloat(fadeSlider:GetValue())
        end)

        frame:Close()
    end

    local cancelBtn = vgui.Create("lyx.TextButton2", buttonBar)
    cancelBtn:Dock(LEFT)
    cancelBtn:SetWide(140)
    cancelBtn:SetText("Cancel")
    cancelBtn.DoClick = function()
        frame:Close()
    end
end

function gm3ZeusCam:TogglePropsFrozen(freeze)
    if not SelectionHasProps() then
        notification.AddLegacy("Selection has no props.", NOTIFY_HINT, 2)
        return
    end
    self:SendSelectionCommand("gm3ZeusCam_freezeProps", nil, function()
        net.WriteBool(freeze and true or false)
    end)
end

function gm3ZeusCam:SendPropsToCamera()
    if not SelectionHasProps() then
        notification.AddLegacy("Selection has no props.", NOTIFY_HINT, 2)
        return
    end
    self:SendSelectionCommand("gm3ZeusCam_propsToCamera", CamPos)
end

function gm3ZeusCam:SendPropsToCursor(traceOverride)
    if not SelectionHasProps() then
        notification.AddLegacy("Selection has no props.", NOTIFY_HINT, 2)
        return
    end
    local tr = gm3_GetEffectiveTrace(traceOverride)
    if not tr.Hit then
        notification.AddLegacy("No target position under cursor.", NOTIFY_ERROR, 2)
        return
    end
    self:SendSelectionCommand("gm3ZeusCam_propsToCursor", tr.HitPos)
end

function gm3ZeusCam:HealNPCs()
    if not SelectionHasNPCs() then
        notification.AddLegacy("Selection has no NPCs.", NOTIFY_HINT, 2)
        return
    end
    self:SendSelectionCommand("gm3ZeusCam_healNPCs")
end

function gm3ZeusCam:SetNPCState(state)
    if not SelectionHasNPCs() then
        notification.AddLegacy("Selection has no NPCs.", NOTIFY_HINT, 2)
        return
    end
    self:SendSelectionCommand("gm3ZeusCam_setNPCState", nil, function()
        net.WriteString(state or "")
    end)
end

function gm3ZeusCam:CreateCamPanel(bool)
    if bool then
        if (gm3CamPanel) then
            gm3CamPanel:Remove()
            gm3CamPanel = nil
        end

        -- draw a panel that covers the whole screen but is transparent
        gm3CamPanel = vgui.Create("DPanel")
        gm3CamPanel:SetSize(ScrW(), ScrH())
        gm3CamPanel:SetPos(0, 0)
        gm3CamPanel.Paint = function(self, w, h)
            surface.SetDrawColor( 0, 0, 0, 0)
            surface.DrawRect( 0, 0, w, h )
        end
        
        -- draw a bottom bar
        local gm3CamPanelBottom = vgui.Create("DPanel", gm3CamPanel)
        gm3CamPanelBottom:SetSize(ScrW(), lyx.Scale(90))
        gm3CamPanelBottom:SetPos(0, ScrH() - lyx.Scale(90))
        gm3CamPanelBottom.Paint = function(self, w, h)
            surface.SetDrawColor( 37, 36, 36)
            surface.DrawRect( 0, 0, w, h )
        end

        local cameraToggle = vgui.Create("lyx.TextButton2", gm3CamPanelBottom)
        cameraToggle:Dock(RIGHT)
        cameraToggle:DockMargin(lyx.Scale(5), lyx.Scale(5), lyx.Scale(5), lyx.Scale(5))
        cameraToggle:SetText("Toggle Zeus")
        cameraToggle:SetWide(lyx.Scale(150))
        cameraToggle:SetBackgroundColor(Color(70,196,91))
        cameraToggle.DoClick = function()
            EnabledCam = !EnabledCam
            EnabledCamConfirm = !EnabledCamConfirm
        
            gm3ZeusCam:CreateCameraHooks(EnabledCam)
        end

        local hint = vgui.Create("DLabel", gm3CamPanelBottom)
        hint:Dock(LEFT)
        hint:DockMargin(lyx.Scale(10), 0, 0, 0)
        hint:SetFont("GM3_Cam_Subtitle")
        hint:SetTextColor(color_white)
        hint:SetText("Hold ALT to show cursor and select entities.")
        hint:SetWide(lyx.Scale(260))

        local buttonScroll = vgui.Create("DScrollPanel", gm3CamPanelBottom)
        buttonScroll:Dock(FILL)
        buttonScroll:DockMargin(lyx.Scale(10), lyx.Scale(5), lyx.Scale(10), lyx.Scale(5))
        local buttonLayout = vgui.Create("DIconLayout", buttonScroll)
        buttonLayout:Dock(FILL)
        buttonLayout:SetSpaceX(lyx.Scale(6))
        buttonLayout:SetSpaceY(lyx.Scale(6))

        local function AddToolbarButton(text, color, width, callback)
            local btn = buttonLayout:Add("lyx.TextButton2")
            btn:SetSize(width or lyx.Scale(150), lyx.Scale(36))
            btn:SetText(text)
            btn:SetBackgroundColor(color)
            btn.DoClick = callback
            return btn
        end

        AddToolbarButton("Clear Selection", Color(90, 90, 90), nil, function()
            ClearSelection()
        end)
        AddToolbarButton("Remove Selected", Color(255, 0, 0), nil, function()
            gm3ZeusCam:RemoveSelectedEntities()
        end)
        AddToolbarButton("Screen Message", Color(50, 120, 200), lyx.Scale(160), function()
            gm3ZeusCam:OpenScreenMessagePrompt(false)
        end)
        AddToolbarButton("Camera Marks", Color(110, 90, 160), nil, function()
            gm3ZeusCam:OpenBookmarkMenu()
        end)
        self.FollowButton = AddToolbarButton("Follow (OFF)", Color(90, 90, 90), nil, function()
            if gm3_followTarget then
                gm3ZeusCam:ClearFollowTarget()
            else
                gm3ZeusCam:StartFollowSelection()
            end
        end)
        AddToolbarButton("Rapid Redeploy", Color(230, 160, 60), lyx.Scale(170), function()
            gm3ZeusCam:RedeploySelection(gm3_lastContextTrace)
        end)
        AddToolbarButton("Signal Marker", Color(200, 90, 140), nil, function()
            gm3ZeusCam:PromptSignalMarker(gm3_lastContextTrace)
        end)
        self.WaypointModeButton = AddToolbarButton("Waypoint Mode (OFF)", Color(90, 90, 90), nil, function()
            gm3ZeusCam:SetWaypointMode(not gm3_waypointMode)
        end)
        self.WaypointLoopButton = AddToolbarButton("Loop Patrol (ON)", Color(50, 160, 80), nil, function()
            gm3ZeusCam:ToggleWaypointLoop()
        end)
        AddToolbarButton("Fire Support", Color(200, 120, 40), nil, function()
            local quickTrace = gm3_lastContextTrace or gm3ZeusCam:GetCursorTrace()
            if quickTrace and not quickTrace.Hit then
                quickTrace = nil
            end
            gm3ZeusCam._pendingFireSupportTrace = quickTrace
            gm3ZeusCam:OpenFireSupportPanel()
        end)

        gm3ZeusCam:CreateSpawnToolbar(gm3CamPanel)

    else
        if IsValid(gm3CamPanel) then
            gm3CamPanel:Remove()
            gm3CamPanel = nil
        end
        if IsValid(gm3ZeusCam.SpawnToolbar) then
            gm3ZeusCam.SpawnToolbar:Remove()
            gm3ZeusCam.SpawnToolbar = nil
        end
        gm3ZeusCam.FireSupportSlider = nil
        gm3ZeusCam.SpawnArtillerySlider = nil
        if IsValid(gm3ZeusCam.FireSupportPanel) then
            gm3ZeusCam.FireSupportPanel:Remove()
            gm3ZeusCam.FireSupportPanel = nil
        end
    end
end

function gm3ZeusCam:CreateCameraHooks(bool)
    if bool then
        self:ClearHooks()
        self:SetSpawnMode(false)
        ClearSelection()
        gm3_selectionBox.active = false
        gm3_hoveredEntity = nil
        gm3_rightMouseHeld = false
        gm3ZeusCam:SetCursorMode(false)

        gm3ZeusCam:AddHook("CalcView", function(ply, pos, angles, fov)
            local view = {}
            if (CamEnabled) then
                view = {
                    origin = CamPos,
                    angles = CamAngle,
                    fov = CamFOV,
                    drawviewer = true
                }
                return view
            else
                view = {
                    origin = pos,
                    angles = angles,
                    fov = fov,
                    drawviewer = false
                }
            end
        end)

        gm3ZeusCam:AddHook("Tick", function()
            local ply = LocalPlayer()
            if not IsValid(ply) then return end
            if (EnabledCamConfirm) then
                CamEnabled = true
            else
                CamEnabled = false
                CamAngle = ply:EyeAngles()
                CamOriginalAngle = ply:EyeAngles()
                CamPos = ply:EyePos()
            end
        
            CamOriginalAngle = ply:EyeAngles() -- keep sync with player view
            
            -- send ConVar info to regular vars as to update
            CamFOV = CVCamFOV:GetFloat()
            CamSpeed = CVCamSpeed:GetFloat()
            CamSensitivity = CVCamSens:GetFloat()
            CamLock = CVCamLock:GetBool()
            
        end)

        gm3ZeusCam:AddHook("CreateMove", function(cmd, ply)
            if (EnabledCam) then
                local SideMove = cmd:GetSideMove()
                local ForwardMove = cmd:GetForwardMove()
                local UpMove = cmd:GetUpMove()
                if (not CamLock) then
                    local CamSpeedActual = CamSpeed
                    cmd:SetSideMove(0)
                    cmd:SetForwardMove(0)
                    cmd:SetUpMove(0)
                    cmd:ClearMovement()
                    
                    cmd:SetViewAngles(CamOriginalAngle)
                    if not gm3_cursorMode then
                        CamAngle = (CamAngle + Angle(cmd:GetMouseY() * CamSensitivity, cmd:GetMouseX() * -CamSensitivity, 0))
                        CamAngle.p = math.Clamp(CamAngle.p, -85, 85)
                        CamAngle.r = 0
                    end
        
                    -- SPEED
                    if (cmd:KeyDown(IN_SPEED)) then
                        CamSpeedActual = CamSpeed * 2
                    end
                    if (cmd:KeyDown(IN_WALK)) then
                        CamSpeedActual = CamSpeed / 2
                    end
                    
                    -- UP AND DOWN
                    if (cmd:KeyDown(IN_JUMP)) then
                        CamPos = CamPos + Vector(0,0,CamSpeedActual)
                    end
                    if (cmd:KeyDown(IN_DUCK)) then
                        CamPos = CamPos - Vector(0,0,CamSpeedActual)
                    end
                        
                    -- BASIC INPUT CONTROLS
                    if (cmd:KeyDown(IN_FORWARD)) then
                        CamPos = CamPos + (CamAngle:Forward() * CamSpeedActual)
                    end
                    if (cmd:KeyDown(IN_BACK)) then
                        CamPos = CamPos - (CamAngle:Forward() * CamSpeedActual)
                    end
                    if (cmd:KeyDown(IN_MOVERIGHT)) then
                        CamPos = CamPos + (CamAngle:Right() * CamSpeedActual)
                    end
                    if (cmd:KeyDown(IN_MOVELEFT)) then
                        CamPos = CamPos - (CamAngle:Right() * CamSpeedActual)
                    end
                    
                    -- ensure that the player itself cant walk, use, jump, duck or fire while in static freecam
                    cmd:RemoveKey(IN_FORWARD)
                    cmd:RemoveKey(IN_BACK)
                    cmd:RemoveKey(IN_MOVELEFT)
                    cmd:RemoveKey(IN_MOVERIGHT)
                    
                    cmd:RemoveKey(IN_USE)
                    cmd:RemoveKey(IN_JUMP)
                    cmd:RemoveKey(IN_DUCK)
                    cmd:RemoveKey(IN_ATTACK)
                    cmd:RemoveKey(IN_ATTACK2)
                    -- disable scrolling
                    cmd:RemoveKey(IN_RELOAD)
                    -- disbale middle mouse button
                    cmd:RemoveKey(IN_WALK)
                    cmd:RemoveKey(IN_WEAPON1)
                    cmd:RemoveKey(IN_WEAPON2)
                    cmd:RemoveKey(IN_BULLRUSH)
                    -- in zoom
                    cmd:RemoveKey(IN_ZOOM)
                    -- in alt
                    cmd:RemoveKey(IN_ALT1)
                    cmd:RemoveKey(IN_ALT2)

                else
                    cmd:SetSideMove(SideMove)
                    cmd:SetForwardMove(ForwardMove)
                    cmd:SetUpMove(UpMove)
                end
            end
        end)

        gm3ZeusCam:AddHook("Think", function()
            if not EnabledCam then return end

            local shouldCursor = gm3_spawnMode or gm3_waypointMode or input.IsKeyDown(KEY_LALT) or input.IsKeyDown(KEY_RALT)
            gm3ZeusCam:SetCursorMode(shouldCursor)
            UpdateRouteVisualProgress()
            if gm3_followTarget then
                if not IsValid(gm3_followTarget) then
                    gm3ZeusCam:ClearFollowTarget()
                else
                    local desired = gm3_followTarget:WorldSpaceCenter() + gm3_followOffset
                    CamPos = LerpVector(FrameTime() * 4, CamPos, desired)
                    if gm3_followYaw then
                        local ang = Angle(CamAngle)
                        ang.y = math.NormalizeAngle(gm3_followYaw)
                        CamAngle = LerpAngle(FrameTime() * 2, CamAngle, ang)
                    end
                end
            end

            if gm3_spawnMode and gm3_cursorMode then
                if input.IsMouseDown(MOUSE_LEFT) and CurTime() > gm3_spawnNextClick then
                    gm3_spawnNextClick = CurTime() + 0.35
                    gm3ZeusCam:SpawnAtCursor()
                end
                return
            end

            if gm3_waypointMode and gm3_cursorMode then
                gm3ZeusCam:HandleWaypointInput()
                return
            end

            if not gm3_cursorMode then
                return
            end

            local cursorX, cursorY = gm3ZeusCam:GetCursorPos()
            if input.IsMouseDown(MOUSE_LEFT) then
                if not gm3_selectionBox.active then
                    gm3_selectionBox.active = true
                    gm3_selectionBox.dragging = false
                    gm3_selectionBox.startX = cursorX
                    gm3_selectionBox.startY = cursorY
                end
                gm3_selectionBox.currentX = cursorX
                gm3_selectionBox.currentY = cursorY
                if not gm3_selectionBox.dragging then
                    if math.abs(gm3_selectionBox.startX - cursorX) > 4 or math.abs(gm3_selectionBox.startY - cursorY) > 4 then
                        gm3_selectionBox.dragging = true
                    end
                end
            elseif gm3_selectionBox.active then
                gm3ZeusCam:FinalizeSelectionBox()
            end

            local trace = gm3ZeusCam:GetCursorTrace()
            if IsSelectableEntity(trace.Entity) then
                gm3_hoveredEntity = trace.Entity
            else
                gm3_hoveredEntity = nil
            end

            if input.IsMouseDown(MOUSE_RIGHT) then
                gm3_rightMouseHeld = true
            elseif gm3_rightMouseHeld then
                gm3_rightMouseHeld = false
                gm3ZeusCam:OpenContextMenu()
            end
        end)

        gm3ZeusCam:AddHook("PostDrawTranslucentRenderables", function()
            if not EnabledCam then return end
            CleanupMoveOrders()
            render.SetColorMaterial()

            for _, order in ipairs(gm3_moveOrders) do
                local ent = order.ent
                if not IsValid(ent) then continue end
                local startPos = ent:WorldSpaceCenter()
                local endPos = order.target
                local color = GetSelectionColor(ent)
                local elevatedStart = startPos + Vector(0, 0, 8)
                local elevatedEnd = endPos + Vector(0, 0, 8)
                DrawThickBeam(elevatedStart, elevatedEnd, 6, Color(color.r, color.g, color.b, 190))

                local dist = math.Round(startPos:Distance(endPos))
                local mid = LerpVector(0.5, startPos, endPos) + Vector(0, 0, 10)
                cam.Start3D2D(mid, Angle(0, CamAngle.y - 90, 90), 0.12)
                    draw.RoundedBox(5, -70, -14, 140, 28, Color(20, 20, 20, 225))
                    draw.SimpleText(dist .. "u", "GM3_Cam_Subtitle", 0, 0, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
                cam.End3D2D()
            end

            for ent, route in pairs(gm3_routeVisuals) do
                if not IsValid(ent) or not istable(route.nodes) or #route.nodes == 0 then
                    gm3_routeVisuals[ent] = nil
                else
                    local totalNodes = #route.nodes
                    local routeColor = route.color or gm3_routeColors.default
                    local up = Vector(0, 0, 8)
                    local entPos = ent:WorldSpaceCenter()
                    local startIdx = math.Clamp(route.currentIndex or 1, 1, totalNodes)
                    local segments = route.loop and totalNodes or (totalNodes - startIdx + 1)
                    local prev = entPos
                    local lastPos = entPos

                    if segments > 0 then
                        for seg = 0, segments - 1 do
                            local idx = ((startIdx + seg - 1) % totalNodes) + 1
                            local node = route.nodes[idx]
                            if not isvector(node) then break end
                            local alpha = seg == 0 and 240 or math.max(200 - seg * 35, 90)
                            local beamColor = Color(routeColor.r, routeColor.g, routeColor.b, alpha)
                            DrawThickBeam(prev + up, node + up, (route.thickness or 4) + (seg == 0 and 1 or 0), beamColor)
                            render.DrawWireframeSphere(node + Vector(0, 0, 4), 12 + seg * 1.2, 12, 12, beamColor, true)
                            cam.Start3D2D(node + Vector(0, 0, 16), Angle(0, CamAngle.y - 90, 90), 0.08)
                                draw.RoundedBox(4, -28, -12, 56, 24, Color(15, 15, 15, 200))
                                draw.SimpleText("WP " .. idx, "GM3_Cam_Subtitle", 0, 0, Color(255, 255, 255, alpha), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
                            cam.End3D2D()
                            prev = node
                            lastPos = node
                        end

                        if route.loop and totalNodes > 1 then
                            local loopColor = Color(routeColor.r, routeColor.g, routeColor.b, 110)
                            DrawThickBeam(lastPos + up, entPos + up, route.thickness or 4, loopColor)
                        end
                    end

                    cam.Start3D2D((lastPos or entPos) + Vector(0, 0, 30), Angle(0, CamAngle.y - 90, 90), 0.09)
                        draw.RoundedBox(4, -80, -14, 160, 28, Color(10, 10, 10, 230))
                        draw.SimpleText(route.label or "Route", "GM3_Cam_Subtitle", 0, 0, routeColor, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
                    cam.End3D2D()
                end
            end

            local now = CurTime()
            for i = #gm3_signalMarkers, 1, -1 do
                local marker = gm3_signalMarkers[i]
                if not marker or marker.expire <= now then
                    table.remove(gm3_signalMarkers, i)
                else
                    local col = marker.color or Color(255, 200, 120)
                    local pos = marker.pos + Vector(0, 0, 4)
                    render.DrawWireframeSphere(pos, 24, 12, 12, col, true)
                    cam.Start3D2D(pos + Vector(0, 0, 42), Angle(0, CamAngle.y - 90, 90), 0.1)
                        draw.RoundedBox(6, -80, -16, 160, 32, Color(10, 10, 10, 220))
                        draw.SimpleText(marker.label or "Marker", "GM3_Cam_Subtitle", 0, 0, col, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
                    cam.End3D2D()
                end
            end

            if gm3_waypointMode then
                local lastPos
                for idx, waypoint in ipairs(gm3_waypoints) do
                    render.DrawWireframeSphere(waypoint + Vector(0, 0, 4), 12, 10, 10, Color(60, 180, 255, 220), true)
                    if lastPos then
                        DrawThickBeam(lastPos + Vector(0, 0, 6), waypoint + Vector(0, 0, 6), 4, Color(60, 180, 255, 200))
                    end
                    cam.Start3D2D(waypoint + Vector(0, 0, 16), Angle(0, CamAngle.y - 90, 90), 0.08)
                        draw.RoundedBox(4, -22, -12, 44, 24, Color(10, 10, 10, 220))
                        draw.SimpleText(idx, "GM3_Cam_Subtitle", 0, 0, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
                    cam.End3D2D()
                    lastPos = waypoint
                end
                if gm3_waypointPreviewPos then
                    render.DrawWireframeSphere(gm3_waypointPreviewPos + Vector(0, 0, 4), 12, 8, 8, Color(60, 180, 255, 160), true)
                    if lastPos then
                        DrawThickBeam(lastPos + Vector(0, 0, 6), gm3_waypointPreviewPos + Vector(0, 0, 6), 4, Color(60, 180, 255, 140))
                    end
                end
            else
                gm3_waypointPreviewPos = nil
            end

            local now = CurTime()
            for i = #gm3_reconPings, 1, -1 do
                local ping = gm3_reconPings[i]
                if not ping or ping.expire <= now then
                    table.remove(gm3_reconPings, i)
                else
                    render.DrawWireframeSphere(ping.pos + Vector(0, 0, 2), ping.radius, 18, 18, Color(50, 180, 200, 70), true)
                    for _, contact in ipairs(ping.contacts or {}) do
                        local baseColor = gm3_reconColors[contact.type or "unknown"] or gm3_reconColors.unknown
                        local c = contact.friendly and gm3_reconColors.friendly or baseColor
                        local contactPos = contact.pos + Vector(0, 0, 6)
                        render.DrawWireframeSphere(contactPos, 6, 8, 8, Color(c.r, c.g, c.b, 140), true)
                        local heading = contact.dir or vector_origin
                        local headingLen = heading:Length()
                        if headingLen > 0.01 and (contact.speed or 0) > 4 then
                            local reach = math.Clamp((contact.speed or 0) * 0.05, 10, 140)
                            local dir = headingLen > 0 and heading / headingLen or Vector()
                            DrawThickBeam(contactPos + Vector(0, 0, 2), contactPos + dir * reach + Vector(0, 0, 2), 3, Color(c.r, c.g, c.b, 180))
                        end
                        cam.Start3D2D(contactPos + Vector(0, 0, 24), Angle(0, CamAngle.y - 90, 90), 0.08)
                            draw.RoundedBox(4, -90, -12, 180, 24, Color(10, 10, 10, 220))
                            local label = contact.label or contact.class or contact.type or "?"
                            local speedInfo = math.floor(contact.speed or 0)
                            draw.SimpleText(label .. " · " .. speedInfo .. "u/s", "GM3_Cam_Subtitle", 0, 0, c, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
                        cam.End3D2D()
                    end
                end
            end

            if gm3_waypointMode and gm3_cursorMode then
                local tr = gm3ZeusCam:GetCursorTrace()
                if tr.Hit then
                    render.DrawWireframeSphere(tr.HitPos + Vector(0, 0, 2), 16, 12, 12, Color(60, 180, 255, 150), true)
                    if #gm3_waypoints > 0 then
                        local last = gm3_waypoints[#gm3_waypoints]
                        DrawThickBeam(last + Vector(0, 0, 6), tr.HitPos + Vector(0, 0, 6), 4, Color(60, 180, 255, 110))
                    end
                end
            end

            if gm3_spawnMode and gm3_cursorMode then
                local tr = gm3ZeusCam:GetCursorTrace()
                if tr.Hit then
                    render.DrawWireframeSphere(tr.HitPos + Vector(0, 0, 2), 20, 12, 12, Color(0, 200, 150, 180), true)
                end
            end
        end)

        gm3ZeusCam:AddHook("HUDPaint", function()
            if not EnabledCam then return end

            surface.SetDrawColor(37, 36, 36, 245)
            surface.DrawRect(0, 0, ScrW(), lyx.Scale(40))
            draw.SimpleText("Gamemaster 3: Zeus Mode", "GM3_Cam_Title", lyx.ScaleW(10), lyx.Scale(6), color_white, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)

            local counts = GetSelectionCounts()
            local status = string.format("Selected: %d | Players: %d | NPCs: %d | Props: %d", gm3_selectionCount, counts.players, counts.npcs, counts.props)
            draw.SimpleText(status, "GM3_Cam_Subtitle", lyx.ScaleW(10), lyx.Scale(48), color_white, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
            draw.SimpleText("Hold ALT to select · Right-click for actions", "GM3_Cam_Subtitle", lyx.ScaleW(10), lyx.Scale(70), Color(200, 200, 200), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
            if gm3_spawnMode then
                draw.SimpleText("Spawn Mode: Left click to deploy NPCs", "GM3_Cam_Subtitle", lyx.ScaleW(10), lyx.Scale(92), Color(90, 220, 170), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
            end
            local hintY = lyx.Scale(92)
            if gm3_waypointMode then
                hintY = hintY + lyx.Scale(18)
                draw.SimpleText("Waypoint Mode: LMB add nodes · RMB confirm · Backspace undo · Delete clear", "GM3_Cam_Subtitle", lyx.ScaleW(10), hintY, Color(80, 200, 255), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
                hintY = hintY + lyx.Scale(18)
                draw.SimpleText(string.format("Active nodes: %d · Loop %s", #gm3_waypoints, gm3_waypointLoop and "ON" or "OFF"), "GM3_Cam_Subtitle", lyx.ScaleW(10), hintY, Color(150, 220, 255), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
            end
            for ent, route in pairs(gm3_routeVisuals) do
                if gm3_selectedEntities[ent] and route and istable(route.nodes) and #route.nodes > 0 then
                    hintY = hintY + lyx.Scale(18)
                    local totalNodes = #route.nodes
                    local idx = math.min(route.currentIndex or 1, totalNodes)
                    local text = string.format("Route: %s (%d/%d)", route.label or "Active", idx, totalNodes)
                    draw.SimpleText(text, "GM3_Cam_Subtitle", lyx.ScaleW(10), hintY, Color(255, 235, 160), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
                    break
                end
            end
            local selection = GetSelectionList()

            if gm3_selectionBox.active and gm3_selectionBox.dragging then
                local minX, maxX = math.min(gm3_selectionBox.startX, gm3_selectionBox.currentX), math.max(gm3_selectionBox.startX, gm3_selectionBox.currentX)
                local minY, maxY = math.min(gm3_selectionBox.startY, gm3_selectionBox.currentY), math.max(gm3_selectionBox.startY, gm3_selectionBox.currentY)
                surface.SetDrawColor(255, 80, 80, 40)
                surface.DrawRect(minX, minY, maxX - minX, maxY - minY)
                surface.SetDrawColor(255, 80, 80, 255)
                DrawOutlinedRect(minX, minY, maxX - minX, maxY - minY, 3)
            end

            if #selection > 0 then
                for _, ent in ipairs(selection) do
                    local x, y, w, h = GetEntityScreenBounds(ent)
                    if x then
                        local col = GetSelectionColor(ent)
                        surface.SetDrawColor(col.r, col.g, col.b, 230)
                        DrawOutlinedRect(x, y, w, h, 3)
                    end
                end
            end

            if IsValid(gm3_hoveredEntity) and not gm3_selectedEntities[gm3_hoveredEntity] then
                local x, y, w, h = GetEntityScreenBounds(gm3_hoveredEntity)
                if x then
                    local col = GetSelectionColor(gm3_hoveredEntity)
                    surface.SetDrawColor(col.r, col.g, col.b, 200)
                    DrawOutlinedRect(x, y, w, h, 2)
                end
            end

            if gm3_waypointMode and gm3_cursorMode then
                local cursorX, cursorY = gm3ZeusCam:GetCursorPos()
                local hints = {
                    "LMB: Add waypoint",
                    "RMB: Finalize patrol",
                    "Backspace: Undo",
                    "Delete: Cancel path"
                }
                surface.SetFont("GM3_Cam_Subtitle")
                local textWidth = 0
                local textHeight = select(2, surface.GetTextSize("Hg"))
                for _, text in ipairs(hints) do
                    local w = surface.GetTextSize(text)
                    textWidth = math.max(textWidth, w)
                end
                local padding = 8
                local boxW = textWidth + padding * 2
                local boxH = textHeight * #hints + padding * 2
                local boxX = math.Clamp(cursorX + 24, 0, ScrW() - boxW - 5)
                local boxY = math.Clamp(cursorY + 24, 0, ScrH() - boxH - 5)
                surface.SetDrawColor(5, 5, 5, 200)
                surface.DrawRect(boxX, boxY, boxW, boxH)
                surface.SetDrawColor(60, 180, 255, 200)
                surface.DrawOutlinedRect(boxX, boxY, boxW, boxH)
                for i, text in ipairs(hints) do
                    draw.SimpleText(text, "GM3_Cam_Subtitle", boxX + padding, boxY + padding + (i - 1) * textHeight, color_white, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
                end
            end


            if #gm3_reconPings > 0 then
                local right = ScrW() - lyx.ScaleW(20)
                local reconY = lyx.Scale(50)
                for _, ping in ipairs(gm3_reconPings) do
                    local remaining = math.max(0, ping.expire - CurTime())
                    local label = string.format("Recon ping: %dm radius · contacts %d · %.1fs", math.floor(ping.radius or 0), #(ping.contacts or {}), remaining)
                    draw.SimpleText(label, "GM3_Cam_Subtitle", right, reconY, Color(120, 200, 255), TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP)
                    reconY = reconY + lyx.Scale(18)
                end
            end
            DrawSelectionSummaryPanel(counts)
            DrawSignalMarkersHUD()
        end)

        gm3ZeusCam:CreateCamPanel(true)
    else
        self:ClearHooks()
        gm3ZeusCam:CreateCamPanel(false)
        gm3ZeusCam:SetCursorMode(false)
        gm3ZeusCam:SetSpawnMode(false)
        gm3ZeusCam:SetWaypointMode(false)
        gm3ZeusCam:ClearFollowTarget()
        gm3_hoveredEntity = nil
        gm3_selectionBox.active = false
        gm3_selectionBox.dragging = false
        ClearSelection()
        table.Empty(gm3_moveOrders)
        ClearRouteVisuals()
    end
end

concommand.Add("gm3Cam_toggle", function()
    gm3ZeusCam:RequestToggle()
end)

lyx:NetAdd("gm3ZeusCam_toggleState", {
    func = function(len)
        local state = net.ReadBool()
        gm3_zeusAllowed = true
        EnabledCam = state
        EnabledCamConfirm = state
        gm3ZeusCam:CreateCameraHooks(state)
    end
})

lyx:NetAdd("gm3ZeusCam_reconData", {
    func = function(len)
        local center = net.ReadVector()
        local radius = net.ReadUInt(12) or 0
        local count = net.ReadUInt(8) or 0
        local contacts = {}
        for i = 1, count do
            contacts[i] = {
                pos = net.ReadVector(),
                type = net.ReadString(),
                class = net.ReadString(),
                label = net.ReadString(),
                dir = net.ReadVector(),
                speed = net.ReadFloat(),
                friendly = net.ReadBool()
            }
        end
        gm3_reconPings[#gm3_reconPings + 1] = {
            pos = center,
            radius = radius,
            contacts = contacts,
            expire = CurTime() + 8
        }
        surface.PlaySound("buttons/combine_button2.wav")
    end
})

lyx:NetAdd("gm3ZeusCam_signalMarker", {
    func = function(len)
        local pos = net.ReadVector()
        local label = net.ReadString()
        local r = net.ReadUInt(8)
        local g = net.ReadUInt(8)
        local b = net.ReadUInt(8)
        local duration = net.ReadFloat() or 10
        gm3_signalMarkers[#gm3_signalMarkers + 1] = {
            pos = pos,
            label = label,
            color = Color(r, g, b),
            expire = CurTime() + math.Clamp(duration, 2, 60)
        }
        surface.PlaySound("buttons/button1.wav")
    end
})

lyx:NetAdd("gm3ZeusCam_artilleryPreview", {
    func = function(len)
        local pos = net.ReadVector()
        local radius = net.ReadUInt(12) or 0
        local delay = net.ReadFloat() or 0
        local profile = net.ReadString() or "default"

        gm3_artilleryPreviews[#gm3_artilleryPreviews + 1] = {
            pos = pos,
            radius = math.max(radius, 50),
            impactTime = CurTime() + math.max(delay, 0),
            duration = math.max(delay, 0.1),
            profile = profile
        }
        surface.PlaySound("ambient/levels/prison/radio_random1.wav")
    end
})

local function gm3_GetArtilleryColor(profile)
    return gm3_artilleryColors[profile] or gm3_artilleryColors[string.lower(profile or "")] or gm3_artilleryColors.default
end

local function gm3_DrawArtilleryPreviews3D()
    if #gm3_artilleryPreviews == 0 then return end
    render.SetColorMaterial()
    local now = CurTime()
    local ply = LocalPlayer()
    local yaw = IsValid(ply) and ply:EyeAngles().y or 0
    for i = #gm3_artilleryPreviews, 1, -1 do
        local preview = gm3_artilleryPreviews[i]
        if not preview or now >= preview.impactTime then
            table.remove(gm3_artilleryPreviews, i)
        else
            local remaining = math.max(preview.impactTime - now, 0)
            local fraction = math.Clamp(remaining / preview.duration, 0, 1)
            local color = gm3_GetArtilleryColor(preview.profile)
            local alpha = math.Clamp(180 * fraction, 60, 200)
            local pos = preview.pos + Vector(0, 0, 2)
            render.DrawWireframeSphere(pos, preview.radius, 24, 24, Color(color.r, color.g, color.b, alpha), true)
            render.DrawSphere(pos, preview.radius, 16, 16, Color(color.r, color.g, color.b, math.floor(alpha * 0.15)))
            local textPos = pos + Vector(0, 0, preview.radius + 30)
            local label = gm3_fireSupportProfiles[preview.profile] and gm3_fireSupportProfiles[preview.profile].label or "Artillery"
            cam.Start3D2D(textPos, Angle(0, yaw - 90, 90), 0.15)
                draw.RoundedBox(6, -140, -28, 280, 56, Color(10, 10, 10, 230))
                draw.SimpleText(string.format("%s in %.1fs", label, remaining), "GM3_Cam_Subtitle", 0, 0, Color(255, 255, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            cam.End3D2D()
        end
    end
end

hook.Add("PostDrawTranslucentRenderables", "gm3ZeusCam_artilleryPreviewRender", gm3_DrawArtilleryPreviews3D)

hook.Add("HUDPaint", "gm3ZeusCam_artilleryPreviewHUD", function()
    if #gm3_artilleryPreviews == 0 then return end
    local now = CurTime()
    local y = ScrH() * 0.25
    for i = #gm3_artilleryPreviews, 1, -1 do
        local preview = gm3_artilleryPreviews[i]
        if preview and preview.impactTime > now then
            local remaining = math.max(preview.impactTime - now, 0)
            local info = string.format("Incoming %s in %.1fs", gm3_fireSupportProfiles[preview.profile] and gm3_fireSupportProfiles[preview.profile].label or "Artillery", remaining)
            draw.SimpleTextOutlined(info, "GM3_Cam_Title", ScrW() * 0.5, y, gm3_GetArtilleryColor(preview.profile), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP, 1, color_black)
            y = y + 28
        end
    end
end)
cvars.AddChangeCallback("gm3Cam_artilleryDelay", function(_, _, new)
    gm3_UpdateArtilleryDelay(new, true)
end, "gm3ZeusCam_artillerySync")

gm3_UpdateArtilleryDelay(CVCamArtilleryDelay:GetFloat(), true)
