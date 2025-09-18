gm3 = gm3
lyx = lyx

if SERVER then
    -- Register network strings on server (server -> client only)
    lyx:NetAdd("gm3:tools:godmode")
    lyx:NetAdd("gm3:tools:godmode:status")

    gm3 = gm3
    lyx = lyx

    -- Table to track god mode states
    gm3.godModePlayers = gm3.godModePlayers or {}

    local tool = GM3Module.new(
        "God Mode",
        "Toggle invincibility for players - they cannot take damage or die",
        "GM3 Assistant",
        {
            ["Target Player"] = {
                type = "player",
                def = ""
            },
            ["Action"] = {
                type = "string",
                def = "toggle" -- Options: toggle, enable, disable
            },
            ["Show Effects"] = {
                type = "boolean",
                def = true -- Visual indicator for god mode
            },
            ["Duration (0 = Infinite)"] = {
                type = "number",
                def = 0 -- Duration in seconds, 0 for permanent
            }
        },
        function(ply, args)
            -- Get the target player using gm3 helper function
            local targetPlayer = gm3:GetPlayerBySteamID(args["Target Player"])
            if not IsValid(targetPlayer) then
                lyx:MessagePlayer({
                    ["type"] = "header",
                    ["color1"] = Color(255,100,100),
                    ["header"] = "God Mode",
                    ["color2"] = Color(255,255,255),
                    ["text"] = "Target player not found! Please select a valid player.",
                    ["ply"] = ply
                })
                return
            end

            local action = string.lower(args["Action"])
            local showEffects = args["Show Effects"]
            local duration = math.max(0, args["Duration (0 = Infinite)"])

            -- Determine the new god mode state
            local enableGodMode = false
            if action == "toggle" then
                enableGodMode = not gm3.godModePlayers[targetPlayer]
            elseif action == "enable" then
                enableGodMode = true
            elseif action == "disable" then
                enableGodMode = false
            else
                lyx:MessagePlayer({
                    ["type"] = "header",
                    ["color1"] = Color(255,100,100),
                    ["header"] = "God Mode",
                    ["color2"] = Color(255,255,255),
                    ["text"] = "Invalid action! Use: toggle, enable, or disable",
                    ["ply"] = ply
                })
                return
            end

            -- Apply god mode
            if enableGodMode then
                -- Enable god mode
                gm3.godModePlayers[targetPlayer] = true
                targetPlayer:GodEnable()
                targetPlayer:SetNWBool("gm3_godmode", true)
                targetPlayer:SetNWBool("gm3_godmode_effects", showEffects)

                -- Heal player to full
                targetPlayer:SetHealth(targetPlayer:GetMaxHealth())
                targetPlayer:SetArmor(100)

                -- Remove fire if burning
                if targetPlayer:IsOnFire() then
                    targetPlayer:Extinguish()
                end

                -- Set up duration timer if specified
                if duration > 0 then
                    timer.Create("gm3_godmode_" .. targetPlayer:SteamID(), duration, 1, function()
                        if IsValid(targetPlayer) then
                            gm3.godModePlayers[targetPlayer] = false
                            targetPlayer:GodDisable()
                            targetPlayer:SetNWBool("gm3_godmode", false)
                            targetPlayer:SetNWBool("gm3_godmode_effects", false)

                            lyx:MessagePlayer({
                                ["type"] = "header",
                                ["color1"] = Color(255,200,0),
                                ["header"] = "God Mode",
                                ["color2"] = Color(255,255,255),
                                ["text"] = "Your god mode has expired!",
                                ["ply"] = targetPlayer
                            })
                        end
                    end)
                else
                    -- Remove any existing timer
                    timer.Remove("gm3_godmode_" .. targetPlayer:SteamID())
                end

                -- Send network message for effects
                net.Start("gm3:tools:godmode")
                    net.WriteEntity(targetPlayer)
                    net.WriteBool(true)
                    net.WriteBool(showEffects)
                net.Broadcast()

                -- Notification messages
                local durationText = duration > 0 and string.format(" for %d seconds", duration) or " (permanent)"

                lyx:MessagePlayer({
                    ["type"] = "header",
                    ["color1"] = Color(0,255,213),
                    ["header"] = "God Mode",
                    ["color2"] = Color(255,255,255),
                    ["text"] = string.format("God mode enabled for %s%s", targetPlayer:Nick(), durationText),
                    ["ply"] = ply
                })

                if targetPlayer ~= ply then
                    lyx:MessagePlayer({
                        ["type"] = "header",
                        ["color1"] = Color(255,215,0),
                        ["header"] = "God Mode",
                        ["color2"] = Color(255,255,255),
                        ["text"] = string.format("You have been granted god mode%s!", durationText),
                        ["ply"] = targetPlayer
                    })
                end

                gm3.Logger:Log(string.format("Admin %s enabled god mode for %s%s",
                    ply:Nick(), targetPlayer:Nick(), durationText))

            else
                -- Disable god mode
                gm3.godModePlayers[targetPlayer] = false
                targetPlayer:GodDisable()
                targetPlayer:SetNWBool("gm3_godmode", false)
                targetPlayer:SetNWBool("gm3_godmode_effects", false)

                -- Remove timer if exists
                timer.Remove("gm3_godmode_" .. targetPlayer:SteamID())

                -- Send network message for effects
                net.Start("gm3:tools:godmode")
                    net.WriteEntity(targetPlayer)
                    net.WriteBool(false)
                    net.WriteBool(false)
                net.Broadcast()

                -- Notification messages
                lyx:MessagePlayer({
                    ["type"] = "header",
                    ["color1"] = Color(0,255,213),
                    ["header"] = "God Mode",
                    ["color2"] = Color(255,255,255),
                    ["text"] = string.format("God mode disabled for %s", targetPlayer:Nick()),
                    ["ply"] = ply
                })

                if targetPlayer ~= ply then
                    lyx:MessagePlayer({
                        ["type"] = "header",
                        ["color1"] = Color(255,100,100),
                        ["header"] = "God Mode",
                        ["color2"] = Color(255,255,255),
                        ["text"] = "Your god mode has been disabled!",
                        ["ply"] = targetPlayer
                    })
                end

                gm3.Logger:Log(string.format("Admin %s disabled god mode for %s",
                    ply:Nick(), targetPlayer:Nick()))
            end
        end,
        "Control" -- Category for tools affecting player control/movement
    )
    gm3:addTool(tool)

    -- Hook to maintain god mode on spawn
    hook.Add("PlayerSpawn", "GM3_GodMode_Maintain", function(ply)
        timer.Simple(0.1, function()
            if IsValid(ply) and gm3.godModePlayers[ply] then
                ply:GodEnable()
            end
        end)
    end)

    -- Clean up on disconnect
    hook.Add("PlayerDisconnected", "GM3_GodMode_Cleanup", function(ply)
        gm3.godModePlayers[ply] = nil
        timer.Remove("gm3_godmode_" .. ply:SteamID())
    end)

    -- Send status to newly connected players
    hook.Add("PlayerInitialSpawn", "GM3_GodMode_Sync", function(ply)
        timer.Simple(2, function()
            if not IsValid(ply) then return end

            for player, enabled in pairs(gm3.godModePlayers) do
                if IsValid(player) and enabled then
                    net.Start("gm3:tools:godmode:status")
                        net.WriteEntity(player)
                        net.WriteBool(true)
                        net.WriteBool(player:GetNWBool("gm3_godmode_effects", false))
                    net.Send(ply)
                end
            end
        end)
    end)
