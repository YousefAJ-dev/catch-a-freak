--!strict
-- Plays one-shot sound effects from Config/Sounds on the local player only.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local Sounds = require(ReplicatedStorage.Shared.Config.Sounds)

local Sfx = {}

local templates: { [string]: Sound } = {}

local function template(name: string): Sound
	local existing = templates[name]
	if existing then
		return existing
	end
	local info = Sounds[name]
	assert(info, "unknown sound " .. name)
	local sound = Instance.new("Sound")
	sound.Name = name
	sound.SoundId = info.id
	sound.Volume = info.volume
	sound.Parent = SoundService
	templates[name] = sound
	return sound
end

function Sfx.play(name: string)
	-- PlayLocalSound plays a copy, so overlapping plays don't cut each other off.
	SoundService:PlayLocalSound(template(name))
end

-- Loads every sound up front so the first play isn't silent.
function Sfx.preload()
	for name in Sounds do
		template(name)
	end
end

return Sfx
