--[[
    GM3 Player Selector Component
    Provides a popup window for selecting players with search, preview, and visual feedback
]]

local PANEL = {}

-- Create fonts for the player selector
surface.CreateFont("GM3.PlayerSelector.Title", {
    font = "Open Sans Bold",
    size = lyx.Scale(18),
    weight = 500,
    antialias = true
})

surface.CreateFont("GM3.PlayerSelector.Name", {
    font = "Open Sans SemiBold",
    size = lyx.Scale(14),
    weight = 500,
    antialias = true
})

surface.CreateFont("GM3.PlayerSelector.Info", {
    font = "Open Sans",
    size = lyx.Scale(12),
    weight = 400,
    antialias = true
})

function PANEL:Init()
    self:SetSize(lyx.ScaleW(600), lyx.Scale(400))
    self:SetTitle("Select Player")
    self:Center()
    self:MakePopup()

    self.SelectedPlayer = nil
    self.SearchText = ""
    self.Players = {}

    -- Header with search
    local header = vgui.Create("DPanel", self)
    header:Dock(TOP)
    header:SetTall(lyx.Scale(50))
    header:DockMargin(lyx.Scale(10), lyx.Scale(10), lyx.Scale(10), lyx.Scale(5))
    header.Paint = function(s, w, h)
        draw.RoundedBox(4, 0, 0, w, h, Color(68, 68, 68, 100))
    end

    -- Search entry
    self.SearchEntry = vgui.Create("lyx.TextEntry2", header)
    self.SearchEntry:Dock(FILL)
    self.SearchEntry:DockMargin(lyx.Scale(10), lyx.Scale(10), lyx.Scale(10), lyx.Scale(10))
    self.SearchEntry:SetPlaceholderText("Search players by name or SteamID...")
    self.SearchEntry.OnChange = function(s)
        self.SearchText = s:GetValue()
        self:RefreshPlayerList()
    end

    -- Player list scroll panel
    self.ScrollPanel = vgui.Create("DScrollPanel", self)
    self.ScrollPanel:Dock(FILL)
    self.ScrollPanel:DockMargin(lyx.Scale(10), lyx.Scale(5), lyx.Scale(10), lyx.Scale(50))

    -- Bottom buttons
    local bottom = vgui.Create("DPanel", self)
    bottom:Dock(BOTTOM)
    bottom:SetTall(lyx.Scale(40))
    bottom:DockMargin(lyx.Scale(10), 0, lyx.Scale(10), lyx.Scale(10))
    bottom.Paint = function() end

    -- Cancel button
    local cancelBtn = vgui.Create("lyx.TextButton2", bottom)
    cancelBtn:Dock(LEFT)
    cancelBtn:SetWide(lyx.ScaleW(100))
    cancelBtn:SetText("Cancel")
    cancelBtn:SetFont("GM3.PlayerSelector.Name")
    cancelBtn:SetBackgroundColor(Color(150, 50, 50))
    cancelBtn.DoClick = function()
        self:Close()
    end

    -- Selected player display
    self.SelectedLabel = vgui.Create("DLabel", bottom)
    self.SelectedLabel:Dock(FILL)
    self.SelectedLabel:DockMargin(lyx.Scale(10), 0, lyx.Scale(10), 0)
    self.SelectedLabel:SetFont("GM3.PlayerSelector.Name")
    self.SelectedLabel:SetTextColor(Color(255, 255, 255))
    self.SelectedLabel:SetText("No player selected")
    self.SelectedLabel:SetContentAlignment(5)

    -- Select button
    self.SelectBtn = vgui.Create("lyx.TextButton2", bottom)
    self.SelectBtn:Dock(RIGHT)
    self.SelectBtn:SetWide(lyx.ScaleW(100))
    self.SelectBtn:SetText("Select")
    self.SelectBtn:SetFont("GM3.PlayerSelector.Name")
    self.SelectBtn:SetBackgroundColor(Color(50, 150, 50))
    self.SelectBtn:SetEnabled(false)
    self.SelectBtn.DoClick = function()
        if self.SelectedPlayer then
            self:OnPlayerSelected(self.SelectedPlayer)
            self:Close()
        end
    end

    -- Populate player list
    self:RefreshPlayerList()
end

function PANEL:RefreshPlayerList()
    -- Clear existing panels
    self.ScrollPanel:Clear()

    -- Get all players and filter
    local players = player.GetAll()
    local filteredPlayers = {}

    for _, ply in ipairs(players) do
        local searchLower = string.lower(self.SearchText)
        local nameLower = string.lower(ply:Nick())
        local steamID = ply:SteamID()
        local steamIDLower = string.lower(steamID)

        if self.SearchText == "" or
           string.find(nameLower, searchLower, 1, true) or
           string.find(steamIDLower, searchLower, 1, true) then
            table.insert(filteredPlayers, ply)
        end
    end

    -- Sort by name
    table.sort(filteredPlayers, function(a, b)
        return a:Nick() < b:Nick()
    end)

    -- Create player panels
    for _, ply in ipairs(filteredPlayers) do
        self:CreatePlayerPanel(ply)
    end
