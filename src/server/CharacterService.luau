--!strict
-- Applies player stats to their character: max health on spawn, walk speed
-- from the Shoes upgrade on spawn and whenever the upgrade changes, the dash
-- cooldown, and the equipped skin set's look (DESIGN.md section 10).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Formulas = require(ReplicatedStorage.Shared.Formulas)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local PlayerConfig = require(ReplicatedStorage.Shared.Config.Player)
local Products = require(ReplicatedStorage.Shared.Config.Products)
local DataService = require(script.Parent.DataService)

local CharacterService = {}

local function applyWalkSpeed(player: Player)
	local data = DataService.get(player)
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if data and humanoid then
		humanoid.WalkSpeed = Formulas.walkSpeed(data.upgrades.shoes)
	end
end

-- Skins -------------------------------------------------------------------
-- A skin recolors the body parts and hides the avatar's 2D clothing (which
-- would paint over the suit). Each part's own color and material are kept in
-- attributes, and the clothing in a folder, so taking the skin off restores
-- the avatar exactly.

local SUIT_PARTS = {
	-- R15
	"UpperTorso", "LowerTorso", "LeftUpperArm", "LeftLowerArm", "LeftHand", "RightUpperArm", "RightLowerArm", "RightHand",
	"LeftUpperLeg", "LeftLowerLeg", "RightUpperLeg", "RightLowerLeg",
	-- R6
	"Torso", "Left Arm", "Right Arm", "Left Leg", "Right Leg",
}
local BOOT_PARTS = { "LeftFoot", "RightFoot" }
local CLOTHING = { Shirt = true, Pants = true, ShirtGraphic = true }

local function dress(part: BasePart, surface: { color: Color3, material: Enum.Material }?)
	if part:GetAttribute("SkinOriginalColor") == nil then
		part:SetAttribute("SkinOriginalColor", part.Color)
		part:SetAttribute("SkinOriginalMaterial", part.Material.Name)
	end
	if surface then
		part.Color = surface.color
		part.Material = surface.material
	else
		part.Color = part:GetAttribute("SkinOriginalColor") :: Color3
		part.Material = (Enum.Material :: any)[part:GetAttribute("SkinOriginalMaterial") :: string]
	end
end

local function applySkin(player: Player)
	local character = player.Character
	if not character then
		return
	end
	local key = player:GetAttribute("EquippedSkin")
	local look: Products.SkinLook? = nil
	for _, skin in Products.skinSets do
		if skin.key == key then
			look = skin.look
		end
	end

	for _, name in SUIT_PARTS do
		local part = character:FindFirstChild(name)
		if part and part:IsA("BasePart") then
			dress(part, look and look.suit)
		end
	end
	for _, name in BOOT_PARTS do
		local part = character:FindFirstChild(name)
		if part and part:IsA("BasePart") then
			dress(part, look and look.boots)
		end
	end

	local stash = character:FindFirstChild("SkinStash") or Instance.new("Folder")
	stash.Name = "SkinStash"
	stash.Parent = character
	for _, child in (if look then character else stash):GetChildren() do
		if CLOTHING[child.ClassName] then
			child.Parent = if look then stash else character
		end
	end

	for _, name in { "SkinGoggles", "SkinGlow" } do
		local old = character:FindFirstChild(name, true)
		if old then
			old:Destroy()
		end
	end
	local head = character:FindFirstChild("Head") :: BasePart?
	if look and look.goggles and head then
		local goggles = Instance.new("Part")
		goggles.Name = "SkinGoggles"
		goggles.Size = Vector3.new(head.Size.X * 1.05, head.Size.Y * 0.28, head.Size.Z * 1.05)
		goggles.CFrame = head.CFrame * CFrame.new(0, head.Size.Y * 0.12, 0)
		goggles.Color = look.goggles
		goggles.Material = Enum.Material.Glass
		goggles.Transparency = 0.25
		goggles.CanCollide = false
		goggles.CanQuery = false
		goggles.CanTouch = false
		goggles.Massless = true
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = goggles
		weld.Part1 = head
		weld.Parent = goggles
		goggles.Parent = character
	end
	local chest = (character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso")) :: BasePart?
	if look and look.glow and chest then
		local glow = Instance.new("PointLight")
		glow.Name = "SkinGlow"
		glow.Color = look.glow
		glow.Range = 10
		glow.Brightness = 1.2
		glow.Parent = chest
	end
end

local function onCharacterAdded(player: Player, character: Model)
	local humanoid = character:WaitForChild("Humanoid") :: Humanoid
	humanoid.MaxHealth = PlayerConfig.maxHealth
	humanoid.Health = PlayerConfig.maxHealth
	applyWalkSpeed(player)
	-- The avatar's clothing and parts load in after the character appears.
	if not player:HasAppearanceLoaded() then
		player.CharacterAppearanceLoaded:Wait()
	end
	if player.Character == character then
		applySkin(player)
	end
end

local function onPlayerAdded(player: Player)
	player.CharacterAdded:Connect(function(character)
		onCharacterAdded(player, character)
	end)
	player:GetAttributeChangedSignal("Upgrade_shoes"):Connect(function()
		applyWalkSpeed(player)
	end)
	player:GetAttributeChangedSignal("EquippedSkin"):Connect(function()
		applySkin(player)
	end)
	if player.Character then
		task.spawn(onCharacterAdded, player, player.Character)
	end
end

-- Dash: the client moves its own character (Roblox runs character physics on
-- the owning client), so the server's job is the cooldown. It accepts a dash
-- only from a player who owns it and whose cooldown has passed, and publishes
-- when the next one is ready as the "DashReadyAt" attribute (server time).
local DASH_TOLERANCE = 0.25 -- seconds of network jitter forgiven
local dashReadyAt: { [Player]: number } = {}

local function onDash(player: Player)
	local data = DataService.get(player)
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if not (data and humanoid) or humanoid.Health <= 0 or (data.upgrades.dash or 0) < 1 then
		return
	end
	local now = workspace:GetServerTimeNow()
	if now < (dashReadyAt[player] or 0) - DASH_TOLERANCE then
		return
	end
	local readyAt = now + Formulas.dashCooldown(data.upgrades.dashRecharge or 0)
	dashReadyAt[player] = readyAt
	player:SetAttribute("DashReadyAt", readyAt)
end

function CharacterService.start()
	Remotes.Dash.OnServerEvent:Connect(onDash)
	Players.PlayerRemoving:Connect(function(player)
		dashReadyAt[player] = nil
	end)
	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end
end

return CharacterService
