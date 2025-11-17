TOOL.Category = "GM3"
TOOL.Name = "#tool.gm3_supply.name"

TOOL.ClientConVar = {
    drop = "ammo"
}

if CLIENT then
    language.Add("tool.gm3_supply.name", "GM3 Supply Drop")
    language.Add("tool.gm3_supply.desc", "Call GM3 supply drops without opening Zeus")
    language.Add("tool.gm3_supply.0", "Left click to drop the selected crate.")
end

local drops = {
    ammo = "Ammo Crate",
    medical = "Medical Crate",
    tech = "Technology Drop",
    shield = "Shield Battery",
    turret = "Turret Kit"
}

local function CanUse(ply)
    return gm3 and gm3.SecurityCheck and gm3:SecurityCheck(ply) or false
end

function TOOL:LeftClick(trace)
    if CLIENT then
        local drop = string.Trim(self:GetClientInfo("drop") or "ammo")
        lyx:NetSend("gm3ZeusCam_supplyDrop", function()
            net.WriteVector(trace.HitPos)
            net.WriteString(drop)
        end)
        return true
    end
    return CanUse(self:GetOwner())
end

function TOOL.BuildCPanel(panel)
    panel:AddControl("Header", {Description = "Call in any GM3 supply crate from the standard Zeus options."})
    local combo = panel:ComboBox("Drop Type", "gm3_supply_drop")
    combo:AddChoice("Ammo", "ammo", true)
    combo:AddChoice("Medical", "medical")
    combo:AddChoice("Technology", "tech")
    combo:AddChoice("Shield", "shield")
    combo:AddChoice("Turret", "turret")
end