end

function PANEL:CreatePlayerPanel(ply)
    local panel = vgui.Create("DButton", self.ScrollPanel)
    panel:Dock(TOP)
    panel:SetTall(lyx.Scale(70))
    panel:DockMargin(0, 0, 0, lyx.Scale(5))
    panel:SetText("")

    -- Store player reference
    panel.Player = ply

    -- Hover and selection state
    panel.Hovered = false
    panel.Selected = (self.SelectedPlayer == ply)

    panel.Paint = function(s, w, h)
        local bgColor = Color(60, 60, 60, 100)

        if s.Selected then
            bgColor = Color(100, 100, 150, 150)
        elseif s.Hovered then
            bgColor = Color(80, 80, 80, 150)
        end

        draw.RoundedBox(4, 0, 0, w, h, bgColor)

        -- Team color indicator
        local teamColor = team.GetColor(ply:Team())
        draw.RoundedBoxEx(4, 0, 0, lyx.Scale(4), h, teamColor, true, false, true, false)
    end

    panel.OnCursorEntered = function(s)
        s.Hovered = true
    end

    panel.OnCursorExited = function(s)
        s.Hovered = false
    end

    -- Model icon
    local modelIcon = vgui.Create("DModelPanel", panel)
    modelIcon:SetPos(lyx.Scale(10), lyx.Scale(5))
    modelIcon:SetSize(lyx.Scale(60), lyx.Scale(60))
    modelIcon:SetModel(ply:GetModel())
    modelIcon:SetMouseInputEnabled(false)

    -- Position the model
    local headPos = modelIcon.Entity:GetBonePosition(modelIcon.Entity:LookupBone("ValveBiped.Bip01_Head1") or 0)
    if headPos then
        modelIcon:SetLookAt(headPos)
        modelIcon:SetCamPos(headPos + Vector(15, 0, 0))
    else
        -- Fallback for models without standard bones
        modelIcon:SetLookAt(Vector(0, 0, 40))
        modelIcon:SetCamPos(Vector(30, 0, 40))
    end
    modelIcon:SetFOV(40)

    -- Prevent model rotation
    function modelIcon:LayoutEntity(ent) end

    -- Player name
    local nameLabel = vgui.Create("DLabel", panel)
    nameLabel:SetPos(lyx.Scale(80), lyx.Scale(10))
    nameLabel:SetFont("GM3.PlayerSelector.Name")
    nameLabel:SetText(ply:Nick())
    nameLabel:SetTextColor(team.GetColor(ply:Team()))
    nameLabel:SizeToContents()

    -- SteamID
    local steamIDLabel = vgui.Create("DLabel", panel)
    steamIDLabel:SetPos(lyx.Scale(80), lyx.Scale(30))
    steamIDLabel:SetFont("GM3.PlayerSelector.Info")
    steamIDLabel:SetText(ply:SteamID())
    steamIDLabel:SetTextColor(Color(200, 200, 200))
    steamIDLabel:SizeToContents()

    -- Team/Group info
    local groupText = ply:GetUserGroup()
    if groupText == "user" then
        groupText = team.GetName(ply:Team())
    end

    local groupLabel = vgui.Create("DLabel", panel)
    groupLabel:SetPos(lyx.Scale(80), lyx.Scale(48))
    groupLabel:SetFont("GM3.PlayerSelector.Info")
    groupLabel:SetText("Group: " .. groupText)
    groupLabel:SetTextColor(Color(180, 180, 180))
    groupLabel:SizeToContents()

    -- Additional info on the right
    local pingLabel = vgui.Create("DLabel", panel)
    pingLabel:SetPos(w - lyx.Scale(100), lyx.Scale(25))
    pingLabel:SetFont("GM3.PlayerSelector.Info")
    pingLabel:SetText("Ping: " .. ply:Ping() .. "ms")
    pingLabel:SetTextColor(Color(180, 180, 180))
    pingLabel:SizeToContents()

    -- Click handler
    panel.DoClick = function(s)
        -- Update selection
        for _, child in ipairs(self.ScrollPanel:GetChildren()) do
            if child.Selected then
                child.Selected = false
            end
        end

        s.Selected = true
        self.SelectedPlayer = ply
        self.SelectedLabel:SetText("Selected: " .. ply:Nick())
        self.SelectBtn:SetEnabled(true)
    end

    -- Double click to select immediately
    panel.DoDoubleClick = function(s)
        self.SelectedPlayer = ply
        self:OnPlayerSelected(ply)
        self:Close()
    end
end

function PANEL:OnPlayerSelected(ply)
    -- Override this function to handle selection
end

function PANEL:Paint(w, h)
    draw.RoundedBox(4, 0, 0, w, h, lyx.Colors.Background)
    draw.RoundedBoxEx(4, 0, 0, w, lyx.Scale(25), lyx.Colors.Header, true, true, false, false)
end

vgui.Register("GM3.PlayerSelector", PANEL, "DFrame")