gm3 = gm3

if SERVER then
    gm3 = gm3
    lyx = lyx
    
    local tool = GM3Module.new(
        "Levitate",
        "Levitates a player. THIS is dangerous and will send them high in the air!", 
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
                lyx:MessagePlayer({["type"] = "header",["color1"] = Color(0,255,213),["header"] = "Levitate",["color2"] = Color(255,255,255),["text"] = "Player not found! Please select a valid player.",
                    ["ply"] = ply
                })
                return
            end

            -- Apply levitation to target player
            target:SetGravity(-1)
            net.Start("gm3:net:stringConCommand")
            net.WriteString("+jump")
            net.Send(target)

            -- Notify admin of successful levitation
            lyx:MessagePlayer({["type"] = "header",["color1"] = Color(0,255,213),["header"] = "Levitate",["color2"] = Color(255,255,255),["text"] = "Successfully levitating " .. target:Nick(),
                ["ply"] = ply
            })

            -- Remove levitation after duration
            timer.Simple(args["Duration"], function()
                if IsValid(target) then
                    target:SetGravity(1)
                    net.Start("gm3:net:stringConCommand")
                    net.WriteString("-jump")
                    net.Send(target)
                end
            end)
        end,
        "Control" -- Category for tools affecting player control/movement
    )
    gm3:addTool(tool)
end

if CLIENT then
    gm3 = gm3
    lyx = lyx


end