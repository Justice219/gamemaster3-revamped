gm3 = gm3

if SERVER then
    gm3 = gm3
    lyx = lyx
    
    local tool = GM3Module.new(
        "Confetti Pop",
        "Makes a player explode in confetti.", 
        "Justice#4956",
        {
            ["Target Player"] = {
                type = "player",
                def = ""
            },
            ["Delay"] = {
                type = "number",
                def = 5
            },
        },
        function(ply, args)
            -- Get the target player using gm3 helper function
            local target = gm3:GetPlayerBySteamID(args["Target Player"])
            if not IsValid(target) then
                lyx:MessagePlayer({["type"] = "header",["color1"] = Color(0,255,213),["header"] = "Confetti Pop",["color2"] = Color(255,255,255),["text"] = "Player not found! Please select a valid player.",
                    ["ply"] = ply
                })
                return
            end

            // delay the timer
            timer.Simple(args["Delay"], function()
                if IsValid(target) then
                    // create confetti
                    local effectData = EffectData()
                    effectData:SetOrigin(target:GetPos())
                    // make the effect look nice
                    effectData:SetScale(1)
                    // make many confetti
                    effectData:SetMagnitude(100)
                    util.Effect("cball_explode", effectData)
                    ply:EmitSound("garrysmod/balloon_pop_cute.wav")

                    // kill the player
                    target:TakeDamage(1000, ply, ply)
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