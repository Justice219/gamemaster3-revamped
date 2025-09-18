gm3 = gm3
lyx = lyx

if SERVER then
    -- Register network strings on server
    lyx:NetAdd("gm3:tools:puppetmaster", {})
    lyx:NetAdd("gm3:tools:puppetmaster:control", {})
    lyx:NetAdd("gm3:tools:puppetmaster:status", {})

    gm3 = gm3
    lyx = lyx

    -- Table to track puppet connections
    gm3.puppetConnections = gm3.puppetConnections or {}

    local tool = GM3Module.new(
        "Puppet Master",
        "Take direct control of another player's movements and actions - become them!",
        "GM3 Creative",
        {
            ["Target Player"] = {
                type = "player",
                def = ""
            },
            ["Control Mode"] = {
                type = "string",
                def = "full" -- Options: full, mirror, reverse
            },
            ["Show Strings"] = {
                type = "boolean",
                def = true -- Visual puppet strings effect
            },
            ["Voice Swap"] = {
                type = "boolean",
                def = false -- Swap voice chat between puppeteer and puppet
            },
            ["Duration (0 = Infinite)"] = {
                type = "number",
                def = 30 -- Default 30 seconds for safety
            }
        },
        function(ply, args)
            -- Get the target player
            local targetPlayer = gm3:GetPlayerBySteamID(args["Target Player"])
            if not IsValid(targetPlayer) then
                lyx:MessagePlayer({
                    ["type"] = "header",
                    ["color1"] = Color(255,100,100),
                    ["header"] = "Puppet Master",
                    ["color2"] = Color(255,255,255),
                    ["text"] = "Target player not found! Please select a valid player.",
                    ["ply"] = ply
                })
                return
            end

            if targetPlayer == ply then
                lyx:MessagePlayer({
                    ["type"] = "header",
                    ["color1"] = Color(255,100,100),
                    ["header"] = "Puppet Master",
                    ["color2"] = Color(255,255,255),
                    ["text"] = "You cannot puppet yourself!",
                    ["ply"] = ply
                })
                return
            end

            -- Check if already controlling someone
            if gm3.puppetConnections[ply] then
                -- Release current puppet
                ReleasePuppet(ply)
            end

            local controlMode = string.lower(args["Control Mode"])
            local showStrings = args["Show Strings"]
            local voiceSwap = args["Voice Swap"]
            local duration = math.max(0, args["Duration (0 = Infinite)"])

            -- Establish puppet connection
            gm3.puppetConnections[ply] = {
                puppet = targetPlayer,
                mode = controlMode,
                strings = showStrings,
                voice = voiceSwap,
                originalView = targetPlayer:GetViewEntity(),
                puppetOriginalPos = targetPlayer:GetPos(),
                masterOriginalPos = ply:GetPos()
            }

            -- Mark puppet as controlled
            targetPlayer.PuppetMaster = ply
            targetPlayer:SetNWEntity("gm3_puppet_master", ply)
            targetPlayer:SetNWBool("gm3_is_puppet", true)

            -- Mark master as controlling
            ply:SetNWEntity("gm3_puppet_target", targetPlayer)
            ply:SetNWBool("gm3_is_puppeteer", true)

            -- Set up control mode
            if controlMode == "full" then
                -- Puppeteer takes full control, puppet watches
                ply:SetViewEntity(targetPlayer)
                targetPlayer:SetViewEntity(ply)

                -- Swap movement control
                ply:SetMoveType(MOVETYPE_NONE)
                ply:SetNoDraw(true)

                -- Give puppet's weapons to master temporarily
                local puppetWeapons = {}
                for _, wep in pairs(targetPlayer:GetWeapons()) do
                    table.insert(puppetWeapons, wep:GetClass())
                end
                gm3.puppetConnections[ply].puppetWeapons = puppetWeapons

            elseif controlMode == "mirror" then
                -- Puppet mirrors all movements
                gm3.puppetConnections[ply].mirrorOffset = targetPlayer:GetPos() - ply:GetPos()

            elseif controlMode == "reverse" then
                -- Puppet does opposite movements (comedy mode)
                gm3.puppetConnections[ply].reverseMode = true
            end

            -- Voice swap setup
            if voiceSwap then
                -- This would require voice chat hooks - placeholder for concept
                targetPlayer:SetNWBool("gm3_voice_swapped", true)
                ply:SetNWBool("gm3_voice_swapped", true)
            end

            -- Duration timer
            if duration > 0 then
                timer.Create("gm3_puppet_" .. ply:SteamID(), duration, 1, function()
                    if IsValid(ply) then
                        ReleasePuppet(ply)

                        lyx:MessagePlayer({
                            ["type"] = "header",
                            ["color1"] = Color(255,200,0),
                            ["header"] = "Puppet Master",
                            ["color2"] = Color(255,255,255),
                            ["text"] = "Puppet control has expired!",
                            ["ply"] = ply
                        })
                    end
                end)
            end

            -- Network message for effects
            net.Start("gm3:tools:puppetmaster")
                net.WriteEntity(ply)
                net.WriteEntity(targetPlayer)
                net.WriteBool(true)
                net.WriteBool(showStrings)
                net.WriteString(controlMode)
            net.Broadcast()

            -- Notifications
            lyx:MessagePlayer({
                ["type"] = "header",
                ["color1"] = Color(200,0,200),
                ["header"] = "Puppet Master",
                ["color2"] = Color(255,255,255),
                ["text"] = string.format("You are now controlling %s (%s mode)", targetPlayer:Nick(), controlMode),
                ["ply"] = ply
            })

            lyx:MessagePlayer({
                ["type"] = "header",
                ["color1"] = Color(200,100,200),
                ["header"] = "Puppet Master",
                ["color2"] = Color(255,255,255),
                ["text"] = string.format("You are being controlled by %s!", ply:Nick()),
                ["ply"] = targetPlayer
            })

            gm3.Logger:Log(string.format("%s is puppet mastering %s (%s mode)",
                ply:Nick(), targetPlayer:Nick(), controlMode))
        end,
        "Control" -- Category
    )
    gm3:addTool(tool)

    -- Release puppet helper
    function ReleasePuppet(master)
        if not gm3.puppetConnections[master] then return end

        local connection = gm3.puppetConnections[master]
        local puppet = connection.puppet

        if IsValid(puppet) then
            -- Restore view entities
            master:SetViewEntity(master)
            if IsValid(puppet) then
                puppet:SetViewEntity(puppet)
            end

            -- Restore movement
            master:SetMoveType(MOVETYPE_WALK)
            master:SetNoDraw(false)

            -- Clear puppet status
            puppet.PuppetMaster = nil
            puppet:SetNWEntity("gm3_puppet_master", NULL)
            puppet:SetNWBool("gm3_is_puppet", false)
            puppet:SetNWBool("gm3_voice_swapped", false)

            -- Network cleanup
            net.Start("gm3:tools:puppetmaster")
                net.WriteEntity(master)
                net.WriteEntity(puppet)
                net.WriteBool(false)
                net.WriteBool(false)
                net.WriteString("")
            net.Broadcast()
        end

        -- Clear master status
        master:SetNWEntity("gm3_puppet_target", NULL)
        master:SetNWBool("gm3_is_puppeteer", false)
        master:SetNWBool("gm3_voice_swapped", false)

        -- Remove timer
        timer.Remove("gm3_puppet_" .. master:SteamID())

        -- Clear connection
        gm3.puppetConnections[master] = nil
    end

    -- Movement control hook
    hook.Add("SetupMove", "GM3_PuppetMaster_Control", function(ply, mv, cmd)
        -- Check if player is a puppet
        if ply.PuppetMaster and IsValid(ply.PuppetMaster) then
            local connection = gm3.puppetConnections[ply.PuppetMaster]
            if not connection then return end

            if connection.mode == "full" then
                -- Copy master's commands to puppet
                local masterCmd = ply.PuppetMaster:GetCurrentCommand()
                if masterCmd then
                    mv:SetForwardSpeed(masterCmd:GetForwardMove())
                    mv:SetSideSpeed(masterCmd:GetSideMove())
                    mv:SetUpSpeed(masterCmd:GetUpMove())
                    cmd:SetViewAngles(masterCmd:GetViewAngles())
                    cmd:SetButtons(masterCmd:GetButtons())
                    cmd:SetImpulse(masterCmd:GetImpulse())
                end

            elseif connection.mode == "reverse" then
                -- Reverse all inputs
                mv:SetForwardSpeed(-mv:GetForwardSpeed())
                mv:SetSideSpeed(-mv:GetSideSpeed())
                local ang = cmd:GetViewAngles()
                ang.yaw = ang.yaw + 180
                cmd:SetViewAngles(ang)

            elseif connection.mode == "mirror" then
                -- Mirror master's position relative to starting point
                if IsValid(ply.PuppetMaster) then
                    local masterPos = ply.PuppetMaster:GetPos()
                    local offset = masterPos - connection.masterOriginalPos
                    local targetPos = connection.puppetOriginalPos + offset

                    -- Smoothly move puppet to mirrored position
                    local currentPos = ply:GetPos()
                    local moveDir = (targetPos - currentPos):GetNormalized()
                    mv:SetVelocity(moveDir * 300)
                end
            end
        end

        -- Check if player is a puppeteer in full control
        if gm3.puppetConnections[ply] and gm3.puppetConnections[ply].mode == "full" then
            -- Prevent puppeteer from moving their own body
            mv:SetForwardSpeed(0)
            mv:SetSideSpeed(0)
            mv:SetUpSpeed(0)
        end
    end)

    -- Cleanup on disconnect
    hook.Add("PlayerDisconnected", "GM3_PuppetMaster_Cleanup", function(ply)
        -- If they were a puppeteer
        if gm3.puppetConnections[ply] then
            ReleasePuppet(ply)
        end

        -- If they were a puppet
        for master, connection in pairs(gm3.puppetConnections) do
            if connection.puppet == ply then
                ReleasePuppet(master)
            end
        end
    end)
