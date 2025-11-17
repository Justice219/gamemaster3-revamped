local PANEL = {}
local OPSAT_DEFAULT = {
    ["Title 1"] = "Information",
    ["Line 1"] = "Planet: KG3",
    ["Line 2"] = "Era: 22BBY",
    ["Title 2"] = "Objective",
    ["Line 3"] = "- Raid CIS Base",
    ["Line 4"] = "- Eliminate CIS Leader"
}

gm3 = gm3 or {}
gm3.opsatClientData = gm3.opsatClientData or table.Copy(OPSAT_DEFAULT)
gm3.opsatSavedPresets = gm3.opsatSavedPresets or {}

if CLIENT then
    surface.CreateFont("GM3.Opsat.Header", {
        font = "Open Sans SemiBold",
        size = 24,
        weight = 600,
        antialias = true
    })

    surface.CreateFont("GM3.Opsat.Sub", {
        font = "Open Sans",
        size = 18,
        weight = 500,
        antialias = true
    })
end

local function copyData(tbl)
    return table.Copy(tbl or OPSAT_DEFAULT)
end

local function sanitizeOpsat(data)
    local sanitized = {}
    for key, defaultValue in pairs(OPSAT_DEFAULT) do
        local value = tostring(data[key] or defaultValue)
        sanitized[key] = string.Trim(value)
    end
    return sanitized
end

function PANEL:Init()
    self:SetTall(self:GetTall())
    self.CurrentOpsat = copyData(gm3.opsatClientData)

    self.ScrollPanel = vgui.Create("DScrollPanel", self)
    self.ScrollPanel:Dock(FILL)
    self.ScrollPanel:DockMargin(lyx.ScaleW(10), lyx.Scale(10), lyx.ScaleW(10), lyx.Scale(10))

    self:BuildOpsatCard()
    self:BuildPresetCard()
    self:RequestPresets()

    self.HookID = "GM3OpsatPresets_" .. tostring(self)
    hook.Add("GM3.OpsatPresetsUpdated", self.HookID, function()
        if IsValid(self) then
            self:RefreshPresetList()
        end
    end)
end

function PANEL:OnRemove()
    if self.HookID then
        hook.Remove("GM3.OpsatPresetsUpdated", self.HookID)
    end
end

function PANEL:RequestPresets()
    net.Start("gm3:tools:opsatRequestPresets")
    net.SendToServer()
end

