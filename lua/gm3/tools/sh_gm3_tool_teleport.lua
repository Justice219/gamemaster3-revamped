gm3 = gm3
lyx = lyx

if SERVER then
    -- Register network string on server
    lyx:NetAdd("gm3:tools:teleport", {})

    gm3 = gm3
    lyx = lyx

    local tool = GM3Module.new(
        "Teleport",
        "Teleport players to different locations or to each other",
        "GM3 Assistant",
        {
            ["Source Player"] = {
                type = "player",
                def = ""
            },
            ["Destination"] = {
                type = "string",
                def = "crosshair" -- Options: crosshair, spawn, target_player
            },
            ["Target Player"] = {
                type = "player",
                def = "" -- Only used when Destination is "target_player"
            },
            ["Offset Height"] = {
                type = "number",
                def = 10 -- Height offset to prevent getting stuck
            }
        },
        function(ply, args)
            -- Get the source player using gm3 helper function
            local sourcePlayer = gm3:GetPlayerBySteamID(args["Source Player"])
            if not IsValid(sourcePlayer) then
                lyx:MessagePlayer({
                    ["type"] = "header",
                    ["color1"] = Color(0,255,213),
                    ["header"] = "Teleport",
                    ["color2"] = Color(255,255,255),
                    ["text"] = "Source player not found! Please select a valid player.",
                    ["ply"] = ply
                })
                return
            end

            local destination = string.lower(args["Destination"])
            local teleportPos = nil
            local teleportAngles = sourcePlayer:GetAngles()

            if destination == "crosshair" then
                -- Teleport to admin's crosshair
                local trace = ply:GetEyeTrace()
                if trace.Hit then
                    teleportPos = trace.HitPos + Vector(0, 0, args["Offset Height"])
                else
                    lyx:MessagePlayer({
                        ["type"] = "header",
                        ["color1"] = Color(255,100,100),
                        ["header"] = "Teleport",
                        ["color2"] = Color(255,255,255),
                        ["text"] = "No valid position under crosshair!",
                        ["ply"] = ply
                    })
                    return
                end

            elseif destination == "spawn" then
                -- Teleport to spawn points
                local spawns = ents.FindByClass("info_player_start")
                if #spawns == 0 then
                    spawns = ents.FindByClass("info_player_terrorist")
                end
                if #spawns == 0 then
                    spawns = ents.FindByClass("info_player_counterterrorist")
                end

                if #spawns > 0 then
                    local spawn = spawns[math.random(#spawns)]
                    teleportPos = spawn:GetPos() + Vector(0, 0, args["Offset Height"])
                    teleportAngles = spawn:GetAngles()
                else
                    -- Fallback to world spawn
                    teleportPos = Vector(0, 0, 100)
                end

            elseif destination == "target_player" then
                -- Teleport to another player
                local targetPlayer = gm3:GetPlayerBySteamID(args["Target Player"])
                if not IsValid(targetPlayer) then
                    lyx:MessagePlayer({
                        ["type"] = "header",
                        ["color1"] = Color(255,100,100),
                        ["header"] = "Teleport",
                        ["color2"] = Color(255,255,255),
                        ["text"] = "Target player not found! Please select a valid target.",
                        ["ply"] = ply
                    })
                    return
                end

                if targetPlayer == sourcePlayer then
                    lyx:MessagePlayer({
                        ["type"] = "header",
                        ["color1"] = Color(255,100,100),
                        ["header"] = "Teleport",
                        ["color2"] = Color(255,255,255),
                        ["text"] = "Cannot teleport player to themselves!",
                        ["ply"] = ply
                    })
                    return
                end

                -- Teleport behind the target player
                local targetAngles = targetPlayer:GetAngles()
                local offset = targetAngles:Forward() * -64 + Vector(0, 0, args["Offset Height"])
                teleportPos = targetPlayer:GetPos() + offset
                teleportAngles = targetAngles

            else
                lyx:MessagePlayer({
                    ["type"] = "header",
                    ["color1"] = Color(255,100,100),
                    ["header"] = "Teleport",
                    ["color2"] = Color(255,255,255),
                    ["text"] = "Invalid destination! Use: crosshair, spawn, or target_player",
                    ["ply"] = ply
                })
                return
            end

            -- Perform the teleport
            if teleportPos then
                -- Store old position for potential undo
                sourcePlayer.LastTeleportPos = sourcePlayer:GetPos()
                sourcePlayer.LastTeleportAngles = sourcePlayer:GetAngles()

                -- If player is in vehicle, eject them first
                if sourcePlayer:InVehicle() then
                    sourcePlayer:ExitVehicle()
                end

                -- Teleport the player
                sourcePlayer:SetPos(teleportPos)
                sourcePlayer:SetEyeAngles(teleportAngles)
                sourcePlayer:SetVelocity(Vector(0,0,0)) -- Reset velocity to prevent momentum carries

                -- Visual and audio feedback
                net.Start("gm3:tools:teleport")
                    net.WriteEntity(sourcePlayer)
                    net.WriteVector(teleportPos)
                net.Broadcast()

                -- Log the action
                local destName = destination
                if destination == "target_player" then
                    local target = gm3:GetPlayerBySteamID(args["Target Player"])
                    if IsValid(target) then
                        destName = target:Nick()
                    end
                end

                lyx:MessagePlayer({
                    ["type"] = "header",
                    ["color1"] = Color(0,255,213),
                    ["header"] = "Teleport",
                    ["color2"] = Color(255,255,255),
                    ["text"] = string.format("Teleported %s to %s", sourcePlayer:Nick(), destName),
                    ["ply"] = ply
                })

                gm3.Logger:Log(string.format("Admin %s teleported %s to %s",
                    ply:Nick(), sourcePlayer:Nick(), destName))
            end
        end,
        "Control" -- Category for tools affecting player control/movement
    )
    gm3:addTool(tool)
end

if CLIENT then
    gm3 = gm3
    lyx = lyx

    -- Create teleport effect
    lyx:NetAdd("gm3:tools:teleport", {
        func = function()
            local ply = net.ReadEntity()
            local pos = net.ReadVector()

            if not IsValid(ply) then return end

            -- Create teleport effect at both locations
            local effectData = EffectData()

            -- Effect at original position
            effectData:SetOrigin(ply:GetPos())
            effectData:SetNormal(Vector(0, 0, 1))
            effectData:SetMagnitude(2)
            effectData:SetScale(1)
            effectData:SetRadius(100)
            util.Effect("Sparks", effectData)

            -- Effect at new position
            effectData:SetOrigin(pos)
            util.Effect("Sparks", effectData)

            -- Play teleport sound
            ply:EmitSound("ambient/energy/whiteflash.wav", 75, 100, 0.5)

            -- Screen flash for the teleported player
            if ply == LocalPlayer() then
                local flash = vgui.Create("DPanel")
                flash:SetSize(ScrW(), ScrH())
                flash:SetPos(0, 0)
                flash:SetAlpha(255)
                flash.Paint = function(s, w, h)
                    draw.RoundedBox(0, 0, 0, w, h, Color(255, 255, 255))
                end

                -- Fade out effect
                flash:AlphaTo(0, 0.3, 0, function()
                    if IsValid(flash) then
                        flash:Remove()
                    end
                end)
            end
        end
    })
end