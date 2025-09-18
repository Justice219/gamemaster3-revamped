TOOL.Category		=	"Gamemaster 3"
TOOL.Name			=	"Hashing"
TOOL.Command		=	nil
TOOL.ConfigName		=	""

TOOL.ClientConVar["levels"] = 20

local Classes = {
	["func_door"] = true,
	["func_door_rotating"] = true,
	["prop_door_rotating"] = true,
	["prop_testchamber_door"] = true
}

if CLIENT then
	language.Add("Tool.gm3_hashing.name", "Hashing")
	language.Add("Tool.gm3_hashing.desc", "Allows a player to create hashlocks")
	language.Add("Tool.gm3_hashing.0", "Left Click: Hash, Right Click: Unhash")
	language.Add("tool.gm3_hashing.levels", "Amount of Levels:")
	

	surface.CreateFont("HashingToolScreenFont", { font = "Arial", size = 40, weight = 1000, antialias = true, additive = false })
	surface.CreateFont("HashingToolScreenSubFont", { font = "Arial", size = 30, weight = 1000, antialias = true, additive = false })
end

if SERVER then
	util.AddNetworkString("gm3:hashing:lock")
	util.AddNetworkString("gm3:hashing:unlock")
	util.AddNetworkString("gm3:newHash")
	util.AddNetworkString("gm3:removeHash")
	util.AddNetworkString("gm3:hashUse")
	util.AddNetworkString("gm3:hashing:win")

	gm3.hashing = gm3.hashing or {}
end

function TOOL:LeftClick(trace)
	if SERVER then return true end 

	local ENT = trace.Entity
	if not IsValid(ENT) or not Classes[ENT:GetClass()] then return false end

	net.Start("gm3:hashing:lock")
		net.WriteEntity(ENT)
		net.WriteInt(self:GetClientNumber("levels"), 32)
	net.SendToServer()

	return true
end

function TOOL:RightClick(trace)
	if SERVER then return true end 

	local ENT = trace.Entity
	if not IsValid(ENT) or not Classes[ENT:GetClass()] then return false end
	
	net.Start("gm3:hashing:unlock")
		net.WriteEntity(ENT)
	net.SendToServer()

	return true
end

function TOOL:Reload(trace)
	if CLIENT then return true end

	return true
end

function TOOL.BuildCPanel(panel)

	panel:AddControl("Header",{Text = "Hashing Tool", Description = "Hashing Tool \n Allows a player to hash lock doors."})
	panel:AddControl("Slider",{Label = "#tool.gm3_hashing.levels", Command = "gm3_hashing_levels", Min = 0, Max = 100, type = "Int"})

end

