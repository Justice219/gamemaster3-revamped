local PANEL = {}

lyx.RegisterFont("GM3.Pages.Server", "Open Sans SemiBold", 20)
surface.CreateFont("OpsatColors", {
    font = "Roboto Bold",
    size = lyx.Scale(22),
    weight = 1000,
    antialias = true,
    shadow = false
})

function PANEL:Init()
    self.ScrollPanel = self.ScrollPanel or vgui.Create("lyx.ScrollPanel2", self)
    self.ScrollPanel:Dock(FILL)

    local zeusPanel = vgui.Create("DPanel", self.ScrollPanel)
    zeusPanel:Dock(TOP)
    zeusPanel:DockMargin(0, 0, lyx.Scale(5), lyx.Scale(10))
    zeusPanel:SetTall(lyx.Scale(60))
    zeusPanel.Paint = function(_, w, h)
        draw.RoundedBox(6, 0, 0, w, h, lyx.Colors.Foreground)
        draw.SimpleText("Zeus Mode", "Lyx.Title", lyx.Scale(10), lyx.Scale(10), color_white, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
        draw.SimpleText("Toggle the top-down Gamemaster camera.", "Lyx.Title", lyx.Scale(10), lyx.Scale(30), Color(220, 220, 220), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
    end
    self.ScrollPanel:AddItem(zeusPanel)

    local toggleBtn = vgui.Create("lyx.TextButton2", zeusPanel)
    toggleBtn:Dock(RIGHT)
    toggleBtn:DockMargin(0, lyx.Scale(12), lyx.Scale(12), lyx.Scale(12))
    toggleBtn:SetWide(lyx.Scale(180))
    toggleBtn:SetText("Toggle Zeus Mode")
    toggleBtn.DoClick = function()
        if gm3ZeusCam and gm3ZeusCam.RequestToggle then
            gm3ZeusCam:RequestToggle()
        else
            RunConsoleCommand("gm3Cam_toggle")
        end
    end

    local categories = {}

    for k,v in pairs(gm3.settings) do
        if v.type == "boolean" then
            self:AddCheckbox(v.nickname, v.value, function(value)
                net.Start("gm3:setting:change")
                    net.WriteTable({
                        key = k,
                        value = value
                    })
                net.SendToServer()
                gm3:SyncReopenMenu("Server")
            end)
        elseif v.type == "table" then
            self:AddColorMixer(v.nickname, Color(v.value.r, v.value.g, v.value.b, v.value.a), function(value)
                net.Start("gm3:setting:change")
                    net.WriteTable({
                        key = k,
                        value = value
                    })
                net.SendToServer()
                --gm3:SyncReopenMenu("Server")
            end, Color(v.default.r, v.default.g, v.default.b, v.default.a))
        end
    end

end

function PANEL:UpdateSettings(key, value)
    -- net.Start("mprr:restriction:job:edit")
    --     net.WriteTable({
    --         job = self.JobName,
    --         key = key,
    --         value = value
    --     })
    -- net.SendToServer()
end

vgui.Register("GM3.Pages.Server", PANEL, "lyx.PageBase")
