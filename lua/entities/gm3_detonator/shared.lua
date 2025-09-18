-- Basic Ent Stuff
ENT.Type = "anim"
ENT.Base = "base_gmodentity"
ENT.Category = "Gamemaster 3"
ENT.PrintName = "Detonator"
ENT.Spawnable = false 

function ENT:SetupDataTables()

    --[[self:NetworkVar("Entity", 0, "owning_ent")
    self:NetworkVar("Bool" , 1 , "HasBeenLooted")
    self:NetworkVar("Int", 1, "TrashItem")
    self:NetworkVar("Int" , 2 , "RegenTimeLeft")
    self:NetworkVar("Bool" , 2 , "Regenerating")
    self:NetworkVar("Int" , 3 , "LootStage")
    self:NetworkVar("Int" , 4 , "TimerID")--]]

    self:NetworkVar("Entity", 0, "ParentProp")
    self:NetworkVar("Bool", 1, "IsExploding")
    self:NetworkVar("Bool", 2, "BeenPlaced")
    self:NetworkVar("Float", 3, "ExplosionTime")
    self:NetworkVar("Int", 4, "TimeLeft")
end

