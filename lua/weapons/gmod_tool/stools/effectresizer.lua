AddCSLuaFile()

local unique_name = "Effect Resizer 641848001"

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

--[[-------------------------------------------------------------------------
Register duplicator entity modifier
---------------------------------------------------------------------------]]
duplicator.RegisterEntityModifier(unique_name,
CLIENT and function(ply, ent, scale)
	print("THIS IS RUNNING IN CLIENT")
	ent:EnableMatrix("RenderMultiply", scale)
end or
SERVER and function(ply, ent, scale)

end)


if SERVER then util.AddNetworkString(unique_name) end
if CLIENT then
	net.Receive(unique_name, function()
		local effect = net.ReadEntity()
		if not IsValid(effect) then return end

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

	local scale = Vector(self:GetClientNumber("scalex"), self:GetClientNumber("scaley"), self:GetClientNumber("scalez"))

	effect:SetNWVector("RenderMultiplyMatrixScale", scale)

	net.Start(unique_name)
		net.WriteEntity(effect)
	net.Broadcast()

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

	local scale = effect:GetNWVector("RenderMultiplyMatrixScale", Vector( 1, 1, 1 ))
	self:GetOwner():ConCommand( "effectresizer_scalex " .. scale.x)
	self:GetOwner():ConCommand( "effectresizer_scaley " .. scale.y)
	self:GetOwner():ConCommand( "effectresizer_scalez " .. scale.z)

	return true
end

function TOOL:Reload( trace )
	local ent = trace.Entity
	if not IsValid(ent) then return false end
	if ent:GetClass() ~= "prop_effect" then return false end
	if CLIENT then return true end

	-- Only the server has AttachedEntity
	local effect = ent.AttachedEntity
	if not IsValid(effect) then return false end

	effect:SetModelScale(1)

	local scale = Vector(1, 1, 1)
	effect:SetNWVector("RenderMultiplyMatrixScale", scale)

	net.Start(unique_name)
		net.WriteEntity(effect)
	net.Broadcast()

	return true
end

function TOOL.BuildCPanel(CPanel)
	CPanel:NumSlider("Scale: ", "effectresizer_scale", 0, 10)
	CPanel:NumSlider("X Scale: ", "effectresizer_scalex", 0, 1)
	CPanel:NumSlider("Y Scale: ", "effectresizer_scaley", 0, 1)
	CPanel:NumSlider("Z Scale: ", "effectresizer_scalez", 0, 1)
end
