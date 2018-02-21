AddCSLuaFile()

local unique_name = "Effect_Resizer_641848001"
if SERVER then util.AddNetworkString(unique_name) end

TOOL.Category = "Poser"
TOOL.Name = "#tool.effectresizer.name"
TOOL.Information = {
		{ name = "left" },
		{ name = "right" },
		{ name = "reload" }
}

if CLIENT then
	language.Add("tool.effectresizer.name", "Effect Resizer")
	language.Add("tool.effectresizer.desc", "Resize Effects")
	language.Add("tool.effectresizer.left", "Resize an effect")
	language.Add("tool.effectresizer.right", "Copy an effect's size")
	language.Add("tool.effectresizer.reload", "Reset an effect's size to normal")
end

TOOL.ClientConVar.scale = 1
TOOL.ClientConVar.scalex = 1
TOOL.ClientConVar.scaley = 1
TOOL.ClientConVar.scalez = 1

local function SetDimensions(ply, effect, data)
	if CLIENT then
		ErrorNoHalt("How did I get here?")
		return
	end

	-- server
	local dims = data.dimensions
	local x, y, z = dims.x, dims.y, dims.z

	local fullsize = x == 1 and y == 1 and z == 1 -- if all dimensions are 1, then there's no dimensions at all

	local xflat = (x == 0) and 1 or 0
	local yflat = (y == 0) and 1 or 0
	local zflat = (z == 0) and 1 or 0
	local tooflat = xflat + yflat + zflat > 1	-- only one axis is allowed to be flat, otherwise nothing is visible

	if fullsize or tooflat then
		-- bad/irrelevant scale
		effect:SetNW2Vector(unique_name, nil)
		duplicator.ClearEntityModifier(effect, unique_name) -- I've checked the duplicator library source code, and removing a modifier while it's being run will not cause problems. It loops through available modifiers, not through the entity's modifiers.
	else
		effect:SetNW2Vector(unique_name, data.dimensions)
		duplicator.StoreEntityModifier(effect, unique_name, data)
	end

	net.Start(unique_name)
		net.WriteEntity(effect)
	net.Broadcast()
end

--[[-------------------------------------------------------------------------
Register duplicator entity modifier
---------------------------------------------------------------------------]]
duplicator.RegisterEntityModifier(unique_name, SetDimensions)

--[[-------------------------------------------------------------------------
Server tells client of scale changes
---------------------------------------------------------------------------]]

if CLIENT then
	net.Receive(unique_name, function()
		local effect = net.ReadEntity()
		if not IsValid(effect) then error("Invalid entity!") end

		local dims = effect:GetNW2Vector(unique_name, 0)
		if dims == 0 then
			effect:DisableMatrix("RenderMultiply")
			return
		end

		local mult = Matrix()
		mult:Scale(dims)
		effect:EnableMatrix("RenderMultiply", mult)
		--[[
		timer.Simple(0.25, function()	-- gotta delay this so that the NWVector arrives, how shitty is that?
			local scale = effect:GetNWVector("RenderMultiplyMatrixScale", Vector( 1, 1, 1 ))

			local nochange = scale.x == 1 and scale.y == 1 and scale.z == 1	-- disable matrix scaling altogether

			local xflat = (scale.x == 0) and 1 or 0
			local yflat = (scale.y == 0) and 1 or 0
			local zflat = (scale.z == 0) and 1 or 0

			local tooflat = xflat + yflat + zflat > 1	-- only one axis is allowed to be flat (and even that's not really recommended)

			if nochange or tooflat then
				effect:DisableMatrix("RenderMultiply")
			else
				local mat = Matrix()
				mat:Scale( scale )
				effect:EnableMatrix( "RenderMultiply", mat )
			end
		end)
		]]
	end)
end

--[[-------------------------------------------------------------------------
Left-click - resize target effect
---------------------------------------------------------------------------]]
function TOOL:LeftClick( trace )
	local ent = trace.Entity
	if not IsValid(ent) then return false end
	if ent:GetClass() ~= "prop_effect" then return false end
	if CLIENT then return true end

	-- Only the server has AttachedEntity
	local effect = ent.AttachedEntity
	if not IsValid(effect) then return false end -- sadly can't be synced with client, but it should never really happen anyway

	effect:SetModelScale(self:GetClientNumber("scale"))

	local dims = Vector(self:GetClientNumber("scalex"), self:GetClientNumber("scaley"), self:GetClientNumber("scalez"))

	SetDimensions(self:GetOwner(), effect, {dimensions = dims})

	return true
end

--[[-------------------------------------------------------------------------
Right-click - copy the target effect's settings
---------------------------------------------------------------------------]]
function TOOL:RightClick( trace )
	local ent = trace.Entity
	if not IsValid(ent) then return false end
	if ent:GetClass() ~= "prop_effect" then return false end
	if CLIENT then return true end

	-- Only the server has AttachedEntity
	local effect = ent.AttachedEntity
	if not IsValid(effect) then return false end

	self:GetOwner():ConCommand( "effectresizer_scale " .. effect:GetModelScale())

	local dims = effect:GetNW2Vector(unique_name, Vector( 1, 1, 1 ))
	self:GetOwner():ConCommand( "effectresizer_scalex " .. dims.x)
	self:GetOwner():ConCommand( "effectresizer_scaley " .. dims.y)
	self:GetOwner():ConCommand( "effectresizer_scalez " .. dims.z)

	return true
end

--[[-------------------------------------------------------------------------
Reload - reset target effect's scale to normal
---------------------------------------------------------------------------]]
function TOOL:Reload( trace )
	local ent = trace.Entity
	if not IsValid(ent) then return false end
	if ent:GetClass() ~= "prop_effect" then return false end
	if CLIENT then return true end

	-- Only the server has AttachedEntity
	local effect = ent.AttachedEntity
	if not IsValid(effect) then return false end

	effect:SetModelScale(1)
	SetDimensions(self:GetOwner(), effect, {dimensions = Vector(1, 1, 1)})

	return true
end

function TOOL.BuildCPanel(CPanel)
	CPanel:NumSlider("Scale: ", "effectresizer_scale", 0, 10)
	CPanel:NumSlider("X Scale: ", "effectresizer_scalex", 0, 1)
	CPanel:NumSlider("Y Scale: ", "effectresizer_scaley", 0, 1)
	CPanel:NumSlider("Z Scale: ", "effectresizer_scalez", 0, 1)
end
