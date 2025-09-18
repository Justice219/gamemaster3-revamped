gm3 = gm3

if SERVER then
    gm3 = gm3
    lyx = lyx
    
    local tool = GM3Module.new(
        "Blind",
        "Makes a player go blind with a specified color.", 
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
            ["Blind Color"] = {
                type = "color",
                def = Color(255, 255, 255) -- Default white
            },
        },
        function(ply, args)
            -- Get the target player using gm3 helper function
            local target = gm3:GetPlayerBySteamID(args["Target Player"])
            if not IsValid(target) then
                lyx:MessagePlayer({["type"] = "header",["color1"] = Color(0,255,213),["header"] = "Blind",["color2"] = Color(255,255,255),["text"] = "Player not found! Please select a valid player.",
                    ["ply"] = ply
                })
                return
            end

            // Get the color from args (it's already a Color object)
            local color = args["Blind Color"] or Color(255, 255, 255)

            // fade the screen to the color
            target:ScreenFade(SCREENFADE.IN, color, 1, 0)

            // remove the fade after duration
            timer.Simple(args["Duration"], function()
                if IsValid(target) then
                    target:ScreenFade(SCREENFADE.OUT, color, 1, 0)
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