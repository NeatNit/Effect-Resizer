AddCSLuaFile()

local unique_name = "Effect_Resizer_641848001"
local ANIM_LENGTH = 0.2
local EASE = 0.5

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

local SetDimensions

if SERVER then
	function SetDimensions(ply, effect, data, scale)
		if CLIENT then
			ErrorNoHalt("How did I get here?")
			return
		end

		-- server
		if not IsValid(effect) then return end

		if scale then effect:SetModelScale(scale, ANIM_LENGTH) end

		local old_dims = effect:GetNW2Vector(unique_name, Vector(1, 1, 1))

		local new_dims = data.dimensions
		local x, y, z = new_dims.x, new_dims.y, new_dims.z

		local fullsize = x == 1 and y == 1 and z == 1 -- if all dimensions are 1, then there's no dimensions at all

		local xflat = (x == 0) and 1 or 0
		local yflat = (y == 0) and 1 or 0
		local zflat = (z == 0) and 1 or 0
		local tooflat = xflat + yflat + zflat > 1	-- only one axis is allowed to be flat, otherwise nothing is visible

		if fullsize or tooflat then
			-- bad/irrelevant dimensions
			effect:SetNW2Vector(unique_name, nil)
			duplicator.ClearEntityModifier(effect, unique_name) -- I've checked the duplicator library source code, and removing a modifier while it's being run will not cause problems. It loops through available modifiers, not through the entity's modifiers.
		else
			effect:SetNW2Vector(unique_name, data.dimensions)
			duplicator.StoreEntityModifier(effect, unique_name, data)
		end

		net.Start(unique_name)
			net.WriteUInt(effect:EntIndex(), 16)	-- entity might not yet be valid clientside, so send as entity index
			net.WriteVector(scale and old_dims or new_dims)	-- in general, this writes old_dims; However, if this was called from the duplicator library, I don't want the animation to play, so I send new_dims twice.
			net.WriteVector(new_dims)
		net.Broadcast()
	end

	--[[-------------------------------------------------------------------------
	Register duplicator entity modifier
	---------------------------------------------------------------------------]]
	duplicator.RegisterEntityModifier(unique_name, SetDimensions)
end

--[[-------------------------------------------------------------------------
Server tells client of scale changes
---------------------------------------------------------------------------]]

if CLIENT then
	--[[-------------------------------------------------------------------------
	SetEffectDimensions - scale an entity visually with a vector
		(this automatically converts it to a matrix and applies it to the effect)
	---------------------------------------------------------------------------]]
	local function SetEffectDimensions(ent, dims)
		if not dims or dims == Vector(1, 1, 1) then
			ent:DisableMatrix("RenderMultiply")
		else
			local mrx = Matrix()
			mrx:Scale(dims)
			ent:EnableMatrix("RenderMultiply", mrx)
		end
	end

	--[[-------------------------------------------------------------------------
	On initial load, load entities' dimensions
	---------------------------------------------------------------------------]]
	hook.Add("InitPostEntity", unique_name, function()
		for k, ent in pairs(ents.GetAll()) do
			local dims = ent:GetNW2Vector(unique_name, 0)
			if dims ~= 0 then
				SetEffectDimensions(ent, dims)
			end
		end
	end)

	--[[=========================================================================
	Resizing Animations
	===========================================================================]]
	local animation_list = {}

	--[[-------------------------------------------------------------------------
	Start a resizing animation on an effect
	---------------------------------------------------------------------------]]
	local function StartAnimation(ent, from_dims, to_dims)
		animation_list[ent] = {
			start_time = CurTime(),
			from_dims = from_dims,
			to_dims = to_dims
		}

		SetEffectDimensions(ent, from_dims)
	end

	--[[-------------------------------------------------------------------------
	Handle animation
	---------------------------------------------------------------------------]]
	hook.Add("Think", unique_name, function()
		if next(animation_list) == nil then return end -- nothing to do

		local now = CurTime()

		for ent, data in pairs(animation_list) do
			if not IsValid(ent) then
				animation_list[ent] = nil
			else
				local progress = (now - data.start_time) / ANIM_LENGTH
				if progress >= 1 then	-- animation finished
					SetEffectDimensions(ent, data.to_dims)
					animation_list[ent] = nil
				else
					SetEffectDimensions(ent, LerpVector(math.EaseInOut(progress, EASE, EASE), data.from_dims, data.to_dims))
				end
			end
		end
	end)

	--[[=========================================================================
	Networking - client
	===========================================================================]]
	local waiting_list = {}

	--[[-------------------------------------------------------------------------
	Receive a new entity resize from the server
	---------------------------------------------------------------------------]]
	net.Receive(unique_name, function()
		local ent_id = net.ReadUInt(16)
		local old_dims = net.ReadVector()
		local new_dims = net.ReadVector()

		local effect = Entity(ent_id)

		if IsValid(effect) then
			StartAnimation(effect, old_dims, new_dims)
		else
			-- newly-created entity that hasn't been networked yet
			waiting_list[ent_id] = new_dims
			-- give it a second, otherwise... WTF?
			timer.Simple(1, function()
				if waiting_list[ent_id] then
					ErrorNoHalt("Effect Resizer: entity expected but it never came!")
					waiting_list[ent_id] = nil
				end
			end)
		end
	end)

	--[[-------------------------------------------------------------------------
	Check new entities for waiting list, or for NW2Vector
	---------------------------------------------------------------------------]]
	hook.Add("OnEntityCreated", unique_name, function(ent)
		local id = ent:EntIndex()
		local new_dims = waiting_list[id]

		if new_dims then
			SetEffectDimensions(ent, new_dims)
			waiting_list[id] = nil
			return
		end

		-- Might have the NWVar:
		local dims = ent:GetNW2Vector(unique_name, 0)
		if dims ~= 0 then
			SetEffectDimensions(ent, dims)
		else
			-- NWVars can come after OnEntityCreated, so try again on the next think...
			timer.Simple(0, function()
				dims = ent:GetNW2Vector(unique_name, 0)
				if dims ~= 0 then SetEffectDimensions(ent, dims) end
			end)
		end
	end)
end -- CLIENT

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

	local dims = Vector(self:GetClientNumber("scalex"), self:GetClientNumber("scaley"), self:GetClientNumber("scalez"))

	SetDimensions(self:GetOwner(), effect, {dimensions = dims}, self:GetClientNumber("scale"))

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

	SetDimensions(self:GetOwner(), effect, {dimensions = Vector(1, 1, 1)}, 1)

	return true
end

--[[-------------------------------------------------------------------------
BuildCPanel
---------------------------------------------------------------------------]]
function TOOL.BuildCPanel(CPanel)
	CPanel:NumSlider("Scale: ", "effectresizer_scale", 0, 10)
	CPanel:NumSlider("X Scale: ", "effectresizer_scalex", 0, 1)
	CPanel:NumSlider("Y Scale: ", "effectresizer_scaley", 0, 1)
	CPanel:NumSlider("Z Scale: ", "effectresizer_scalez", 0, 1)
end
