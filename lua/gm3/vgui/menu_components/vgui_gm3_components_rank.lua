local PANEL = {}

function PANEL:Init()

end

lyx.RegisterFont("GM3.Components.Rank", "Open Sans SemiBold", 20)

function PANEL:SetRank(name, panel) 
    self.Label = vgui.Create("lyx.Label2", self)
    self.Label:SetText(name)
    self.Label:Dock(LEFT)
    self.Label:DockMargin(lyx.ScaleW(15), lyx.Scale(14), lyx.ScaleW(0), lyx.Scale(0))
    self.Label:SetFont("GM3.Components.Rank")
    self.Label:SetWide(lyx.Scale(100))

    // panel label
    self.PanelAccess = vgui.Create("lyx.Label2", self)
    self.PanelAccess:SetText("Has panel access?")
    self.PanelAccess:Dock(TOP)
    self.PanelAccess:DockMargin(lyx.ScaleW(15), lyx.Scale(14), lyx.ScaleW(0), lyx.Scale(0))
    self.PanelAccess:SetTall(25)
    self.PanelAccess:SetFont("GM3.Components.Rank")

    local checkbox = vgui.Create("lyx.Checkbox2", self)
    checkbox:Dock(TOP)
    checkbox:DockMargin(lyx.ScaleW(10), lyx.Scale(10), lyx.ScaleW(10), lyx.Scale(10))
    checkbox:SetTall(lyx.Scale(15))
    checkbox:SetToggle(panel)

    self.RemoveRank = vgui.Create("lyx.TextButton2", self)
    self.RemoveRank:SetText("Remove")
    self.RemoveRank:SetFont("GM3.Components.Rank")
    self.RemoveRank:Dock(TOP)
    self.RemoveRank:DockMargin(lyx.ScaleW(0), lyx.Scale(12), lyx.ScaleW(15), lyx.Scale(12))
    self.RemoveRank.DoClick = function()
         surface.PlaySound("buttons/button10.wav")

         net.Start("gm3:rank:remove")
            net.WriteString(name)   
        net.SendToServer()

        self:Remove()
    end

    self.SaveRank = vgui.Create("lyx.TextButton2", self)
    self.SaveRank:SetText("Save")
    self.SaveRank:SetFont("GM3.Components.Rank")
    self.SaveRank:Dock(TOP)
    self.SaveRank:DockMargin(lyx.ScaleW(0), lyx.Scale(12), lyx.ScaleW(15), lyx.Scale(12))
    self.SaveRank.DoClick = function()
         surface.PlaySound("buttons/button10.wav")

         net.Start("gm3:rank:save")
            net.WriteString(name)
            net.WriteBool(checkbox:GetToggle())
        net.SendToServer()

        gm3:SyncReopenMenu("Ranks")
    end
end

function PANEL:Paint(w, h)
    draw.RoundedBox(4, 0, 0, w, h, lyx.Colors.Foreground)
end

vgui.Register("GM3.Components.Rank", PANEL)