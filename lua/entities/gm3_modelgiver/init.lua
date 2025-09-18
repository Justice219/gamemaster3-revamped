AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")
AddCSLuaFile("lyx_core/thirdparty/cl_lyx_imgui.lua")

include("shared.lua")

function ENT:Initialize()

    -- Setup ent basics
    self:SetModel("models/lordtrilobite/starwars/props/kyber_crate_phys.mdl")
    self:PhysicsInit(SOLID_VPHYSICS)
    self:SetMoveType(MOVETYPE_VPHYSICS)
    self:SetSolid(SOLID_VPHYSICS)
    self:SetUseType(SIMPLE_USE)

    -- Set Values n shit
    self:SetModelP("models/player/skeleton.mdl")
    self:SetCrateName("Skeleton")

    local phys = self:GetPhysicsObject()
    if phys:IsValid() then
        phys:Wake()
    end

end

function ENT:GiveWeapon(ply)
    ply:Give(self:GetWeaponP())
end

function ENT:Use(act, caller)
    act:SetModel(self:GetModelP())
end

function ENT:SetData(str, name)
    self:SetModelP(str)
    self:SetCrateName(name)
end