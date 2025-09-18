gm3 = gm3

if SERVER then
    gm3 = gm3
    lyx = lyx
    
    local tool = GM3Module.new(
        "Glow",
        "Makes a player glow. Leave color blank to use random color.", 
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
            ["Glow Color"] = {
                type = "color",
                def = Color(255, 255, 255) -- Default white
            },
            ["Random Color"] = {
                type = "boolean",
                def = false -- Use random color instead of selected
            },
        },
        function(ply, args)
            -- Get the target player using gm3 helper function
            local target = gm3:GetPlayerBySteamID(args["Target Player"])
            if not IsValid(target) then
                lyx:MessagePlayer({["type"] = "header",["color1"] = Color(0,255,213),["header"] = "Glow",["color2"] = Color(255,255,255),["text"] = "Player not found! Please select a valid player.",
                    ["ply"] = ply
                })
                return
            end

            // Get the color - use random if specified
            local color
            if args["Random Color"] then
                color = Color(math.random(0,255), math.random(0,255), math.random(0,255))
            else
                color = args["Glow Color"] or Color(255, 255, 255)
            end

            // set player glow
            target:SetColor(color)
            target:SetMaterial("models/effects/vol_light001")

            // remove glow after duration
            timer.Simple(args["Duration"], function()
                if IsValid(target) then
                    target:SetColor(Color(255,255,255))
                    target:SetMaterial("")
                end
            end)
        end,
        "Visual" -- Category for tools affecting player vision/display
    )
    gm3:addTool(tool)
end

if CLIENT then
    gm3 = gm3
    lyx = lyx


end