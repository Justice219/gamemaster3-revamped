AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "base_anim"
ENT.PrintName = "GM3 Waypoint"
ENT.RenderGroup = RENDERGROUP_TRANSLUCENT

local waypointIcons = {
    flag = "icon16/flag.png",
    target = "icon16/cross.png",
    star = "icon16/star.png",
    alert = "icon16/exclamation.png",
    gear = "icon16/cog.png"
}

function ENT:SetupDataTables()
    self:NetworkVar("String", 0, "WaypointTitle")
    self:NetworkVar("String", 1, "WaypointSubtitle")
    self:NetworkVar("Vector", 0, "WaypointColor")
    self:NetworkVar("String", 2, "WaypointIcon")
end

if SERVER then
    function ENT:Initialize()
        self:SetModel("models/props_c17/utilityconnecter006c.mdl")
        self:SetModelScale(0.01, 0)
        self:SetMoveType(MOVETYPE_NONE)
        self:SetSolid(SOLID_NONE)
        self:SetCollisionGroup(COLLISION_GROUP_WORLD)
        self:DrawShadow(false)
    end

    function ENT:OnTakeDamage()
        return 0
    end
else
    local textFont = "GM3_Cam_Subtitle"

    local function GetWaypointIconMat(id)
        local path = waypointIcons[id] or waypointIcons.flag
        waypointIcons[id] = path
        return Material(path, "smooth")
    end

    function ENT:Draw()
        local pos = self:GetPos()
        local ply = LocalPlayer()
        if not IsValid(ply) then return end

        local colorVec = self:GetWaypointColor()
        local labelColor = Color(colorVec.x or 255, colorVec.y or 200, colorVec.z or 120)
        local ang = Angle(0, ply:EyeAngles().y - 90, 90)
        local title = self:GetWaypointTitle() ~= "" and self:GetWaypointTitle() or "Waypoint"
        local subtitle = self:GetWaypointSubtitle()
        local dist = math.Round(ply:GetPos():Distance(pos))
        local mat = GetWaypointIconMat(self:GetWaypointIcon())
        local iconSize = 32

        cam.Start3D2D(pos + Vector(0, 0, 70), ang, 0.12)
            surface.SetDrawColor(labelColor.r, labelColor.g, labelColor.b, 160)
            surface.DrawRect(-110, -50, 220, 100)
            surface.SetDrawColor(20, 20, 20, 230)
            surface.DrawRect(-106, -46, 212, 92)
            surface.SetMaterial(mat)
            surface.SetDrawColor(255, 255, 255)
            surface.DrawTexturedRect(-100, -16, iconSize, iconSize)
            draw.SimpleText(title, textFont, -60, -10, color_white, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
            local distText = string.format("%dm", math.floor(dist / 16))
            draw.SimpleText(distText, textFont, 100, -16, labelColor, TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP)
            if subtitle ~= "" then
                draw.SimpleText(subtitle, textFont, -60, 14, Color(200, 200, 200), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
            end
        cam.End3D2D()
    end
end
