--!strict
-- Feedback that follows the player's state rather than a button press: a pop
-- and a sparkle burst when a freak lands in the carry bar, a cash sound and a
-- gold burst when money goes up, a coin when it's spent, and a geiger counter
-- ticking while in a ring, louder and faster in outer rings. Button, dash,
-- item and wheel sounds are played where those happen (Sfx).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local SoundService = game:GetService("SoundService")

local Sounds = require(ReplicatedStorage.Shared.Config.Sounds)
local Sfx = require(script.Parent.Sfx)

local player = Players.LocalPlayer

local FeedbackController = {}

local function carried(): number
	local ok, slots = pcall(HttpService.JSONDecode, HttpService, (player:GetAttribute("Carry") :: string?) or "[]")
	local count = 0
	for _, slot in if ok then slots else {} do
		if slot ~= false then
			count += 1
		end
	end
	return count
end

-- A short burst of sparkles around the character.
local function burst(color: Color3, count: number)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return
	end
	local attachment = Instance.new("Attachment")
	attachment.Parent = root
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	emitter.Color = ColorSequence.new(color)
	emitter.LightEmission = 0.8
	emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 0) })
	emitter.Lifetime = NumberRange.new(0.5, 0.9)
	emitter.Speed = NumberRange.new(6, 12)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Acceleration = Vector3.new(0, -10, 0)
	emitter.Rate = 0
	emitter.Parent = attachment
	emitter:Emit(count)
	task.delay(1.5, function()
		attachment:Destroy()
	end)
end

function FeedbackController.start()
	Sfx.preload()

	local lastCarried = carried()
	player:GetAttributeChangedSignal("Carry"):Connect(function()
		local now = carried()
		if now > lastCarried then
			Sfx.play("grab")
			burst(Color3.fromRGB(140, 255, 120), 24)
		end
		lastCarried = now
	end)

	local lastMoney = (player:GetAttribute("Money") :: number?) or 0
	player:GetAttributeChangedSignal("Money"):Connect(function()
		local now = (player:GetAttribute("Money") :: number?) or 0
		if now > lastMoney then
			Sfx.play("money")
			burst(Color3.fromRGB(255, 215, 80), 30)
		elseif now < lastMoney then
			Sfx.play("spend")
		end
		lastMoney = now
	end)

	local geiger = Instance.new("Sound")
	geiger.Name = "Geiger"
	geiger.SoundId = Sounds.radiation.id
	geiger.Looped = true
	geiger.Parent = SoundService
	local function updateGeiger()
		local tier = (player:GetAttribute("ZoneTier") :: number?) or 0
		if tier > 0 then
			geiger.Volume = Sounds.radiation.volume * (1 + 0.35 * (tier - 1))
			geiger.PlaybackSpeed = 1 + 0.08 * (tier - 1)
			if not geiger.IsPlaying then
				geiger:Play()
			end
		else
			geiger:Stop()
		end
	end
	player:GetAttributeChangedSignal("ZoneTier"):Connect(updateGeiger)
	updateGeiger()
end

return FeedbackController