function PANEL:BuildOpsatCard()
    local FormCard = vgui.Create("DPanel", self.ScrollPanel)
    FormCard:Dock(TOP)
    FormCard:DockMargin(lyx.ScaleW(5), 0, lyx.ScaleW(5), lyx.Scale(8))
    FormCard:DockPadding(lyx.ScaleW(16), lyx.Scale(16), lyx.ScaleW(16), lyx.Scale(16))
    FormCard.Paint = function(_, w, h)
        draw.RoundedBox(8, 0, 0, w, h, Color(18, 18, 18, 235))
        surface.SetDrawColor(255, 255, 255, 5)
        surface.DrawOutlinedRect(0, 0, w, h, 1)
    end

    local Title = vgui.Create("lyx.Label2", FormCard)
    Title:Dock(TOP)
    Title:SetFont("GM3.Opsat.Header")
    Title:SetTall(lyx.Scale(32))
    Title:SetText("OPSAT Broadcast")

    local Subtitle = vgui.Create("lyx.Label2", FormCard)
    Subtitle:Dock(TOP)
    Subtitle:SetTall(lyx.Scale(20))
    Subtitle:SetText("Craft mission briefs, objectives, or intel cards and broadcast them instantly.")

    local Body = vgui.Create("DPanel", FormCard)
    Body:Dock(TOP)
    Body:SetTall(lyx.Scale(310))
    Body:DockMargin(0, lyx.Scale(10), 0, 0)
    Body.Paint = nil

    Body.PerformLayout = function(panel, w, _)
        if IsValid(panel.LeftColumn) then
            panel.LeftColumn:SetWide(math.floor(w * 0.55))
        end
    end

    local LeftColumn = vgui.Create("DPanel", Body)
    LeftColumn:Dock(LEFT)
    LeftColumn.Paint = nil
    Body.LeftColumn = LeftColumn

    local RightColumn = vgui.Create("DPanel", Body)
    RightColumn:Dock(FILL)
    RightColumn:DockMargin(lyx.ScaleW(12), 0, 0, 0)
    RightColumn.Paint = nil

    local function addField(column, key, label, placeholder)
        local container = vgui.Create("DPanel", column)
        container:Dock(TOP)
        container:SetTall(lyx.Scale(58))
        container:DockMargin(0, 0, lyx.ScaleW(6), lyx.Scale(8))
        container.Paint = nil

        local lbl = vgui.Create("lyx.Label2", container)
        lbl:Dock(TOP)
        lbl:SetTall(lyx.Scale(18))
        lbl:SetFont("GM3.Opsat.Sub")
        lbl:SetText(label)

        local entry = vgui.Create("lyx.TextEntry2", container)
        entry:Dock(FILL)
        entry:SetPlaceholderText(placeholder)
        entry:SetText(self.CurrentOpsat[key] or OPSAT_DEFAULT[key])
        entry.OnChange = function(s)
            self.CurrentOpsat[key] = string.sub(s:GetValue(), 1, 160)
            self:UpdatePreview()
        end

        return entry
    end

    self.Fields = {}
    self.Fields["Title 1"] = addField(LeftColumn, "Title 1", "Left Title", "Information")
    self.Fields["Line 1"] = addField(LeftColumn, "Line 1", "Left Line 1", "Planet: KG3")
    self.Fields["Line 2"] = addField(LeftColumn, "Line 2", "Left Line 2", "Era: 22BBY")

    self.Fields["Title 2"] = addField(RightColumn, "Title 2", "Right Title", "Objective")
    self.Fields["Line 3"] = addField(RightColumn, "Line 3", "Right Line 1", "- Raid CIS Base")
    self.Fields["Line 4"] = addField(RightColumn, "Line 4", "Right Line 2", "- Eliminate CIS Leader")

    local PreviewCard = vgui.Create("DPanel", FormCard)
    PreviewCard:Dock(TOP)
    PreviewCard:SetTall(lyx.Scale(200))
    PreviewCard:DockMargin(0, lyx.Scale(6), 0, 0)
    PreviewCard.Paint = nil

    self.PreviewBody = vgui.Create("DPanel", PreviewCard)
    self.PreviewBody:Dock(FILL)
    self.PreviewBody.Paint = function(panel, w, h)
        draw.RoundedBox(12, 0, 0, w, h, Color(20, 20, 20, 240))
        draw.RoundedBox(12, 0, 0, w, lyx.Scale(6), Color(189, 88, 88, 180))
        surface.SetDrawColor(255, 255, 255, 8)
        surface.DrawOutlinedRect(0, 0, w, h, 1)

        local primary = gm3.settings and gm3.settings["gm3_opsat_primaryColor"]
        local secondary = gm3.settings and gm3.settings["gm3_opsat_secondaryColor"]
        local primaryColor = primary and primary.value or Color(189, 88, 88)
        local secondaryColor = secondary and secondary.value or Color(255, 255, 255)

        local data = self.CurrentOpsat
        local y = lyx.Scale(18)
        local function drawSection(title, ...)
            surface.SetFont("GM3.Opsat.Header")
            local titleText = string.upper(string.Trim(title or ""))
            if titleText ~= "" then
                surface.SetTextColor(primaryColor)
                surface.SetTextPos(lyx.ScaleW(12), y)
                surface.DrawText(titleText)
                y = y + lyx.Scale(26)
            end

            surface.SetFont("GM3.Opsat.Sub")
            for _, text in ipairs({...}) do
                text = string.Trim(text or "")
                if text ~= "" then
                    surface.SetTextColor(secondaryColor)
                    surface.SetTextPos(lyx.ScaleW(16), y)
                    surface.DrawText(text)
                    y = y + lyx.Scale(20)
                end
            end
            y = y + lyx.Scale(6)
        end

        drawSection(data["Title 1"], data["Line 1"], data["Line 2"])
        drawSection(data["Title 2"], data["Line 3"], data["Line 4"])
    end

    local ButtonRow = vgui.Create("DPanel", FormCard)
    ButtonRow:Dock(TOP)
    ButtonRow:SetTall(lyx.Scale(44))
    ButtonRow:DockMargin(0, lyx.Scale(10), 0, 0)
    ButtonRow.Paint = nil

    local Deploy = vgui.Create("lyx.TextButton2", ButtonRow)
    Deploy:Dock(LEFT)
    Deploy:SetWide(lyx.ScaleW(180))
    Deploy:SetText("Broadcast OPSAT")
    Deploy:SetBackgroundColor(Color(63, 61, 61))
    Deploy.DoClick = function()
        local payload = sanitizeOpsat(self.CurrentOpsat)
        gm3.opsatClientData = copyData(payload)
        net.Start("gm3:tools:opsatSet")
        net.WriteTable(payload)
        net.SendToServer()
    end

    local Reset = vgui.Create("lyx.TextButton2", ButtonRow)
    Reset:Dock(LEFT)
    Reset:DockMargin(lyx.ScaleW(10), 0, 0, 0)
    Reset:SetWide(lyx.ScaleW(140))
    Reset:SetText("Reset Fields")
    Reset:SetBackgroundColor(Color(45, 45, 45))
    Reset.DoClick = function()
        self.CurrentOpsat = copyData(OPSAT_DEFAULT)
        for key, entry in pairs(self.Fields) do
            if IsValid(entry) then
                entry:SetText(self.CurrentOpsat[key])
            end
        end
        self:UpdatePreview()
    end

    local Remove = vgui.Create("lyx.TextButton2", ButtonRow)
    Remove:Dock(RIGHT)
    Remove:SetWide(lyx.ScaleW(160))
    Remove:SetText("Remove OPSAT")
    Remove:SetBackgroundColor(Color(120, 35, 35))
    Remove.DoClick = function()
        net.Start("gm3:tools:opsatRemove")
        net.SendToServer()
    end

    FormCard:InvalidateLayout(true)
    FormCard:SizeToChildren(false, true)
    timer.Simple(0, function()
        if IsValid(FormCard) then
            FormCard:SizeToChildren(false, true)
        end
    end)
