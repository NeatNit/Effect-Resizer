AddCSLuaFile()

TOOL.Category = "Poser"
TOOL.Name = "#tool.effectresizer.name"

if CLIENT then
	language.Add("tool.effectresizer.name", "Effect Resizer")
	language.Add("tool.effectresizer.desc", "Resize Effects")
	language.Add("tool.effectresizer.0", "Left Click to apply, Right Click to copy, Reload to reset")
end

TOOL.ClientConVar[ "scale" ] = 1
TOOL.ClientConVar[ "scalex" ] = 1
TOOL.ClientConVar[ "scaley" ] = 1
TOOL.ClientConVar[ "scalez" ] = 1


if SERVER then util.AddNetworkString("EffectResizeEntityMatrix") end
if CLIENT then
	net.Receive("EffectResizeEntityMatrix", function()
		local effect = net.ReadEntity()
		if !IsValid(effect) then return end

		local mat = Matrix()
		
		timer.Simple(0.25, function()	-- gotta delay this so that the NWVector arrives, how shitty is that?
			local scale = effect:GetNWVector("RenderMultiplyMatrixScale", Vector( 1, 1, 1 ))
			
			local nochange = (scale.x == 1 and scale.y == 1 and scale.z == 1)	-- disable matrix scaling altogether

			local xflat = (scale.x == 0) and 1 or 0
			local yflat = (scale.y == 0) and 1 or 0
			local zflat = (scale.z == 0) and 1 or 0

			local tooflat = (xflat + yflat + zflat > 1)	-- only one axis is allowed to be flat (and even that's not really recommended)

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

function TOOL:LeftClick( trace )
	local ent = trace.Entity
	if !IsValid(ent) then return false end
	if ent:GetClass() != "prop_effect" then return false end
	if CLIENT then return true end

	local effect = ent.AttachedEntity
	if !IsValid(effect) then return false end -- sadly can't be synced with client

	effect:SetModelScale(self:GetClientNumber("scale"))

	local scale = Vector(self:GetClientNumber("scalex"), self:GetClientNumber("scaley"), self:GetClientNumber("scalez"))
	
	effect:SetNWVector("RenderMultiplyMatrixScale", scale)

	net.Start("EffectResizeEntityMatrix")
		net.WriteEntity(effect)
	net.Broadcast()

	return true
end

function TOOL:RightClick( trace )
	local ent = trace.Entity
	if !IsValid(ent) then return false end
	if ent:GetClass() != "prop_effect" then return false end
	if CLIENT then return true end

	local effect = ent.AttachedEntity
	if !IsValid(effect) then return false end -- sadly can't be synced with client

	self:GetOwner():ConCommand( "effectresizer_scale " .. effect:GetModelScale())
	return true
end

function TOOL:Reload( trace )
	local ent = trace.Entity
	if !IsValid(ent) then return false end
	if ent:GetClass() != "prop_effect" then return false end
	if CLIENT then return true end

	local effect = ent.AttachedEntity
	if !IsValid(effect) then return false end -- sadly can't be synced with client

	effect:SetModelScale(1)
	
	local scale = Vector(1, 1, 1)
	effect:SetNWVector("RenderMultiplyMatrixScale", scale)

	net.Start("EffectResizeEntityMatrix")
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