gm3 = gm3

if SERVER then
    gm3 = gm3
    lyx = lyx
    
    local tool = GM3Module.new(
        "Clone",
        "Create a clone of a player that mimics their movements.", 
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
                lyx:MessagePlayer({["type"] = "header",["color1"] = Color(0,255,213),["header"] = "Clone",["color2"] = Color(255,255,255),["text"] = "Player not found! Please select a valid player.",
                    ["ply"] = ply
                })
                return
            end

            local clone =  ents.Create("prop_dynamic")
            clone:SetModel(target:GetModel())
            clone:SetPos(target:GetPos())
            clone:SetAngles(target:GetAngles())
            clone:Spawn()

            timer.Create("Clone_"..target:SteamID(), 0.1, 0, function()
                if not IsValid(target) then
                    timer.Remove("Clone_"..target:SteamID())
                    if IsValid(clone) then
                        clone:Remove()
                    end
                    return
                end
                if not IsValid(clone) then
                    timer.Remove("Clone_"..target:SteamID())
                    return
                end
                clone:SetPos(target:GetPos())
                clone:SetAngles(target:GetAngles())

                // copy current animation
                local seq = target:GetSequence()
                clone:ResetSequence(seq)
                clone:SetCycle(target:GetCycle())
                clone:SetPlaybackRate(target:GetPlaybackRate())
            end)

            timer.Simple(10, function()
                if IsValid(clone) then
                    clone:Remove()
                end
                timer.Remove("CloneMimic_" .. ply:SteamID())
            end)

        end,
        "Control" -- Category for tools affecting player control/movement
    gm3:addTool(tool)
end

if CLIENT then
    gm3 = gm3
    lyx = lyx


end