end

function PANEL:BuildPresetCard()
    local PresetCard = vgui.Create("DPanel", self.ScrollPanel)
    PresetCard:Dock(TOP)
    PresetCard:DockMargin(lyx.ScaleW(5), 0, lyx.ScaleW(5), lyx.Scale(8))
    PresetCard:DockPadding(lyx.ScaleW(16), lyx.Scale(16), lyx.ScaleW(16), lyx.Scale(16))
    PresetCard.Paint = function(_, w, h)
        draw.RoundedBox(8, 0, 0, w, h, Color(15, 15, 15, 235))
        surface.SetDrawColor(255, 255, 255, 3)
        surface.DrawOutlinedRect(0, 0, w, h, 1)
    end

    local Title = vgui.Create("lyx.Label2", PresetCard)
    Title:Dock(TOP)
    Title:SetFont("GM3.Opsat.Header")
    Title:SetTall(lyx.Scale(32))
    Title:SetText("Saved OPSAT Presets")

    local SaveRow = vgui.Create("DPanel", PresetCard)
    SaveRow:Dock(TOP)
    SaveRow:SetTall(lyx.Scale(44))
    SaveRow:DockMargin(0, lyx.Scale(6), 0, lyx.Scale(4))
    SaveRow.Paint = nil

    self.PresetName = vgui.Create("lyx.TextEntry2", SaveRow)
    self.PresetName:Dock(LEFT)
    self.PresetName:SetWide(lyx.ScaleW(220))
    self.PresetName:SetPlaceholderText("ex. Siege Brief")

    local SaveBtn = vgui.Create("lyx.TextButton2", SaveRow)
    SaveBtn:Dock(LEFT)
    SaveBtn:DockMargin(lyx.ScaleW(8), 0, 0, 0)
    SaveBtn:SetWide(lyx.ScaleW(140))
    SaveBtn:SetText("Save Preset")
    SaveBtn:SetBackgroundColor(Color(63, 61, 61))
    SaveBtn.DoClick = function()
        local name = string.Trim(self.PresetName:GetValue() or "")
        if name == "" then return end

        local payload = {
            name = name,
            data = sanitizeOpsat(self.CurrentOpsat)
        }

        net.Start("gm3:tools:opsatSavePreset")
        net.WriteTable(payload)
        net.SendToServer()
    end

    self.PresetList = vgui.Create("DIconLayout", PresetCard)
    self.PresetList:Dock(TOP)
    self.PresetList:DockMargin(0, lyx.Scale(8), 0, 0)
    self.PresetList:SetSpaceX(lyx.ScaleW(8))
    self.PresetList:SetSpaceY(lyx.Scale(8))

    self:RefreshPresetList()

    PresetCard:InvalidateLayout(true)
    PresetCard:SizeToChildren(false, true)
    timer.Simple(0, function()
        if IsValid(PresetCard) then
            PresetCard:SizeToChildren(false, true)
        end
    end)
