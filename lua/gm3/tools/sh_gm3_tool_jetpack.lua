gm3 = gm3

if SERVER then
    gm3 = gm3
    lyx = lyx
    
    local tool = GM3Module.new(
        "Jetpack",
        "Gives a player a jetlike effect, allowing them to fly around.", 
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
                lyx:MessagePlayer({["type"] = "header",["color1"] = Color(0,255,213),["header"] = "Jetpack",["color2"] = Color(255,255,255),["text"] = "Player not found! Please select a valid player.",
                    ["ply"] = ply
                })
                return
            end

            target:SetMoveType(MOVETYPE_FLY)
            target:SetGravity(0.1)
            target:SetVelocity(Vector(0,0,1000))
            target:SetLocalVelocity(Vector(0,0,1000))
            target:SetNWBool("jetpack", true)
            target:SetNWInt("jetpacktime", args["Duration"])
            timer.Simple(args["Duration"], function()
                if IsValid(target) then
                    target:SetMoveType(MOVETYPE_WALK)
                    target:SetGravity(1)
                    target:SetNWBool("jetpack", false)
                end
            end)
        end,
        "Control" -- Category for tools affecting player control/movement
    gm3:addTool(tool)
end

if CLIENT then
    gm3 = gm3
    lyx = lyx


end