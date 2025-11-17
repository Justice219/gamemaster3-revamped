local PANEL = {}

function PANEL:Init()
end

lyx.RegisterFont("GM3.Components.Command", "Open Sans SemiBold", 20)
surface.CreateFont("Roboto Black", {
    font = "Roboto Bold",
    size = lyx.Scale(16),
    weight = 1000,
    antialias = true,
    shadow = false
})

function PANEL:SetCommand(cmd)
    self.cmd = cmd
    cmd.ranks = cmd.ranks or {}

    self:DockPadding(lyx.ScaleW(16), lyx.Scale(14), lyx.ScaleW(16), lyx.Scale(14))
    self:SetTall(lyx.Scale(190))

    local Header = vgui.Create("DPanel", self)
    Header:Dock(TOP)
    Header:SetTall(lyx.Scale(32))
    Header.Paint = function() end

    local commandText = isstring(cmd.command) and cmd.command or "/command"
    self.Label = vgui.Create("lyx.Label2", Header)
    self.Label:Dock(LEFT)
    self.Label:SetWide(lyx.ScaleW(220))
    self.Label:DockMargin(0, 0, lyx.ScaleW(8), 0)
    self.Label:SetText(commandText)
    self.Label:SetFont("GM3.Components.Command")

    local RankInfo = vgui.Create("lyx.Label2", Header)
    RankInfo:Dock(FILL)
    local rankNames = {}
    for rank, allowed in pairs(cmd.ranks) do
        if allowed then
            table.insert(rankNames, rank)
        end
    end
    table.sort(rankNames, function(a, b) return string.lower(a) < string.lower(b) end)
    if #rankNames == 0 then
        RankInfo:SetText("Accessible by all ranks")
    else
        RankInfo:SetText("Allowed: " .. table.concat(rankNames, ", "))
    end

    local PreviewWrapper = vgui.Create("DPanel", self)
    PreviewWrapper:Dock(TOP)
    PreviewWrapper:SetTall(lyx.Scale(70))
    PreviewWrapper:DockMargin(0, lyx.Scale(6), 0, lyx.Scale(6))
    PreviewWrapper:DockPadding(lyx.ScaleW(10), lyx.Scale(6), lyx.ScaleW(10), lyx.Scale(8))
    PreviewWrapper.Paint = function(_, w, h)
        draw.RoundedBox(6, 0, 0, w, h, Color(0, 0, 0, 180))
    end

    local PreviewLabel = vgui.Create("lyx.Label2", PreviewWrapper)
    PreviewLabel:Dock(TOP)
    PreviewLabel:SetTall(lyx.Scale(18))
    PreviewLabel:SetFont("GM3.Components.Command")
    PreviewLabel:SetText("Preview")

    self.CommandExample = vgui.Create("RichText", PreviewWrapper)
    self.CommandExample:Dock(FILL)
    function self.CommandExample:PerformLayout()
        self:SetFontInternal("Roboto Black")
    end

    local function setCommandExample()
        local primary = cmd.color1 or color_white
        local secondary = cmd.color2 or color_white

        self.CommandExample:SetText("")
        self.CommandExample:InsertColorChange(primary.r, primary.g, primary.b, 255)
        if cmd.useHeader and commandText ~= "" then
            if string.sub(commandText, 1, 1) == "/" and #commandText > 1 then
                self.CommandExample:AppendText(string.upper("[" .. string.sub(commandText, 2) .. "] "))
            else
                self.CommandExample:AppendText(string.upper("[" .. commandText .. "] "))
            end
        end
        if cmd.showPlayerName then
            self.CommandExample:AppendText(LocalPlayer():Nick() .. ": ")
        end
        self.CommandExample:InsertColorChange(secondary.r, secondary.g, secondary.b, 255)
        self.CommandExample:AppendText("Typed Message will show here.")
    end

    setCommandExample()

    local ButtonsRow = vgui.Create("DPanel", self)
    ButtonsRow:Dock(TOP)
    ButtonsRow:SetTall(lyx.Scale(36))
    ButtonsRow:DockMargin(0, lyx.Scale(4), 0, 0)
    ButtonsRow.Paint = function() end

    local EditRanks = vgui.Create("lyx.TextButton2", ButtonsRow)
    EditRanks:Dock(LEFT)
    EditRanks:SetWide(lyx.ScaleW(150))
    EditRanks:SetText("Edit Ranks")
    EditRanks:SetBackgroundColor(Color(63,61,61))
    EditRanks.DoClick = function()
        for k,_ in pairs(cmd.ranks) do
            if not gm3.ranks[k] then
                cmd.ranks[k] = nil
                net.Start("gm3:command:removeRank")
                    net.WriteString(commandText)
                    net.WriteString(k)
                net.SendToServer()
            end
        end

        local menu = DermaMenu()
        for k, _ in pairs(gm3.ranks) do
            if cmd.ranks[k] then
                menu:AddOption(k, function()
                    net.Start("gm3:command:removeRank")
                        net.WriteString(commandText)
                        net.WriteString(k)
                    net.SendToServer()
                    gm3:SyncReopenMenu("Commands")
                end):SetIcon("icon16/tick.png")
            else
                menu:AddOption(k, function()
                    net.Start("gm3:command:addRank")
                        net.WriteString(commandText)
                        net.WriteString(k)
                    net.SendToServer()
                    gm3:SyncReopenMenu("Commands")
                end):SetIcon("icon16/cross.png")
            end
        end
        menu:Open()
    end

    local RemoveButton = vgui.Create("lyx.TextButton2", ButtonsRow)
    RemoveButton:Dock(RIGHT)
    RemoveButton:SetWide(lyx.ScaleW(180))
    RemoveButton:SetText("Remove Chat Command")
    RemoveButton:SetBackgroundColor(Color(111, 28, 28))
    RemoveButton.DoClick = function()
        net.Start("gm3:command:remove")
            net.WriteString(commandText)
        net.SendToServer()

        gm3:SyncReopenMenu("Commands")
    end
end

function PANEL:Resize()
    self:SetTall(self.Height)
end

function PANEL:Paint(w, h)
    draw.RoundedBox(6, 0, 0, w, h, Color(14, 11, 11, 160))
    surface.SetDrawColor(255, 255, 255, 4)
    surface.DrawOutlinedRect(0, 0, w, h)
end

vgui.Register("GM3.Components.Command", PANEL)
