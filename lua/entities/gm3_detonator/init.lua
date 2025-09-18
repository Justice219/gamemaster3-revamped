AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")
AddCSLuaFile("lyx_core/thirdparty/cl_lyx_imgui.lua")
include("shared.lua")

function ENT:Initialize()

    -- Setup ent basics
    self:SetModel("models/props_lab/reciever01d.mdl")
    self:PhysicsInit(SOLID_VPHYSICS)
    self:SetMoveType(MOVETYPE_VPHYSICS)
    self:SetSolid(SOLID_VPHYSICS)
    self:SetUseType(SIMPLE_USE)
    self:SetSkin(1)

    self:SetIsExploding(false)
    self:SetBeenPlaced(false)
    self:SetExplosionTime(10)


    local phys = self:GetPhysicsObject()
    if phys:IsValid() then
        phys:Wake()
    end

end

function ENT:Use(act, caller)
    if !self:GetBeenPlaced() then
        self:SetBeenPlaced(true)

        self:SetMaterial("")
    else
        if !self:GetIsExploding() then
            self:Explode()
            lyx:MessagePlayer({
                ["type"] = "header",
                ["color1"] = Color(151,38,62),
                ["header"] = "Detonator",["color2"] = Color(255,255,255),
                ["text"] = "Detpack has been activated!",
                ["ply"] = act
            })
        end
    end
end

function ENT:ExplodeEffect()
    local effectdata = EffectData()
    effectdata:SetOrigin(self:GetPos())
    effectdata:SetScale(1)
    effectdata:SetMagnitude(1)
    util.Effect("Explosion", effectdata)
end

function ENT:Explode()
    timer.Create("gm3_detonator_".. self:EntIndex(), self:GetExplosionTime(), 1, function()
        for k,v in pairs(constraint.FindConstraints(self, "Weld")) do
            print(v)
        end
        self:Remove()
        if IsValid(self:GetParentProp()) then
            self:GetParentProp():Remove()
        end
        self:ExplodeEffect()
    end)
    self:SetIsExploding(true)
end

function ENT:Delete()
    if self:GetIsExploding() then
        timer.Remove("gm3_detonator_".. self:EntIndex())
    end
    self:Remove()
end

function ENT:Think()
    if self:GetIsExploding() then
        self:SetTimeLeft(timer.TimeLeft("gm3_detonator_" .. self:EntIndex()))
    end
end

function ENT:SetData(time, prop)
    self:SetExplosionTime(time)
    self:SetParentProp(prop)
end