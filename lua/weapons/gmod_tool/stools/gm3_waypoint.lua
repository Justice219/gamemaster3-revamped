TOOL.Category = "GM3"
TOOL.Name = "#tool.gm3_waypoint.name"

TOOL.ClientConVar = {
    title = "Waypoint",
    subtitle = "",
    icon = "flag",
    color_r = "255",
    color_g = "200",
    color_b = "120"
}

if CLIENT then
    language.Add("tool.gm3_waypoint.name", "GM3 Waypoint")
    language.Add("tool.gm3_waypoint.desc", "Place GM3 waypoints without the Zeus UI")
    language.Add("tool.gm3_waypoint.0", "Left click to place a waypoint. Right click an existing waypoint to edit/remove it (else open manager).")
end

local function CanUse(ply)
    if not gm3 or not gm3.SecurityCheck then return false end
    return gm3:SecurityCheck(ply)
end

function TOOL:LeftClick(trace)
    if CLIENT then
        local color = Color(
            math.Clamp(tonumber(self:GetClientNumber("color_r")) or 255, 0, 255),
            math.Clamp(tonumber(self:GetClientNumber("color_g")) or 200, 0, 255),
            math.Clamp(tonumber(self:GetClientNumber("color_b")) or 120, 0, 255)
        )
        local icon = string.Trim(self:GetClientInfo("icon") or "flag")
        local title = string.sub(self:GetClientInfo("title") or "Waypoint", 1, 40)
        local subtitle = string.sub(self:GetClientInfo("subtitle") or "", 1, 60)
        lyx:NetSend("gm3ZeusCam_createWaypoint", function()
            net.WriteVector(trace.HitPos)
            net.WriteString(title)
            net.WriteString(subtitle)
            net.WriteUInt(color.r, 8)
            net.WriteUInt(color.g, 8)
            net.WriteUInt(color.b, 8)
            net.WriteString(icon)
        end)
        return true
    end
    return CanUse(self:GetOwner())
end

function TOOL:RightClick(trace)
    if CLIENT then
        local ent = trace.Entity
        if IsValid(ent) and ent:GetClass() == "gm3_waypoint" then
            local menu = DermaMenu()
            menu:AddOption("Edit Waypoint", function()
                if gm3ZeusCam and gm3ZeusCam.OpenWaypointManager then
                    gm3ZeusCam:OpenWaypointManager()
                    timer.Simple(0, function()
                        if gm3ZeusCam.PopulateWaypointEditor then
                            gm3ZeusCam:PopulateWaypointEditor(ent)
                        end
                    end)
                end
            end):SetIcon("icon16/pencil.png")
            menu:AddOption("Remove Waypoint", function()
                if gm3ZeusCam and gm3ZeusCam.RemoveWaypoint then
                    gm3ZeusCam:RemoveWaypoint(ent)
                end
            end):SetIcon("icon16/flag_delete.png")
            menu:Open()
        else
            if gm3ZeusCam and gm3ZeusCam.OpenWaypointManager then
                gm3ZeusCam:OpenWaypointManager()
            end
        end
    end
    return true
end

function TOOL.BuildCPanel(panel)
    panel:AddControl("Header", {Description = "Drop GM3 waypoints anywhere without opening the Zeus suite."})
    panel:AddControl("TextBox", {Label = "Title", Command = "gm3_waypoint_title"})
    panel:AddControl("TextBox", {Label = "Subtitle", Command = "gm3_waypoint_subtitle"})

    local iconCombo = panel:ComboBox("Icon", "gm3_waypoint_icon")
    iconCombo:AddChoice("Flag", "flag", true)
    iconCombo:AddChoice("Target", "target")
    iconCombo:AddChoice("Star", "star")
    iconCombo:AddChoice("Alert", "alert")
    iconCombo:AddChoice("Objective", "gear")

    local mixer = vgui.Create("DColorMixer", panel)
    mixer:SetAlphaBar(false)
    mixer:SetPalette(true)
    mixer:SetColor(Color(255, 200, 120))
    mixer.ValueChanged = function(_, col)
        RunConsoleCommand("gm3_waypoint_color_r", tostring(math.floor(col.r)))
        RunConsoleCommand("gm3_waypoint_color_g", tostring(math.floor(col.g)))
        RunConsoleCommand("gm3_waypoint_color_b", tostring(math.floor(col.b)))
    end
    panel:AddItem(mixer)
end
