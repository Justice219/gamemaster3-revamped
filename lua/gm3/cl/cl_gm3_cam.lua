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
    if not gm3_zeusAllowed then
        notification.AddLegacy("You do not have access to Zeus.", NOTIFY_ERROR, 3)
        return
    end
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
        props = 0
    }
    for ent, _ in pairs(gm3_selectedEntities) do
        if IsValid(ent) then
            if ent:IsPlayer() and ent ~= LocalPlayer() then
                counts.players = counts.players + 1
            elseif ent:IsNPC() or ent:IsNextBot() then
                counts.npcs = counts.npcs + 1
            else
                counts.props = counts.props + 1
            end
        end
    end
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

function gm3ZeusCam:TrackMoveOrders(targetPos, entities)
    if not targetPos then return end
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

function gm3ZeusCam:SetSpawnMode(state)
    gm3_spawnMode = state and true or false
    if IsValid(self.SpawnModeButton) then
        self.SpawnModeButton:SetText(gm3_spawnMode and "Spawn Mode (ON)" or "Spawn Mode (OFF)")
        self.SpawnModeButton:SetBackgroundColor(gm3_spawnMode and Color(30, 160, 110) or Color(90, 90, 90))
    end
end

function gm3ZeusCam:CreateSpawnToolbar(parent)
    if IsValid(self.SpawnToolbar) then
        self.SpawnToolbar:Remove()
    end

    local panel = vgui.Create("DPanel", parent)
    panel:SetSize(lyx.ScaleW(260), lyx.Scale(190))
    panel:SetPos(lyx.Scale(10), lyx.Scale(120))
    panel.Paint = function(s, w, h)
        surface.SetDrawColor(gm3_spawnMode and Color(20, 80, 60, 220) or Color(30, 30, 30, 220))
        surface.DrawRect(0, 0, w, h)
        surface.SetDrawColor(70, 70, 70, 255)
        surface.DrawOutlinedRect(0, 0, w, h)
        draw.SimpleText("Spawn Toolbar", "GM3_Cam_Subtitle", lyx.Scale(8), lyx.Scale(5), color_white)
    end

    local classEntry = vgui.Create("lyx.TextEntry2", panel)
    classEntry:Dock(TOP)
    classEntry:DockMargin(lyx.Scale(8), lyx.Scale(28), lyx.Scale(8), lyx.Scale(6))
    classEntry:SetPlaceholderText("NPC Class (npc_combine_s)")
    classEntry:SetValue(gm3_spawnConfig.class)
    classEntry.OnChange = function(s)
        gm3_spawnConfig.class = string.Trim(s:GetValue() or "")
    end

    local weaponEntry = vgui.Create("lyx.TextEntry2", panel)
    weaponEntry:Dock(TOP)
    weaponEntry:DockMargin(lyx.Scale(8), 0, lyx.Scale(8), lyx.Scale(6))
    weaponEntry:SetPlaceholderText("Weapon (weapon_smg1)")
    weaponEntry:SetValue(gm3_spawnConfig.weapon)
    weaponEntry.OnChange = function(s)
        gm3_spawnConfig.weapon = string.Trim(s:GetValue() or "")
    end

    local countEntry = vgui.Create("lyx.TextEntry2", panel)
    countEntry:Dock(TOP)
    countEntry:DockMargin(lyx.Scale(8), 0, lyx.Scale(8), lyx.Scale(6))
    countEntry:SetPlaceholderText("Count (1-20)")
    countEntry:SetValue(tostring(gm3_spawnConfig.count))
    countEntry:SetNumeric(true)
    countEntry.OnChange = function(s)
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
    self:SetSpawnMode(false)
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

    lyx:NetSend("gm3ZeusCam_spawnNPCs", function()
        net.WriteString(class)
        net.WriteString(weapon)
        net.WriteUInt(count, 6)
        net.WriteVector(tr.HitPos + Vector(0, 0, 5))
        net.WriteAngle(CamAngle)
        net.WriteString(gm3_spawnConfig.relationship or "hostile")
    end)
end

