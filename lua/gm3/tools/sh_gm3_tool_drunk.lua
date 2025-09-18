gm3 = gm3

if SERVER then
    gm3 = gm3
    lyx = lyx
    
    local tool = GM3Module.new(
        "Drunk",
        "Makes a player experience a drunk sort of effect.", 
        "Justice#4956",
        {
            ["Target Player"] = {
                type = "player",
                def = ""
            },
            ["Duration"] = {
                type = "number",
                def = 5
            },
        },
        function(ply, args)
            -- Get the target player using gm3 helper function
            local target = gm3:GetPlayerBySteamID(args["Target Player"])
            if not IsValid(target) then
                lyx:MessagePlayer({["type"] = "header",["color1"] = Color(0,255,213),["header"] = "Drunk",["color2"] = Color(255,255,255),["text"] = "Player not found! Please select a valid player.",
                    ["ply"] = ply
                })
                return
            end

            -- Apply drunk effects to the target player, not the admin
            target:SendLua([[
                hook.Add("RenderScreenspaceEffects", "DrunkEffect", function()
                    DrawMotionBlur(0.1, 0.8, 0.01)
                end)
            ]])
            target:SendLua([[
                hook.Add("Move", "DrunkControl", function(ply, mv)
                    mv:SetForwardSpeed(mv:GetForwardSpeed() * 0.8 + math.sin(CurTime() * 2) * 100)
                    mv:SetSideSpeed(mv:GetSideSpeed() * 0.8 + math.cos(CurTime() * 2) * 100)
                end)
            ]])
            timer.Simple(args["Duration"], function()
                if IsValid(target) then
                    target:SendLua('hook.Remove("RenderScreenspaceEffects", "DrunkEffect")')
                    target:SendLua('hook.Remove("Move", "DrunkControl")')
                end
            end)
        end,
        "Visual" -- Category for tools affecting player vision/display
    gm3:addTool(tool)
end

if CLIENT then
    gm3 = gm3
    lyx = lyx


end