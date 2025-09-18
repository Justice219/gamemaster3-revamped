-- Incoludes
include("shared.lua")
local imgui = include("lyx_core/thirdparty/cl_lyx_imgui.lua")

function ENT:Draw()
    self:DrawModel()
    
    -- distance check
    if LocalPlayer():GetPos():Distance(self:GetPos()) < 200 then
        if imgui.Entity3D2D(self, Vector(-5,-6,12), Angle(0,-90,90), 0.1) then
            -- Main UI
            if !self:GetBeenPlaced() then
                draw.RoundedBox(6, -185,-1, 250, 90, Color(58,58,58, 100))
                draw.SimpleText("Detonator", imgui.xFont("!Roboto@20"),-180, -0, Color(255,255,255)) 
                draw.SimpleText("Press E To Place", imgui.xFont("!Roboto@20"),-180, 20, Color(255,255,255)) 
            elseif !self:GetIsExploding() then
                draw.RoundedBox(6, -185,-1, 250, 90, Color(58,58,58, 100))
                draw.SimpleText("Detonator (Armed)", imgui.xFont("!Roboto@20"),-180, -0, Color(255,136,0)) 
                draw.SimpleText("Press E To Activate", imgui.xFont("!Roboto@20"),-180, 20, Color(255,255,255)) 
            elseif self:GetIsExploding() then
                draw.RoundedBox(6, -185,-1, 250, 90, Color(58,58,58, 100))
                draw.SimpleText("Detonator (Exploding)", imgui.xFont("!Roboto@20"),-180, -0, Color(255,136,0))
                draw.SimpleText("Time Left: " .. self:GetTimeLeft(), imgui.xFont("!Roboto@20"),-180, 20, Color(255,255,255))
            end
    
            imgui.End3D2D()
        end
    end
end