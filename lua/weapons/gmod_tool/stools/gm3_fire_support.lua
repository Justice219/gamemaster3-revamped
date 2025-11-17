TOOL.Category = "GM3"
TOOL.Name = "#tool.gm3_fire_support.name"

TOOL.ClientConVar = {
    profile = "precision",
    warning = "6"
}

if CLIENT then
    language.Add("tool.gm3_fire_support.name", "GM3 Fire Support")
    language.Add("tool.gm3_fire_support.desc", "Call GM3 artillery without the Zeus camera")
    language.Add("tool.gm3_fire_support.0", "Left click to call selected fire support profile.")
end

local fireProfiles = {
    precision = {radius = 160, shells = 1, delay = 0.35, smoke = false},
    barrage = {radius = 340, shells = 5, delay = 0.7, smoke = false},
    carpet = {radius = 520, shells = 8, delay = 1.1, smoke = false},
    smoke = {radius = 260, shells = 4, delay = 0.5, smoke = true},
    incendiary = {radius = 260, shells = 4, delay = 0.5, smoke = false},
    emp = {radius = 220, shells = 2, delay = 0.8, smoke = false}
}

local function CanUse(ply)
    return gm3 and gm3.SecurityCheck and gm3:SecurityCheck(ply) or false
end

function TOOL:LeftClick(trace)
    if CLIENT then
        local profileId = self:GetClientInfo("profile") or "precision"
        local data = fireProfiles[profileId]
        if not data then return true end
        local warning = math.Clamp(self:GetClientNumber("warning") or 6, 1, 120)
        lyx:NetSend("gm3ZeusCam_callArtillery", function()
            net.WriteVector(trace.HitPos)
            net.WriteUInt(math.Clamp(data.radius, 50, 1023), 12)
            net.WriteUInt(math.Clamp(data.shells, 1, 12), 4)
            net.WriteFloat(math.Clamp(data.delay, 0.1, 3))
            net.WriteBool(data.smoke and true or false)
            net.WriteFloat(warning)
            net.WriteString(profileId)
        end)
        return true
    end
    return CanUse(self:GetOwner())
end

function TOOL.BuildCPanel(panel)
    panel:AddControl("Header", {Description = "Call any GM3 fire support profile directly."})
    local combo = panel:ComboBox("Profile", "gm3_fire_support_profile")
    combo:AddChoice("Precision Strike", "precision", true)
    combo:AddChoice("Heavy Barrage", "barrage")
    combo:AddChoice("Carpet Bomb", "carpet")
    combo:AddChoice("Smoke Screen", "smoke")
    combo:AddChoice("Incendiary", "incendiary")
    combo:AddChoice("EMP Blast", "emp")

    panel:NumSlider("Warning Delay (sec)", "gm3_fire_support_warning", 1, 60, 0)
end