function gm3ZeusCam:SendFormationCommand(name)
    if not SelectionHasNPCs() then
        notification.AddLegacy("Select NPCs to use formations.", NOTIFY_HINT, 2)
        return
    end
    local formation = gm3_formations[name]
    if not formation then return end
    local tr = self:GetCursorTrace()
    if not tr.Hit then
        notification.AddLegacy("Aim at a location to send the formation.", NOTIFY_ERROR, 2)
        return
    end
    local selection = GetSelectionList()
    local offsets = formation(#selection, gm3_formationSpacing)
    local targetPositions = {}
    for i, ent in ipairs(selection) do
        local offset = offsets[i] or offsets[#offsets]
        targetPositions[i] = tr.HitPos + offset
    end

    lyx:NetSend("gm3ZeusCam_moveFormation", function()
        net.WriteUInt(#selection, 12)
        for i, ent in ipairs(selection) do
            net.WriteEntity(ent)
            net.WriteVector(targetPositions[i])
        end
    end)

    self:TrackMoveOrders(tr.HitPos, selection)
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
                self:SendNPCsToCursor()
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
                self:SendFormationCommand("line")
            end):SetIcon("icon16/shape_align_left.png")
            formationMenu:AddOption("Column", function()
                self:SendFormationCommand("column")
            end):SetIcon("icon16/shape_align_bottom.png")
            formationMenu:AddOption("Wedge", function()
                self:SendFormationCommand("wedge")
            end):SetIcon("icon16/shape_move_forwards.png")
            formationMenu:AddOption("Circle", function()
                self:SendFormationCommand("circle")
            end):SetIcon("icon16/shape_ungroup.png")
        end

        if hasPlayers then
            menu:AddSpacer()
            menu:AddOption("Players → Camera", function()
                self:SendPlayersToCamera()
            end):SetIcon("icon16/user_go.png")

            menu:AddOption("Players → Cursor", function()
                self:SendPlayersToCursor()
            end):SetIcon("icon16/user_green.png")
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
                self:SendPropsToCursor()
            end):SetIcon("icon16/box_world.png")
        end
    end

    menu:AddOption("Clear Selection", function()
        ClearSelection()
    end):SetIcon("icon16/cancel.png")

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
        self:TrackMoveOrders(CamPos, selection)
    end
end

function gm3ZeusCam:SendNPCsToCursor()
    if not SelectionHasNPCs() then
        notification.AddLegacy("Selection has no NPCs.", NOTIFY_HINT, 2)
        return
    end
    local tr = self:GetCursorTrace()
    if not tr.Hit then
        notification.AddLegacy("No target position under cursor.", NOTIFY_ERROR, 2)
        return
    end
    local selection = self:SendSelectionCommand("gm3ZeusCam_moveToClick", tr.HitPos)
    if selection then
        self:TrackMoveOrders(tr.HitPos, selection)
    end
end

function gm3ZeusCam:SendPlayersToCamera()
    if not SelectionHasPlayers() then
        notification.AddLegacy("Selection has no players.", NOTIFY_HINT, 2)
        return
    end
    local selection = self:SendSelectionCommand("gm3ZeusCam_playersToCamera", CamPos)
    if selection then
        self:TrackMoveOrders(CamPos, selection)
    end
end

function gm3ZeusCam:SendPlayersToCursor()
    if not SelectionHasPlayers() then
        notification.AddLegacy("Selection has no players.", NOTIFY_HINT, 2)
        return
    end
    local tr = self:GetCursorTrace()
    if not tr.Hit then
        notification.AddLegacy("No target position under cursor.", NOTIFY_ERROR, 2)
        return
    end
    local selection = self:SendSelectionCommand("gm3ZeusCam_playersToCursor", tr.HitPos)
    if selection then
        self:TrackMoveOrders(tr.HitPos, selection)
    end
end

function gm3ZeusCam:StopSelectedNPCs()
    if not SelectionHasNPCs() then
        notification.AddLegacy("Selection has no NPCs.", NOTIFY_HINT, 2)
        return
    end
    self:SendSelectionCommand("gm3ZeusCam_stopNPCs")
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

function gm3ZeusCam:SendPropsToCursor()
    if not SelectionHasProps() then
        notification.AddLegacy("Selection has no props.", NOTIFY_HINT, 2)
        return
    end
    local tr = self:GetCursorTrace()
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
        gm3CamPanelBottom:SetSize(ScrW(), lyx.Scale(60))
        gm3CamPanelBottom:SetPos(0, ScrH() - lyx.Scale(60))
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
        hint:SizeToContents()

        local clearSel = vgui.Create("lyx.TextButton2", gm3CamPanelBottom)
        clearSel:Dock(RIGHT)
        clearSel:DockMargin(lyx.Scale(5), lyx.Scale(5), lyx.Scale(5), lyx.Scale(5))
        clearSel:SetText("Clear Selection")
        clearSel:SetWide(lyx.Scale(150))
        clearSel:SetBackgroundColor(Color(90, 90, 90))
        clearSel.DoClick = function()
            ClearSelection()
        end

        local removeSelected = vgui.Create("lyx.TextButton2", gm3CamPanelBottom)
        removeSelected:Dock(RIGHT)
        removeSelected:DockMargin(lyx.Scale(5), lyx.Scale(5), lyx.Scale(5), lyx.Scale(5))
        removeSelected:SetText("Remove Selected")
        removeSelected:SetWide(lyx.Scale(150))
        removeSelected:SetBackgroundColor(Color(255,0,0))
        removeSelected.DoClick = function()
            gm3ZeusCam:RemoveSelectedEntities()
        end

        local moveToCamera = vgui.Create("lyx.TextButton2", gm3CamPanelBottom)
        moveToCamera:Dock(RIGHT)
        moveToCamera:DockMargin(lyx.Scale(5), lyx.Scale(5), lyx.Scale(5), lyx.Scale(5))
        moveToCamera:SetText("NPCs → Camera")
        moveToCamera:SetWide(lyx.Scale(150))
        moveToCamera:SetBackgroundColor(Color(139,36,139))
        moveToCamera.DoClick = function()
            gm3ZeusCam:SendNPCsToCamera()
        end

        local moveToClick = vgui.Create("lyx.TextButton2", gm3CamPanelBottom)
        moveToClick:Dock(RIGHT)
        moveToClick:DockMargin(lyx.Scale(5), lyx.Scale(5), lyx.Scale(5), lyx.Scale(5))
        moveToClick:SetText("NPCs → Cursor")
        moveToClick:SetWide(lyx.Scale(150))
        moveToClick:SetBackgroundColor(Color(139,36,139))
        moveToClick.DoClick = function()
            gm3ZeusCam:SendNPCsToCursor()
        end

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

            local shouldCursor = gm3_spawnMode or input.IsKeyDown(KEY_LALT) or input.IsKeyDown(KEY_RALT)
            gm3ZeusCam:SetCursorMode(shouldCursor)

            if gm3_spawnMode and gm3_cursorMode then
                if input.IsMouseDown(MOUSE_LEFT) and CurTime() > gm3_spawnNextClick then
                    gm3_spawnNextClick = CurTime() + 0.35
                    gm3ZeusCam:SpawnAtCursor()
                end
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
                render.DrawLine(startPos, endPos, Color(color.r, color.g, color.b, 200), true)

                local dist = math.Round(startPos:Distance(endPos))
                local mid = LerpVector(0.5, startPos, endPos) + Vector(0, 0, 10)
                cam.Start3D2D(mid, Angle(0, CamAngle.y - 90, 90), 0.1)
                    draw.RoundedBox(4, -60, -12, 120, 24, Color(20, 20, 20, 220))
                    draw.SimpleText(dist .. "u", "GM3_Cam_Subtitle", 0, 0, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
                cam.End3D2D()
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
            local selection = GetSelectionList()

            if gm3_selectionBox.active and gm3_selectionBox.dragging then
                local minX, maxX = math.min(gm3_selectionBox.startX, gm3_selectionBox.currentX), math.max(gm3_selectionBox.startX, gm3_selectionBox.currentX)
                local minY, maxY = math.min(gm3_selectionBox.startY, gm3_selectionBox.currentY), math.max(gm3_selectionBox.startY, gm3_selectionBox.currentY)
                surface.SetDrawColor(255, 80, 80, 40)
                surface.DrawRect(minX, minY, maxX - minX, maxY - minY)
                surface.SetDrawColor(255, 80, 80, 255)
                DrawOutlinedRect(minX, minY, maxX - minX, maxY - minY, 2)
            end

            if #selection > 0 then
                for _, ent in ipairs(selection) do
                    local x, y, w, h = GetEntityScreenBounds(ent)
                    if x then
                        local col = GetSelectionColor(ent)
                        surface.SetDrawColor(col.r, col.g, col.b, 230)
                        DrawOutlinedRect(x, y, w, h, 2)
                    end
                end
            end

            if IsValid(gm3_hoveredEntity) and not gm3_selectedEntities[gm3_hoveredEntity] then
                local x, y, w, h = GetEntityScreenBounds(gm3_hoveredEntity)
                if x then
                    local col = GetSelectionColor(gm3_hoveredEntity)
                    surface.SetDrawColor(col.r, col.g, col.b, 200)
                    DrawOutlinedRect(x, y, w, h, 1)
                end
            end
        end)

        gm3ZeusCam:CreateCamPanel(true)
    else
        self:ClearHooks()
        gm3ZeusCam:CreateCamPanel(false)
        gm3ZeusCam:SetCursorMode(false)
        gm3ZeusCam:SetSpawnMode(false)
        gm3_hoveredEntity = nil
        gm3_selectionBox.active = false
        gm3_selectionBox.dragging = false
        ClearSelection()
        table.Empty(gm3_moveOrders)
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