end

if CLIENT then
    gm3 = gm3
    lyx = lyx

    local godModePlayers = {}

    -- Create god mode visual effects
    lyx:NetAdd("gm3:tools:godmode", {
        func = function()
            local ply = net.ReadEntity()
            local enabled = net.ReadBool()
            local showEffects = net.ReadBool()

            if not IsValid(ply) then return end

            godModePlayers[ply] = enabled and showEffects

            if enabled then
                -- Play activation sound
                ply:EmitSound("npc/scanner/scanner_electric1.wav", 75, 120, 0.5)

                -- Create activation particle effect
                local effectData = EffectData()
                effectData:SetOrigin(ply:GetPos())
                effectData:SetEntity(ply)
                effectData:SetScale(1)
                util.Effect("TeslaHitBoxes", effectData)
            else
                -- Play deactivation sound
                ply:EmitSound("npc/scanner/scanner_electric2.wav", 75, 80, 0.5)
            end
        end
    })

    -- Sync status for new players
    lyx:NetAdd("gm3:tools:godmode:status", {
        func = function()
            local ply = net.ReadEntity()
            local enabled = net.ReadBool()
            local showEffects = net.ReadBool()

            if IsValid(ply) then
                godModePlayers[ply] = enabled and showEffects
            end
        end
    })

    -- Visual indicator rendering
    hook.Add("PrePlayerDraw", "GM3_GodMode_Effects", function(ply)
        if godModePlayers[ply] then
            -- Create golden glow effect
            local glow = DynamicLight(ply:EntIndex())
            if glow then
                glow.pos = ply:GetPos() + Vector(0, 0, 40)
                glow.r = 255
                glow.g = 215
                glow.b = 0
                glow.brightness = 2
                glow.size = 128
                glow.decay = 1000
                glow.style = 0
                glow.dietime = CurTime() + 0.1
            end
        end
    end)

    -- HUD indicator for local player
    hook.Add("HUDPaint", "GM3_GodMode_HUD", function()
        if LocalPlayer():GetNWBool("gm3_godmode", false) then
            -- Draw god mode indicator
            surface.SetFont("DermaLarge")
            local text = "GOD MODE ACTIVE"
            local tw, th = surface.GetTextSize(text)

            local x = ScrW() / 2
            local y = ScrH() - 100

            -- Pulsing effect
            local pulse = math.sin(CurTime() * 3) * 0.3 + 0.7
            local alpha = 255 * pulse

            -- Background
            draw.RoundedBox(8, x - tw/2 - 10, y - th/2 - 5, tw + 20, th + 10,
                Color(0, 0, 0, alpha * 0.7))

            -- Text with golden color
            draw.SimpleText(text, "DermaLarge", x, y,
                Color(255, 215, 0, alpha), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

            -- Border
            surface.SetDrawColor(255, 215, 0, alpha * 0.5)
            surface.DrawOutlinedRect(x - tw/2 - 10, y - th/2 - 5, tw + 20, th + 10, 2)
        end
    end)

    -- Particle effect for god mode players
    hook.Add("Think", "GM3_GodMode_Particles", function()
        for ply, showEffects in pairs(godModePlayers) do
            if IsValid(ply) and showEffects then
                if math.random() < 0.05 then -- 5% chance per frame
                    local pos = ply:GetPos() + Vector(
                        math.random(-20, 20),
                        math.random(-20, 20),
                        math.random(0, 70)
                    )

                    local emitter = ParticleEmitter(pos)
                    if emitter then
                        local particle = emitter:Add("sprites/light_glow02_add", pos)
                        if particle then
                            particle:SetDieTime(1)
                            particle:SetStartAlpha(100)
                            particle:SetEndAlpha(0)
                            particle:SetStartSize(math.random(2, 5))
                            particle:SetEndSize(0)
                            particle:SetColor(255, 215, 0)
                            particle:SetVelocity(Vector(0, 0, 20))
                            particle:SetGravity(Vector(0, 0, -10))
                        end
                        emitter:Finish()
                    end
                end
            elseif not IsValid(ply) then
                godModePlayers[ply] = nil
            end
        end
    end)
end