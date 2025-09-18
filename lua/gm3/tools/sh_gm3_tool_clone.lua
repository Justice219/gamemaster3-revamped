gm3 = gm3

if SERVER then
    gm3 = gm3
    lyx = lyx
    
    local tool = GM3Module.new(
        "Clone",
        "Create a clone of a player that mimics their movements.. NAME OR STEAMID", 
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
        
        end)
    gm3:addTool(tool)
end

if CLIENT then
    gm3 = gm3
    lyx = lyx


end