end

if CLIENT then
    gm3 = gm3
    lyx = lyx

    local puppetConnections = {}

    -- Handle puppet effects
    lyx:NetAdd("gm3:tools:puppetmaster", {
        func = function()
            local master = net.ReadEntity()
            local puppet = net.ReadEntity()
            local active = net.ReadBool()
            local showStrings = net.ReadBool()
            local mode = net.ReadString()

            if not IsValid(master) or not IsValid(puppet) then return end

            if active then
                puppetConnections[master] = {
                    puppet = puppet,
                    strings = showStrings,
                    mode = mode
                }

                -- Play sound effects
                master:EmitSound("ambient/creatures/teddy.wav", 75, 80, 0.5)
                puppet:EmitSound("npc/stalker/go_alert2.wav", 75, 120, 0.5)

                -- Screen effect for puppet
                if puppet == LocalPlayer() then
                    local warning = vgui.Create("DPanel")
                    warning:SetSize(ScrW(), lyx.Scale(60))
                    warning:SetPos(0, 0)
                    warning.Paint = function(s, w, h)
                        draw.RoundedBox(0, 0, 0, w, h, Color(150, 0, 150, 100))
                        draw.SimpleText("PUPPET MODE - " .. mode:upper(), "DermaLarge",
                            w/2, h/2, Color(255, 255, 255, 200 + math.sin(CurTime() * 5) * 55),
                            TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
                    end
                    puppet.PuppetWarning = warning
                end
            else
                puppetConnections[master] = nil

                -- Remove warning
                if puppet == LocalPlayer() and IsValid(puppet.PuppetWarning) then
                    puppet.PuppetWarning:Remove()
                end

                -- Play release sound
                puppet:EmitSound("npc/stalker/go_alert2b.wav", 75, 150, 0.5)
            end
        end
    })

    -- Draw puppet strings effect
    hook.Add("PostDrawTranslucentRenderables", "GM3_PuppetMaster_Strings", function()
        for master, data in pairs(puppetConnections) do
            if IsValid(master) and IsValid(data.puppet) and data.strings then
                -- Draw ethereal strings between puppet and master
                local masterPos = master:GetPos() + Vector(0, 0, 70)
                local puppetPoints = {
                    data.puppet:GetBonePosition(data.puppet:LookupBone("ValveBiped.Bip01_L_Hand") or 0) or data.puppet:GetPos(),
                    data.puppet:GetBonePosition(data.puppet:LookupBone("ValveBiped.Bip01_R_Hand") or 0) or data.puppet:GetPos(),
                    data.puppet:GetBonePosition(data.puppet:LookupBone("ValveBiped.Bip01_Head1") or 0) or data.puppet:GetPos() + Vector(0,0,60),
                    data.puppet:GetPos() + Vector(0, 0, 40)
                }

                for _, point in pairs(puppetPoints) do
                    -- Draw glowing string
                    render.SetMaterial(Material("cable/cable2"))
                    render.DrawBeam(masterPos, point, 2, 0, 1,
                        Color(200, 100, 255, 100 + math.sin(CurTime() * 3) * 50))

                    -- Add sparkle effects along the string
                    if math.random() < 0.1 then
                        local midPoint = (masterPos + point) / 2
                        local effectData = EffectData()
                        effectData:SetOrigin(midPoint)
                        effectData:SetScale(0.5)
                        util.Effect("ManhackSparks", effectData)
                    end
                end
            end
        end
    end)

    -- HUD indicator
    hook.Add("HUDPaint", "GM3_PuppetMaster_HUD", function()
        local master = LocalPlayer():GetNWEntity("gm3_puppet_master")
        local puppet = LocalPlayer():GetNWEntity("gm3_puppet_target")

        if IsValid(master) then
            -- Being controlled
            draw.SimpleText("CONTROLLED BY: " .. master:Nick(), "DermaLarge",
                ScrW()/2, 100, Color(200, 100, 200, 200),
                TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        elseif IsValid(puppet) then
            -- Controlling someone
            draw.SimpleText("CONTROLLING: " .. puppet:Nick(), "DermaLarge",
                ScrW()/2, 100, Color(200, 0, 200, 200),
                TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
    end)
end