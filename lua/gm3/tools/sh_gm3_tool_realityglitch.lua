gm3 = gm3
lyx = lyx

if SERVER then
    -- Register network strings on server (server -> client only)
    lyx:NetAdd("gm3:tools:realityglitch")
    lyx:NetAdd("gm3:tools:realityglitch:update")

    gm3 = gm3
    lyx = lyx

    -- Table to track glitched players
    gm3.glitchedPlayers = gm3.glitchedPlayers or {}

    local tool = GM3Module.new(
        "Reality Glitch",
        "Break a player's perception of reality with surreal visual and audio effects",
        "GM3 Creative",
        {
            ["Target Player"] = {
                type = "player",
                def = ""
            },
            ["Glitch Type"] = {
                type = "string",
                def = "random" -- Options: random, matrix, nightmare, disco, quantum, backwards
            },
            ["Intensity"] = {
                type = "number",
                def = 50 -- 0-100 intensity scale
            },
            ["Audio Distortion"] = {
                type = "boolean",
                def = true -- Distort game audio
            },
            ["Duration (0 = Infinite)"] = {
                type = "number",
                def = 60 -- Default 60 seconds of madness
            }
        },
        function(ply, args)
            -- Get the target player
            local targetPlayer = gm3:GetPlayerBySteamID(args["Target Player"])
            if not IsValid(targetPlayer) then
                lyx:MessagePlayer({
                    ["type"] = "header",
                    ["color1"] = Color(255,100,100),
                    ["header"] = "Reality Glitch",
                    ["color2"] = Color(255,255,255),
                    ["text"] = "Target player not found! Please select a valid player.",
                    ["ply"] = ply
                })
                return
            end

            local glitchType = string.lower(args["Glitch Type"])
            local intensity = math.Clamp(args["Intensity"], 0, 100)
            local audioDistortion = args["Audio Distortion"]
            local duration = math.max(0, args["Duration (0 = Infinite)"])

            -- If already glitched, clear it first
            if gm3.glitchedPlayers[targetPlayer] then
                ClearGlitch(targetPlayer)
            end

            -- Random glitch type
            if glitchType == "random" then
                local types = {"matrix", "nightmare", "disco", "quantum", "backwards"}
                glitchType = types[math.random(#types)]
            end

            -- Apply glitch
            gm3.glitchedPlayers[targetPlayer] = {
                type = glitchType,
                intensity = intensity,
                audio = audioDistortion,
                startTime = CurTime(),
                randomSeed = math.random(1, 10000)
            }

            -- Set network variables
            targetPlayer:SetNWBool("gm3_glitched", true)
            targetPlayer:SetNWString("gm3_glitch_type", glitchType)
            targetPlayer:SetNWInt("gm3_glitch_intensity", intensity)
            targetPlayer:SetNWInt("gm3_glitch_seed", gm3.glitchedPlayers[targetPlayer].randomSeed)

            -- Apply server-side effects based on type
            if glitchType == "matrix" then
                -- Matrix effect - slow motion
                targetPlayer:SetLaggedMovementValue(0.5)
                game.SetTimeScale(0.5)
                timer.Simple(0.1, function() game.SetTimeScale(1) end) -- Reset for others

            elseif glitchType == "backwards" then
                -- Reverse controls
                targetPlayer:SetNWBool("gm3_reverse_controls", true)

            elseif glitchType == "quantum" then
                -- Random teleportation
                timer.Create("gm3_glitch_quantum_" .. targetPlayer:SteamID(), 3, 0, function()
                    if IsValid(targetPlayer) and gm3.glitchedPlayers[targetPlayer] then
                        local randomOffset = VectorRand() * 100
                        randomOffset.z = 0
                        local newPos = targetPlayer:GetPos() + randomOffset
                        targetPlayer:SetPos(newPos)

                        -- Quantum particle effect
                        local effectData = EffectData()
                        effectData:SetOrigin(targetPlayer:GetPos())
                        effectData:SetScale(1)
                        util.Effect("cball_explode", effectData)
                    end
                end)

            elseif glitchType == "nightmare" then
                -- Spawn hallucination NPCs
                timer.Create("gm3_glitch_nightmare_" .. targetPlayer:SteamID(), 5, 0, function()
                    if IsValid(targetPlayer) and gm3.glitchedPlayers[targetPlayer] then
                        net.Start("gm3:tools:realityglitch:update")
                            net.WriteEntity(targetPlayer)
                            net.WriteString("spawn_hallucination")
                        net.Send(targetPlayer)
                    end
                end)
            end

            -- Audio distortion
            if audioDistortion then
                targetPlayer:SetDSP(14 + math.floor(intensity / 20), false) -- Various DSP effects
            end

            -- Duration timer
            if duration > 0 then
                timer.Create("gm3_glitch_" .. targetPlayer:SteamID(), duration, 1, function()
                    if IsValid(targetPlayer) then
                        ClearGlitch(targetPlayer)

                        lyx:MessagePlayer({
                            ["type"] = "header",
                            ["color1"] = Color(0,255,0),
                            ["header"] = "Reality Glitch",
                            ["color2"] = Color(255,255,255),
                            ["text"] = "Reality has stabilized.",
                            ["ply"] = targetPlayer
                        })
                    end
                end)
            end

            -- Network message for effects
            net.Start("gm3:tools:realityglitch")
                net.WriteEntity(targetPlayer)
                net.WriteBool(true)
                net.WriteString(glitchType)
                net.WriteInt(intensity, 7)
                net.WriteBool(audioDistortion)
            net.Broadcast()

            -- Notifications
            lyx:MessagePlayer({
                ["type"] = "header",
                ["color1"] = Color(255,0,255),
                ["header"] = "Reality Glitch",
                ["color2"] = Color(255,255,255),
                ["text"] = string.format("Applied %s glitch to %s (Intensity: %d%%)",
                    glitchType, targetPlayer:Nick(), intensity),
                ["ply"] = ply
            })

            lyx:MessagePlayer({
                ["type"] = "header",
                ["color1"] = Color(math.random(0,255), math.random(0,255), math.random(0,255)),
                ["header"] = "REALITY ERROR",
                ["color2"] = Color(255,255,255),
                ["text"] = "Something is wrong with reality...",
                ["ply"] = targetPlayer
            })

            gm3.Logger:Log(string.format("%s glitched %s's reality (%s, %d%%)",
                ply:Nick(), targetPlayer:Nick(), glitchType, intensity))
        end,
        "Visual" -- Category
    )
    gm3:addTool(tool)

    -- Clear glitch helper
    function ClearGlitch(targetPlayer)
        if not IsValid(targetPlayer) or not gm3.glitchedPlayers[targetPlayer] then return end

        -- Reset everything
        targetPlayer:SetLaggedMovementValue(1)
        targetPlayer:SetDSP(0, false)
        targetPlayer:SetNWBool("gm3_glitched", false)
        targetPlayer:SetNWBool("gm3_reverse_controls", false)

        -- Remove timers
        timer.Remove("gm3_glitch_" .. targetPlayer:SteamID())
        timer.Remove("gm3_glitch_quantum_" .. targetPlayer:SteamID())
        timer.Remove("gm3_glitch_nightmare_" .. targetPlayer:SteamID())

        -- Network message
        net.Start("gm3:tools:realityglitch")
            net.WriteEntity(targetPlayer)
            net.WriteBool(false)
            net.WriteString("")
            net.WriteInt(0, 7)
            net.WriteBool(false)
        net.Broadcast()

        gm3.glitchedPlayers[targetPlayer] = nil
    end

    -- Reverse controls hook
    hook.Add("SetupMove", "GM3_RealityGlitch_Reverse", function(ply, mv, cmd)
        if ply:GetNWBool("gm3_reverse_controls", false) then
            mv:SetForwardSpeed(-mv:GetForwardSpeed())
            mv:SetSideSpeed(-mv:GetSideSpeed())

            -- Randomly invert mouse
            if math.random() < 0.3 then
                local ang = cmd:GetViewAngles()
                ang.pitch = -ang.pitch
                cmd:SetViewAngles(ang)
            end
        end
    end)

    -- Cleanup on disconnect
    hook.Add("PlayerDisconnected", "GM3_RealityGlitch_Cleanup", function(ply)
        ClearGlitch(ply)
    end)
end

if CLIENT then
    gm3 = gm3
    lyx = lyx

    local glitchedPlayers = {}
    local hallucinations = {}

    -- Handle glitch effects
    lyx:NetAdd("gm3:tools:realityglitch", {
        func = function()
            local ply = net.ReadEntity()
            local active = net.ReadBool()
            local glitchType = net.ReadString()
            local intensity = net.ReadInt(7)
            local audio = net.ReadBool()

            if not IsValid(ply) then return end

            if active then
                glitchedPlayers[ply] = {
                    type = glitchType,
                    intensity = intensity,
                    audio = audio,
                    startTime = CurTime()
                }

                -- Play glitch sound
                ply:EmitSound("npc/scanner/combat_scan" .. math.random(1,5) .. ".wav", 75, math.random(50, 150))

                if ply == LocalPlayer() then
                    -- Start the madness
                    surface.PlaySound("ambient/creatures/town_child_scream1.wav")
                end
            else
                glitchedPlayers[ply] = nil

                -- Clear hallucinations
                for _, ent in pairs(hallucinations) do
                    if IsValid(ent) then
                        ent:Remove()
                    end
                end
                hallucinations = {}
            end
        end
    })

    -- Handle special updates
    lyx:NetAdd("gm3:tools:realityglitch:update", {
        func = function()
            local ply = net.ReadEntity()
            local updateType = net.ReadString()

            if updateType == "spawn_hallucination" and ply == LocalPlayer() then
                -- Create client-side hallucination
                local mdl = ClientsideModel("models/player/zombie_fast.mdl")
                mdl:SetPos(LocalPlayer():GetPos() + VectorRand() * 500)
                mdl:SetAngles(AngleRand())
                mdl:SetColor(Color(255, 0, 0, 100))
                mdl:SetRenderMode(RENDERMODE_TRANSCOLOR)

                -- Make it disappear after a bit
                timer.Simple(math.random(2, 5), function()
                    if IsValid(mdl) then
                        mdl:Remove()
                    end
                end)

                table.insert(hallucinations, mdl)
            end
        end
    })

    -- Main rendering hook for glitch effects
    hook.Add("RenderScreenspaceEffects", "GM3_RealityGlitch_Effects", function()
        if not LocalPlayer():GetNWBool("gm3_glitched", false) then return end

        local glitchType = LocalPlayer():GetNWString("gm3_glitch_type", "")
        local intensity = LocalPlayer():GetNWInt("gm3_glitch_intensity", 50) / 100
        local seed = LocalPlayer():GetNWInt("gm3_glitch_seed", 0)

        if glitchType == "matrix" then
            -- Matrix green tint with digital rain
            local tab = {
                ["$pp_colour_addr"] = 0,
                ["$pp_colour_addg"] = 0.1 * intensity,
                ["$pp_colour_addb"] = 0,
                ["$pp_colour_brightness"] = -0.1 * intensity,
                ["$pp_colour_contrast"] = 1 + 0.5 * intensity,
                ["$pp_colour_colour"] = 1 - 0.5 * intensity,
                ["$pp_colour_mulr"] = 0,
                ["$pp_colour_mulg"] = 1,
                ["$pp_colour_mulb"] = 0
            }
            DrawColorModify(tab)

            -- Digital distortion
            DrawMotionBlur(0.4 * intensity, 0.8, 0.01)

            -- Scan lines
            if math.sin(CurTime() * 10) > 0 then
                DrawMaterialOverlay("effects/combine_binocoverlay", 0.1 * intensity)
            end

        elseif glitchType == "nightmare" then
            -- Horror vision
            local tab = {
                ["$pp_colour_addr"] = 0.1 * intensity,
                ["$pp_colour_addg"] = 0,
                ["$pp_colour_addb"] = 0,
                ["$pp_colour_brightness"] = -0.3 * intensity,
                ["$pp_colour_contrast"] = 1 + intensity,
                ["$pp_colour_colour"] = 1 - 0.8 * intensity,
                ["$pp_colour_mulr"] = 2,
                ["$pp_colour_mulg"] = 0,
                ["$pp_colour_mulb"] = 0
            }
            DrawColorModify(tab)

            -- Creepy blur
            DrawMotionBlur(0.2 * intensity, 0.5, 0.05)

            -- Random screen shake
            if math.random() < 0.05 * intensity then
                util.ScreenShake(LocalPlayer():GetPos(), 5 * intensity, 5, 0.5, 100)
            end

        elseif glitchType == "disco" then
            -- Psychedelic colors
            local time = CurTime() * 5
            local tab = {
                ["$pp_colour_addr"] = math.sin(time) * 0.5 * intensity,
                ["$pp_colour_addg"] = math.sin(time + 2) * 0.5 * intensity,
                ["$pp_colour_addb"] = math.sin(time + 4) * 0.5 * intensity,
                ["$pp_colour_brightness"] = math.sin(time * 2) * 0.2 * intensity,
                ["$pp_colour_contrast"] = 1 + math.sin(time * 3) * 0.5 * intensity,
                ["$pp_colour_colour"] = 1 + math.sin(time * 4) * 2 * intensity,
                ["$pp_colour_mulr"] = 1,
                ["$pp_colour_mulg"] = 1,
                ["$pp_colour_mulb"] = 1
            }
            DrawColorModify(tab)

            -- Rainbow bloom
            DrawBloom(0.65, 2 * intensity, 9, 9, 1, 1, 1, 1, 1)

            -- Spin effect
            DrawSharpen(math.sin(time) * 5 * intensity, 1.2)

        elseif glitchType == "quantum" then
            -- Reality breaking apart
            local glitchAmount = math.sin(CurTime() * 10 + seed) * intensity

            -- Chromatic aberration
            DrawMaterialOverlay("effects/strider_pinch_dudv", glitchAmount * 0.1)

            -- Time distortion
            DrawMotionBlur(0.1 + glitchAmount * 0.4, 0.9, 0.01)

            -- Color shifting
            local tab = {
                ["$pp_colour_addr"] = math.random() * 0.1 * intensity,
                ["$pp_colour_addg"] = math.random() * 0.1 * intensity,
                ["$pp_colour_addb"] = math.random() * 0.1 * intensity,
                ["$pp_colour_brightness"] = (math.random() - 0.5) * 0.5 * intensity,
                ["$pp_colour_contrast"] = 1 + (math.random() - 0.5) * intensity,
                ["$pp_colour_colour"] = 1,
                ["$pp_colour_mulr"] = 1,
                ["$pp_colour_mulg"] = 1,
                ["$pp_colour_mulb"] = 1
            }
            DrawColorModify(tab)

        elseif glitchType == "backwards" then
            -- Inverted vision
            local tab = {
                ["$pp_colour_addr"] = 0,
                ["$pp_colour_addg"] = 0,
                ["$pp_colour_addb"] = 0,
                ["$pp_colour_brightness"] = 0,
                ["$pp_colour_contrast"] = 1,
                ["$pp_colour_colour"] = 1,
                ["$pp_colour_mulr"] = -1,
                ["$pp_colour_mulg"] = -1,
                ["$pp_colour_mulb"] = -1
            }
            DrawColorModify(tab)

            -- Upside down effect simulation with blur
            DrawMotionBlur(0.8 * intensity, 0.8, 0.01)
        end

        -- Common glitch effects
        if math.random() < 0.02 * intensity then
            -- Random static
            DrawMaterialOverlay("effects/tvscreen_noise002a", math.random() * 0.5)
        end
    end)

    -- HUD glitches
    hook.Add("HUDPaint", "GM3_RealityGlitch_HUD", function()
        if not LocalPlayer():GetNWBool("gm3_glitched", false) then return end

        local glitchType = LocalPlayer():GetNWString("gm3_glitch_type", "")
        local intensity = LocalPlayer():GetNWInt("gm3_glitch_intensity", 50)

        -- Glitched text
        local texts = {
            "ERROR", "REALITY FAULT", "SYSTEM FAILURE", "HELP ME",
            "IT'S NOT REAL", "WAKE UP", "ERROR 404", "SEGMENTATION FAULT"
        }

        if math.random() < 0.01 * intensity then
            local text = texts[math.random(#texts)]
            local x = math.random(0, ScrW())
            local y = math.random(0, ScrH())
            local color = Color(math.random(0,255), math.random(0,255), math.random(0,255), math.random(100,255))

            draw.SimpleText(text, "DermaLarge", x, y, color,
                TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end

        -- Type-specific HUD elements
        if glitchType == "matrix" then
            -- Digital rain effect
            for i = 1, intensity do
                if math.random() < 0.1 then
                    local x = math.random(0, ScrW())
                    local char = string.char(math.random(33, 126))
                    draw.SimpleText(char, "DermaDefault", x, 0,
                        Color(0, 255, 0, math.random(50, 200)),
                        TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
                end
            end
        end
    end)
end