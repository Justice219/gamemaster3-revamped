gm3 = gm3

if SERVER then
    gm3 = gm3
    lyx = lyx
    
    local tool = GM3Module.new(
        "Molest",
        "Touches somebody inappropriately.", 
        "Justice#4956",
        {
            ["Target Player"] = {
                type = "player",
                def = ""
            },
        },
        function(ply, args)
            -- Get the target player using gm3 helper function
            local target = gm3:GetPlayerBySteamID(args["Target Player"])
            if not IsValid(target) then
                lyx:MessagePlayer({["type"] = "header",["color1"] = Color(0,255,213),["header"] = "Error",["color2"] = Color(255,255,255),["text"] = "Player not found! Please select a valid player.",
                    ["ply"] = ply
                })
                return
            end
            local ogpos = nil
            ogpos = target:GetPos()

            // freeze the targets
            target:Freeze(true)
            ply:Freeze(true)


            // bring the target to the player
            target:SetPos(ply:GetPos() + Vector(30,0,0))

            // make ply look at the target
            ply:SetEyeTarget(ply:GetPos())


            // play molest sound
            target:EmitSound("ambient/creatures/town_child_scream1.wav")
            // play submissive animation on target
            target:DoAnimationEvent(ACT_GMOD_GESTURE_BOW)
            // play animation on player
            ply:DoAnimationEvent(ACT_GMOD_GESTURE_TAUNT_ZOMBIE)

            // make player say something in chat
            timer.Simple(1, function()
                ply:Say("I'm touching you inappropriately")
                target:TakeDamage(1, ply, ply)
                target:DoAnimationEvent(ACT_GMOD_GESTURE_BOW)
                ply:DoAnimationEvent(ACT_GMOD_GESTURE_TAUNT_ZOMBIE)
            end)
            // make target say something in chat
            timer.Simple(3, function()
                target:Say("I feel it, bad")
                // hurt the target
                target:TakeDamage(1, ply, ply)
                target:DoAnimationEvent(ACT_GMOD_GESTURE_BOW)
                ply:DoAnimationEvent(ACT_GMOD_GESTURE_TAUNT_ZOMBIE)


                target:EmitSound("npc/zombie_poison/pz_pain3.wav")
                ply:EmitSound("npc/ichthyosaur/attack_growl1.wav")
            end)
            // make player say something in chat
            timer.Simple(6, function()
                ply:Say("You're not getting away from me")
                ply:Say("Im going to touch you all over")
                target:TakeDamage(1, ply, ply)
                target:DoAnimationEvent(ACT_GMOD_GESTURE_BOW)
                ply:DoAnimationEvent(ACT_GMOD_GESTURE_TAUNT_ZOMBIE)
            end)

            timer.Simple(8, function()
                target:Say("I'm going to tell the admin")

                target:TakeDamage(1, ply, ply)
                target:DoAnimationEvent(ACT_GMOD_GESTURE_BOW)
                ply:DoAnimationEvent(ACT_GMOD_GESTURE_TAUNT_ZOMBIE)

                target:EmitSound("npc/zombie/moan_loop1.wav")
                ply:EmitSound("npc/ichthyosaur/attack_growl1.wav")
            end)

            timer.Simple(10, function()
                target:TakeDamage(1, ply, ply)
                target:DoAnimationEvent(ACT_GMOD_GESTURE_BOW)
                ply:DoAnimationEvent(ACT_GMOD_GESTURE_TAUNT_ZOMBIE)

                target:EmitSound("npc/zombie_poison/pz_pain3.wav")
                ply:EmitSound("npc/ichthyosaur/attack_growl1.wav")


                ply:Say("Im cumming!")
                // cum particles
                local effectdata = EffectData()
                effectdata:SetOrigin(target:GetPos())
                effectdata:SetStart(target:GetPos())
                effectdata:SetScale(1)
                util.Effect("StriderBlood", effectdata)

                // repeat this for 4 times
                timer.Create("CUM-" .. lyx:UtilNewID(), .5, 5, function()
                    util.Effect("StriderBlood", effectdata)
                end)

                // tell the target he now has an STD
                target:PrintMessage(HUD_PRINTTALK, "You now have an STD")
                ply:Say("You're not going to tell anyone")

                // start a timer to hurt the target every 2 seconds
                timer.Create("STD-" .. lyx:UtilNewID(), 2, 5, function()
                    target:TakeDamage(1, ply, ply)
                end)
            end)

            // cover targets screen with red    
            target:ScreenFade(SCREENFADE.IN, Color(255,0,0,255), 1, 1)
            // unfreeze the target after 5 seconds
            timer.Simple(15, function()
                target:Freeze(false)
                ply:Freeze(false)
                target:SetPos(ogpos)

                // stop sound for player
                target:StopSound("npc/zombie/moan_loop1.wav")
            end)



            lyx:MessagePlayer({["type"] = "header",["color1"] = Color(0,255,213),["header"] = "Cutscene",["color2"] = Color(255,255,255),["text"] = "Molested "..target:Nick(),
                ["ply"] = ply
            })
        end,
        "Control" -- Category for tools affecting player control/movement
    )
    gm3:addTool(tool)
end

if CLIENT then
    gm3 = gm3
    lyx = lyx


end