end

function PANEL:RefreshPresetList()
    if not IsValid(self.PresetList) then return end
    self.PresetList:Clear()

    local presets = gm3.opsatSavedPresets or {}
    if #presets == 0 then
        local empty = self.PresetList:Add("DPanel")
        empty:SetSize(lyx.ScaleW(260), lyx.Scale(70))
        empty.Paint = function(_, w, h)
            draw.RoundedBox(4, 0, 0, w, h, Color(26, 26, 26, 220))
        end
        local label = vgui.Create("lyx.Label2", empty)
        label:Dock(FILL)
        label:SetFont("GM3.Opsat.Sub")
        label:SetText("No presets saved yet.")
        label:SetContentAlignment(5)
        return
    end

    for _, preset in ipairs(presets) do
        local card = self.PresetList:Add("DPanel")
        card:SetSize(lyx.ScaleW(260), lyx.Scale(90))
        card:DockPadding(lyx.ScaleW(10), lyx.Scale(8), lyx.ScaleW(10), lyx.Scale(8))
        card.Paint = function(_, w, h)
            draw.RoundedBox(6, 0, 0, w, h, Color(26, 26, 26, 220))
            surface.SetDrawColor(255, 255, 255, 4)
            surface.DrawOutlinedRect(0, 0, w, h, 1)
        end

        local nameLabel = vgui.Create("lyx.Label2", card)
        nameLabel:Dock(TOP)
        nameLabel:SetTall(lyx.Scale(22))
        nameLabel:SetFont("GM3.Opsat.Sub")
        nameLabel:SetText(preset.name or "Preset")

        local snippet = vgui.Create("lyx.Label2", card)
        snippet:Dock(TOP)
        snippet:SetTall(lyx.Scale(18))
        snippet:SetText((preset.data and preset.data["Line 1"]) or "")
        snippet:SetTextColor(Color(190, 190, 190))

        local buttonRow = vgui.Create("DPanel", card)
        buttonRow:Dock(BOTTOM)
        buttonRow:SetTall(lyx.Scale(28))
        buttonRow.Paint = nil

        local loadBtn = vgui.Create("lyx.TextButton2", buttonRow)
        loadBtn:Dock(LEFT)
        loadBtn:SetWide(lyx.ScaleW(70))
        loadBtn:SetText("Load")
        loadBtn.DoClick = function()
            self:ApplyPreset(preset.data or {})
        end

        local deployBtn = vgui.Create("lyx.TextButton2", buttonRow)
        deployBtn:Dock(LEFT)
        deployBtn:DockMargin(lyx.ScaleW(6), 0, 0, 0)
        deployBtn:SetWide(lyx.ScaleW(80))
        deployBtn:SetText("Send")
        deployBtn.DoClick = function()
            self:ApplyPreset(preset.data or {})
            local payload = sanitizeOpsat(self.CurrentOpsat)
            gm3.opsatClientData = copyData(payload)
            net.Start("gm3:tools:opsatSet")
            net.WriteTable(payload)
            net.SendToServer()
        end

        local deleteBtn = vgui.Create("lyx.TextButton2", buttonRow)
        deleteBtn:Dock(RIGHT)
        deleteBtn:SetWide(lyx.ScaleW(70))
        deleteBtn:SetText("Delete")
        deleteBtn:SetBackgroundColor(Color(120, 35, 35))
        deleteBtn.DoClick = function()
            net.Start("gm3:tools:opsatDeletePreset")
            net.WriteString(preset.name or "")
            net.SendToServer()
        end
    end
end

function PANEL:ApplyPreset(data)
    self.CurrentOpsat = copyData(data)
    for key, entry in pairs(self.Fields or {}) do
        if IsValid(entry) then
            entry:SetText(self.CurrentOpsat[key] or OPSAT_DEFAULT[key])
        end
    end
    self:UpdatePreview()
end

function PANEL:UpdatePreview()
    if not IsValid(self.PreviewBody) then return end
    self.PreviewBody:InvalidateLayout(true)
end

function PANEL:SetPlayer()
end

function PANEL:Paint(w, h)
    draw.RoundedBox(4, 0, 0, w, h, lyx.Colors.Foreground)
end

vgui.Register("GM3.Pages.Opsat", PANEL)
