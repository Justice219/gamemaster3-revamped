gm3 = gm3

if SERVER then
    gm3 = gm3
    lyx = lyx
    
    local tool = GM3Module.new(
        "Blind",
        "Makes a player go blind with a specified color. NAME OR STEAMID", 
        "Justice#4956",
        {
            ["Name/SteamID"] = {
                type = "string",
                def = "Garry"
            },
            ["Duration"] = {
                type = "number",
                def = 5
            },
            ["Color"] = {
                type = "string",
                def = "255,255,255"
            },
        },
        function(ply, args)
            local target = nil 
            for k,v in pairs(player.GetAll()) do
                if v:Nick() == args["Name/SteamID"] or v:SteamID() == args["Name/SteamID"] then
                    target = v
                end
            end
            if not IsValid(target) then
                lyx:MessagePlayer({["type"] = "header",["color1"] = Color(0,255,213),["header"] = "Shrink",["color2"] = Color(255,255,255),["text"] = "Player not found!",
                    ["ply"] = ply
                })
                return
            end

            // check if color is blank
            local color = args["Color"]
            if color == "" then
                // set to black if color is blank
                color = Color(0,0,0)
            else
                local tbl = string.Explode(",", color)
                color = Color(tonumber(tbl[1]),tonumber(tbl[2]),tonumber(tbl[3]))
            end

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
    gm3:addTool(tool)
end

if CLIENT then
    gm3 = gm3
    lyx = lyx


end