function TOOL:DrawToolScreen(width, height)

	if SERVER then return end

	surface.SetDrawColor(175, 37, 37)
	surface.DrawRect(0, 0, 256, 256)

	surface.SetFont("HashingToolScreenFont")
	local w, h = surface.GetTextSize(" ")
	surface.SetFont("HashingToolScreenSubFont")
	local w2, h2 = surface.GetTextSize(" ")

	draw.SimpleText("Hashing Tool", "HashingToolScreenFont", 128, 100, Color(224, 224, 224, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, Color(17, 148, 240, 255), 4)
	draw.SimpleText("By Justice", "HashingToolScreenSubFont", 128, 128 + (h + h2) / 2 - 4, Color(224, 224, 224, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, Color(17, 148, 240, 255), 4)

end

print("Hashing Tool Loaded")

// networking
if CLIENT then
	surface.CreateFont("HashFont", {
		font = "DermaDefault",
		size = 60,
		weight = 500,
		antialias = true,
		additive = false,
		bold = true
	})

	function gm3:DrawHash(ent, id, levels)
		local imgui = include("lyx_core/thirdparty/cl_lyx_imgui.lua")
		
		local ply = LocalPlayer()
		local trace = ply:GetEyeTrace()
		local pos = trace.HitPos + Vector(0,10,0)
		local ang = trace.HitNormal:Angle()
		ang:RotateAroundAxis(ang:Right(), -90)
		ang:RotateAroundAxis(ang:Up(), 90)
		
		local oscillationSpeed = 1 -- adjust this value to change the speed of the oscillation
		local oscillationRange = 200 -- adjust this value to change the range of the oscillation

		local levelAmount = levels
	

		surface.CreateFont("HashFont", {
			font = "DermaDefault",
			size = 60,
			weight = 500,
			antialias = true,
			additive = false,
			bold = true
		})

		hook.Add("PostDrawOpaqueRenderables", "gm3_hashing_" .. id, function()
			if not IsValid(ent) then
				hook.Remove("PostDrawOpaqueRenderables", "gm3_hashing_" .. id)
				return
			end

			local xOffset = math.sin(CurTime() * oscillationSpeed) * oscillationRange
		
			cam.Start3D2D(pos, ang, 0.05)
				draw.RoundedBox(0, -600, -45, 1200, 90, Color(255, 0, 0, 159)) -- Center the box
				draw.SimpleText("HASH LOCKED", "HashFont", xOffset, 0, Color(0, 0, 0), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER) -- Center the text
				draw.SimpleText("LEVEL AMOUNT: " .. levelAmount, "HashFont", xOffset, 75, Color(255, 255, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER) -- Center the text
			cam.End3D2D()
		end)
	end

	net.Receive("gm3:newHash", function()
		local ent = net.ReadEntity()
		local id = net.ReadString()
		local level = net.ReadInt(32)

		gm3:DrawHash(ent, id, level)
	end)

	net.Receive("gm3:removeHash", function()
		local ent = net.ReadEntity()
		local id = net.ReadString()

		hook.Remove("PostDrawOpaqueRenderables", "gm3_hashing_" .. id)
	end)

	net.Receive("gm3:hashUse", function()
		local ent = net.ReadEntity()
		local levels = net.ReadString()

		// open panel
		

		// If the panel already exists, don't create a new one
		if IsValid(gm3.HashingPanel) then return end

		// open panel
		gm3.HashingPanel = vgui.Create("GM3.Hashing")
		if IsValid(gm3.HashingPanel) then
			local function callback()
				print("DOOR UNLOCKED")
			end
			gm3.HashingPanel:Setup(levels, callback, ent)
		end
	end)
end

if SERVER then
	gm3.hashing = gm3.hashing or {}

	net.Receive("gm3:hashing:lock", function(len, ply)
		if !gm3:SecurityCheck(ply) then return end
		local ent = net.ReadEntity()
		local levels = net.ReadInt(32)

		// check if the entity is already hashed
		local data = gm3.hashing[tostring(ent:EntIndex())]
		// check if data exists, if it does, check if locked
		if data then
			if data.locked then return end
		end

		local id = lyx:UtilNewID()

		// add to table for tracking
		gm3.hashing[tostring(ent:EntIndex())] = {
			ent = ent,
			levels = levels,
			id = id,
			locked = true,
			index = tostring(ent:EntIndex()),
			pos = ent:GetPos()
		}

		net.Start("gm3:newHash")
			net.WriteEntity(ent)
			net.WriteString(id)
			net.WriteInt(levels, 32)
		net.Broadcast()

		-- // create use hook
		-- hook.Add("PlayerUse", "gm3:hashing:" .. id, function(ply, hashedEnt)
		-- 	// check if ent is the hashed entity
		-- 	if !ent == hashedEnt then return end

		-- 	net.Start("gm3:hashUse")
		-- 		net.WriteEntity(ent)
		-- 		net.WriteString(levels)
		-- 	net.Send(ply)
		-- end)
		-- key down instead of PlayerUse

		-- OK THIS IS SO UNOPTIMIZED BUT I CANT THINK OF A BETTER WAY TO DO THIS
		-- THE COMMMENTED HOOK ABOVE WORKS ON SPECIFIC ENVIROMENTS BUT NOT ON OTHERS
		-- THEREFORE WE MUST USE KEY PRESS INSTEAD OF PLAYER USE, SORRY PERFORMANCE
		hook.Add("KeyPress", "gm3:hashing:" .. id, function(ply, key)
			-- check if the key is the use key
			if key != IN_USE then return end

			-- check player eye trace
			local trace = ply:GetEyeTrace()
			local traceEnt = trace.Entity

			-- check if the entity is the hashed entity
			if traceEnt != ent then return end

			net.Start("gm3:hashUse")
				net.WriteEntity(ent)
				net.WriteString(levels)
			net.Send(ply)

		end)

		print(id)

		ent:Fire("lock")

		-- message player that they have hashed the door
		lyx:MessagePlayer({
			["type"] = "header",
			["color1"] = Color(0,255,213),
			["header"] = "Gamemaster 3",
			["color2"] = Color(255,255,255),
			["text"] = "You have hashed the door!",
			["ply"] = ply
		})
	end)

	net.Receive("gm3:hashing:unlock", function(len, ply)
		if !gm3:SecurityCheck(ply) then return end
		local ent = net.ReadEntity()

		-- check if the entity is already hashed
		local data = gm3.hashing[tostring(ent:EntIndex())]
		-- check if data exists, if it does, check if locked
		if data then
			if !data.locked then return end
		else
			return
		end

		-- prevent from running multiple times

		
		-- match the entity to the table
		local data = gm3.hashing[tostring(ent:EntIndex())]
		
		-- remove hash
		net.Start("gm3:removeHash")
			net.WriteEntity(ent)
			net.WriteString(data.id)
		net.Broadcast()

		ent:Fire("unlock")

		// unlock in table
		gm3.hashing[tostring(ent:EntIndex())].locked = false

		// remove use hook
		hook.Remove("KeyPress", "gm3:hashing:" .. data.id)

		// message player that unlocked
		lyx:MessagePlayer({
			["type"] = "header",
			["color1"] = Color(0,255,213),
			["header"] = "Gamemaster 3",
			["color2"] = Color(255,255,255),
			["text"] = "You have unhashed the door!",
			["ply"] = ply
		})

	end)

	net.Receive("gm3:hashing:win", function(len, ply)
		local ent = net.ReadEntity()
		local data = gm3.hashing[tostring(ent:EntIndex())]

		// remove hash
		net.Start("gm3:removeHash")
			net.WriteEntity(ent)
			net.WriteString(data.id)
		net.Broadcast()

		ent:Fire("unlock")
		// unlock in table
		gm3.hashing[tostring(ent:EntIndex())].locked = false

		// remove use hook
		hook.Remove("KeyPress", "gm3:hashing:" .. data.id)

		print("Unhashed Entity")
	end)
end