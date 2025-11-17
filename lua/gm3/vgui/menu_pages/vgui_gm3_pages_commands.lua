gm3.commands = gm3.commands or {}
local PANEL = {}

lyx.RegisterFont("GM3.Components.Commands", "Open Sans SemiBold", 20)

function PANEL:Init()
    local cmd = {
        color1 = Color(255, 255, 255),
        color2 = Color(255, 255, 255),
        useHeader = false,
        showPlayerName = false,
        command = "/command",
        ranks = {}
    }

    self.ScrollPanel = vgui.Create("DScrollPanel", self)
    self.ScrollPanel:Dock(FILL)
    self.ScrollPanel:DockMargin(lyx.ScaleW(10), lyx.Scale(10), lyx.ScaleW(10), lyx.Scale(10))

    local function setCommandExample()
        if not IsValid(self.CommandExample) then return end

        local primary = cmd.color1 or color_white
        local secondary = cmd.color2 or color_white

        self.CommandExample:SetText("")
        self.CommandExample:InsertColorChange(primary.r, primary.g, primary.b, 255)
        if cmd.useHeader and isstring(cmd.command) and cmd.command ~= "" then
            if string.sub(cmd.command, 1, 1) == "/" and #cmd.command > 1 then
                self.CommandExample:AppendText(string.upper("[" .. string.sub(cmd.command, 2) .. "] "))
            else
                self.CommandExample:AppendText(string.upper("[" .. cmd.command .. "] "))
            end
        end
        if cmd.showPlayerName then
            self.CommandExample:AppendText(LocalPlayer():Nick() .. ": ")
        end
        self.CommandExample:InsertColorChange(secondary.r, secondary.g, secondary.b, 255)
        self.CommandExample:AppendText("Typed Message will show here.")
    end

    local function setCheckboxValue(box, value)
        if not IsValid(box) then return end
        if box.SetChecked then
            box:SetChecked(value)
        elseif box.SetValue then
            box:SetValue(value and 1 or 0)
        end
    end

    local FormCard = vgui.Create("DPanel", self.ScrollPanel)
    FormCard:Dock(TOP)
    FormCard:DockMargin(lyx.ScaleW(5), 0, lyx.ScaleW(5), lyx.Scale(8))
    FormCard:DockPadding(lyx.ScaleW(16), lyx.Scale(16), lyx.ScaleW(16), lyx.Scale(16))
    FormCard.Paint = function(_, w, h)
        draw.RoundedBox(8, 0, 0, w, h, Color(18, 18, 18, 235))
        surface.SetDrawColor(255, 255, 255, 5)
        surface.DrawOutlinedRect(0, 0, w, h, 1)
    end

    local HeaderLabel = vgui.Create("lyx.Label2", FormCard)
    HeaderLabel:Dock(TOP)
    HeaderLabel:SetFont("GM3.Components.Commands")
    HeaderLabel:SetTall(lyx.Scale(30))
    HeaderLabel:SetText("Create Chat Command")

    local Subtext = vgui.Create("lyx.Label2", FormCard)
    Subtext:Dock(TOP)
    Subtext:DockMargin(0, 0, 0, lyx.Scale(8))
    Subtext:SetTall(lyx.Scale(18))
    Subtext:SetText("Configure the visual styling and behaviour before saving.")

    self.CommandEntry = vgui.Create("lyx.TextEntry2", FormCard)
    self.CommandEntry:Dock(TOP)
    self.CommandEntry:SetTall(lyx.Scale(40))
    self.CommandEntry:SetPlaceholderText("ex. /force")
    self.CommandEntry:SetText(cmd.command)
    function self.CommandEntry:OnValueChange(value)
        value = value or ""
        if string.find(value, " ", 1, true) then
            chat.AddText(Color(255, 0, 0), "No spaces allowed in command.")
            local cleaned = string.gsub(value, "%s+", "")
            if cleaned ~= value then
                self:SetText(cleaned)
            end
            return
        end

        cmd.command = value ~= "" and value or "/command"
        setCommandExample()
    end

    local ColorsRow = vgui.Create("DPanel", FormCard)
    ColorsRow:Dock(TOP)
    ColorsRow:SetTall(lyx.Scale(150))
    ColorsRow:DockMargin(0, lyx.Scale(12), 0, lyx.Scale(6))
    ColorsRow.Paint = function() end

    function ColorsRow:PerformLayout(w)
        if IsValid(self.PrimaryContainer) then
            self.PrimaryContainer:SetWide(w * 0.5 - lyx.ScaleW(6))
        end
        if IsValid(self.SecondaryContainer) then
            self.SecondaryContainer:SetWide(w * 0.5 - lyx.ScaleW(6))
        end
    end

    local function buildColorMixer(storageKey, title, onChanged)
        local container = vgui.Create("DPanel", ColorsRow)
        container:Dock(LEFT)
        container:DockMargin(0, 0, lyx.ScaleW(12), 0)
        ColorsRow[storageKey] = container
        container.Paint = function() end

        local label = vgui.Create("lyx.Label2", container)
        label:Dock(TOP)
        label:SetFont("GM3.Components.Commands")
        label:SetTall(lyx.Scale(20))
        label:SetText(title)

        local mixer = vgui.Create("DColorMixer", container)
        mixer:Dock(FILL)
        mixer:SetPalette(false)
        mixer:SetAlphaBar(false)
        function mixer:ValueChanged(value)
            onChanged(self, value)
        end

        return mixer
    end

    local PrimaryColor = buildColorMixer("PrimaryContainer", "Primary Text Colour", function(panel)
        cmd.color1 = panel:GetColor()
        setCommandExample()
    end)
    local SecondaryColor = buildColorMixer("SecondaryContainer", "Secondary Text Colour", function(panel)
        cmd.color2 = panel:GetColor()
        setCommandExample()
    end)

    PrimaryColor:SetColor(cmd.color1)
    SecondaryColor:SetColor(cmd.color2)

    local TogglesRow = vgui.Create("DPanel", FormCard)
    TogglesRow:Dock(TOP)
    TogglesRow:SetTall(lyx.Scale(80))
    TogglesRow:DockMargin(0, lyx.Scale(4), 0, lyx.Scale(6))
    TogglesRow.Paint = function() end

    local function buildToggleColumn(title, description, onToggled)
        local container = vgui.Create("DPanel", TogglesRow)
        container:Dock(LEFT)
        container:SetWide(lyx.ScaleW(230))
        container:DockMargin(0, 0, lyx.ScaleW(12), 0)
        container.Paint = function() end

        local label = vgui.Create("lyx.Label2", container)
        label:Dock(TOP)
        label:SetFont("GM3.Components.Commands")
        label:SetTall(lyx.Scale(20))
        label:SetText(title)

        local desc = vgui.Create("lyx.Label2", container)
        desc:Dock(TOP)
        desc:SetTall(lyx.Scale(16))
        desc:SetText(description)
        desc:SetTextColor(Color(189, 189, 189))

        local checkbox = vgui.Create("lyx.Checkbox2", container)
        checkbox:Dock(TOP)
        checkbox:SetTall(lyx.Scale(18))
        checkbox:SetText("Enabled")
        checkbox.OnToggled = function(_, val)
            onToggled(val)
        end

        return checkbox
    end

    self.HeaderCheckbox = buildToggleColumn("Header Prefix", "Adds [COMMAND] before the message.", function(val)
        cmd.useHeader = val
        setCommandExample()
    end)

    self.ShowPlayerNameCheckbox = buildToggleColumn("Player Name", "Show sender name before text.", function(val)
        cmd.showPlayerName = val
        setCommandExample()
    end)

    local PreviewWrapper = vgui.Create("DPanel", FormCard)
    PreviewWrapper:Dock(TOP)
    PreviewWrapper:SetTall(lyx.Scale(90))
    PreviewWrapper:DockMargin(0, lyx.Scale(8), 0, lyx.Scale(8))
    PreviewWrapper:DockPadding(lyx.ScaleW(10), lyx.Scale(6), lyx.ScaleW(10), lyx.Scale(10))
    PreviewWrapper.Paint = function(_, w, h)
        draw.RoundedBox(6, 0, 0, w, h, Color(9, 9, 9, 220))
    end

    local PreviewLabel = vgui.Create("lyx.Label2", PreviewWrapper)
    PreviewLabel:Dock(TOP)
    PreviewLabel:SetTall(lyx.Scale(18))
    PreviewLabel:SetFont("GM3.Components.Commands")
    PreviewLabel:SetText("Live Preview")

    self.CommandExample = vgui.Create("RichText", PreviewWrapper)
    self.CommandExample:Dock(FILL)
    function self.CommandExample:PerformLayout()
        self:SetFontInternal("Roboto Black")
    end

    local ButtonRow = vgui.Create("DPanel", FormCard)
    ButtonRow:Dock(TOP)
    ButtonRow:SetTall(lyx.Scale(40))
    ButtonRow:DockMargin(0, lyx.Scale(4), 0, 0)
    ButtonRow.Paint = function() end

    local CreateButton = vgui.Create("lyx.TextButton2", ButtonRow)
    CreateButton:Dock(FILL)
    CreateButton:SetText("Save Command")
    CreateButton:SetBackgroundColor(Color(63, 61, 61))
    CreateButton.DoClick = function()
        net.Start("gm3:command:create")
            net.WriteTable(cmd)
        net.SendToServer()

        gm3:SyncReopenMenu("Commands")
    end

    local ResetButton = vgui.Create("lyx.TextButton2", ButtonRow)
    ResetButton:Dock(RIGHT)
    ResetButton:DockMargin(lyx.ScaleW(8), 0, 0, 0)
    ResetButton:SetWide(lyx.ScaleW(140))
    ResetButton:SetText("Reset Fields")
    ResetButton:SetBackgroundColor(Color(34, 32, 32))
    ResetButton.DoClick = function()
        cmd = {
            color1 = Color(255, 255, 255),
            color2 = Color(255, 255, 255),
            useHeader = false,
            showPlayerName = false,
            command = "/command",
            ranks = {}
        }

        setCheckboxValue(self.HeaderCheckbox, false)
        setCheckboxValue(self.ShowPlayerNameCheckbox, false)
        self.CommandEntry:SetText(cmd.command)
        PrimaryColor:SetColor(cmd.color1)
        SecondaryColor:SetColor(cmd.color2)
        setCommandExample()
    end

    FormCard:InvalidateLayout(true)
    FormCard:SizeToChildren(false, true)
    timer.Simple(0, function()
        if IsValid(FormCard) then
            FormCard:SizeToChildren(false, true)
        end
    end)

    local commands = {}
    for _, data in pairs(gm3.commands or {}) do
        table.insert(commands, data)
    end
    table.sort(commands, function(a, b)
        return string.lower(a.command or "") < string.lower(b.command or "")
    end)

    if #commands == 0 then
        local EmptyLabel = vgui.Create("lyx.Label2", self.ScrollPanel)
        EmptyLabel:Dock(TOP)
        EmptyLabel:DockMargin(lyx.ScaleW(5), lyx.Scale(15), lyx.ScaleW(5), 0)
        EmptyLabel:SetTall(lyx.Scale(24))
        EmptyLabel:SetFont("GM3.Components.Commands")
        EmptyLabel:SetText("No commands created yet. Use the form above to get started.")
        EmptyLabel:SetContentAlignment(5)
    else
        local ListLabel = vgui.Create("lyx.Label2", self.ScrollPanel)
        ListLabel:Dock(TOP)
        ListLabel:DockMargin(lyx.ScaleW(5), lyx.Scale(12), lyx.ScaleW(5), lyx.Scale(2))
        ListLabel:SetTall(lyx.Scale(24))
        ListLabel:SetFont("GM3.Components.Commands")
        ListLabel:SetText("Existing Commands")
    end

    for _, v in ipairs(commands) do
        local Module = vgui.Create("GM3.Components.Command", self.ScrollPanel)
        Module:Dock(TOP)
        Module:DockMargin(lyx.ScaleW(5), lyx.Scale(10), lyx.ScaleW(5), 0)
        Module:SetCommand(v)
    end

    setCommandExample()
end

function PANEL:Paint(w, h)
    draw.RoundedBox(4, 0, 0, w, h, lyx.Colors.Foreground)
end

vgui.Register("GM3.Pages.Commands", PANEL)
