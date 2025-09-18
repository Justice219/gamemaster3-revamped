gm3 = gm3

if SERVER then
    gm3 = gm3
    lyx = lyx

    local tool = GM3Module.new(
        "Kill Player",
        "Kills a given player", 
        "Justice#4956",
        {
            ["Target Player"] = {
                type = "player",
                def = ""
            }
        },
        function(ply, args)
            -- Get the target player using gm3 helper function
            local target = gm3:GetPlayerBySteamID(args["Target Player"])
            if not IsValid(target) then
                lyx:MessagePlayer({["type"] = "header",["color1"] = Color(0,255,213),["header"] = "Player Kill",["color2"] = Color(255,255,255),["text"] = "Player not found! Please select a valid player.",
                    ["ply"] = ply
                })
                return
            end

            -- Kill the target player
            target:Kill()

            -- Notify admin of successful kill
            lyx:MessagePlayer({["type"] = "header",["color1"] = Color(0,255,213),["header"] = "Player Kill",["color2"] = Color(255,255,255),["text"] = "Successfully killed " .. target:Nick(),
                ["ply"] = ply
            })
        end,
        "Utility" -- Category for general utility tools
    )
    gm3:addTool(tool)
end

if CLIENT then
    gm3 = gm3
    lyx = lyx


end