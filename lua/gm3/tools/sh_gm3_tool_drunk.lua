gm3 = gm3

if SERVER then
    gm3 = gm3
    lyx = lyx
    
    local tool = GM3Module.new(
        "Drunk",
        "Makes a player experience a drunk sort of effect. NAME OR STEAMID", 
        "Justice#4956",
        {
            ["Name/SteamID"] = {
                type = "string",
                def = "Garry"
            },
            ["Duration"] = {
                type = "number",
                def = 5
            },
        },
        function(ply, args)
            local target = nil 
            for k,v in pairs(player.GetAll()) do
                if v:Nick() == args["Name/SteamID"] or v:SteamID() == args["Name/SteamID"] then
                    target = v
                end
            end
            if not IsValid(target) then
                lyx:MessagePlayer({["type"] = "header",["color1"] = Color(0,255,213),["header"] = "Shrink",["color2"] = Color(255,255,255),["text"] = "Player not found!",
                    ["ply"] = ply
                })
                return
            end

            ply:SendLua([[
                hook.Add("RenderScreenspaceEffects", "DrunkEffect", function()
                    DrawMotionBlur(0.1, 0.8, 0.01)
                end)
            ]])
            ply:SendLua([[
                hook.Add("Move", "DrunkControl", function(ply, mv)
                    mv:SetForwardSpeed(mv:GetForwardSpeed() * 0.8 + math.sin(CurTime() * 2) * 100)
                    mv:SetSideSpeed(mv:GetSideSpeed() * 0.8 + math.cos(CurTime() * 2) * 100)
                end)
            ]])
            timer.Simple(args["Duration"], function()
                if IsValid(target) then
                    ply:SendLua('hook.Remove("RenderScreenspaceEffects", "DrunkEffect")')
                    ply:SendLua('hook.Remove("Move", "DrunkControl")')
                end
            end)
        end)
    gm3:addTool(tool)
end

if CLIENT then
    gm3 = gm3
    lyx = lyx


end