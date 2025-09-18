-- Basic Ent Stuff
ENT.Type = "anim"
ENT.Base = "base_gmodentity"
ENT.Category = "Gamemaster 3"
ENT.PrintName = "Model Giver"
ENT.Spawnable = true

function ENT:SetupDataTables()

    self:NetworkVar("String", 1, "ModelP")
    self:NetworkVar("String", 2, "CrateName")
end

