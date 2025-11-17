local PANEL = {}

function PANEL:Init()
    self:DockPadding(lyx.ScaleW(16), lyx.Scale(14), lyx.ScaleW(16), lyx.Scale(14))
end

lyx.RegisterFont("GM3.Components.Rank", "Open Sans SemiBold", 20)
lyx.RegisterFont("GM3.Components.RankSmall", "Open Sans", 16)

function PANEL:SetRank(name, panel)
    self.rankName = name

    local Header = vgui.Create("DPanel", self)
    Header:Dock(TOP)
    Header:SetTall(lyx.Scale(32))
    Header.Paint = function() end

    local Label = vgui.Create("lyx.Label2", Header)
    Label:Dock(LEFT)
    Label:SetFont("GM3.Components.Rank")
    Label:SetText(name)
    Label:SetWide(lyx.ScaleW(200))

    local PanelDesc = vgui.Create("lyx.Label2", Header)
    PanelDesc:Dock(FILL)
    PanelDesc:SetFont("GM3.Components.RankSmall")
    PanelDesc:SetText("Panel Access")

    self.Checkbox = vgui.Create("lyx.Checkbox2", self)
    self.Checkbox:Dock(TOP)
    self.Checkbox:SetTall(lyx.Scale(18))
    self.Checkbox:SetText(panel and "Has access" or "No access")
    self.Checkbox:SetToggle(panel)
    self.Checkbox.OnToggled = function(_, val)
        self.Checkbox:SetText(val and "Has access" or "No access")
    end

    local ButtonRow = vgui.Create("DPanel", self)
    ButtonRow:Dock(TOP)
    ButtonRow:SetTall(lyx.Scale(40))
    ButtonRow:DockMargin(0, lyx.Scale(8), 0, 0)
    ButtonRow.Paint = function() end

    local RemoveRank = vgui.Create("lyx.TextButton2", ButtonRow)
    RemoveRank:Dock(LEFT)
    RemoveRank:SetWide(lyx.ScaleW(140))
    RemoveRank:SetText("Remove Rank")
    RemoveRank:SetBackgroundColor(Color(111, 28, 28))
    RemoveRank.DoClick = function()
        surface.PlaySound("buttons/button10.wav")

        net.Start("gm3:rank:remove")
            net.WriteString(name)
        net.SendToServer()

        self:Remove()
    end

    local SaveRank = vgui.Create("lyx.TextButton2", ButtonRow)
    SaveRank:Dock(RIGHT)
    SaveRank:SetWide(lyx.ScaleW(140))
    SaveRank:SetText("Save Changes")
    SaveRank:SetBackgroundColor(Color(63, 61, 61))
    SaveRank.DoClick = function()
        surface.PlaySound("buttons/button10.wav")

        net.Start("gm3:rank:save")
            net.WriteString(name)
            net.WriteBool(self.Checkbox:GetToggle())
        net.SendToServer()

        gm3:SyncReopenMenu("Ranks")
    end
end

function PANEL:Paint(w, h)
    draw.RoundedBox(6, 0, 0, w, h, Color(14, 11, 11, 160))
    surface.SetDrawColor(255, 255, 255, 4)
    surface.DrawOutlinedRect(0, 0, w, h)
end

vgui.Register("GM3.Components.Rank", PANEL)
