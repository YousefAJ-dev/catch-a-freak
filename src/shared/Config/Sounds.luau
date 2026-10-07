--!strict
-- Sound effects (DESIGN.md section 13, Milestone 10). Public Creator Store
-- audio; Roblox's licensed libraries (ProSoundEffects, APM) where they had a
-- match. Played on the client by Sfx and SoundController.

export type Sound = { id: string, volume: number }

local Sounds: { [string]: Sound } = {
	grab = { id = "rbxassetid://140323850218372", volume = 0.6 }, -- a freak lands in the carry bar
	money = { id = "rbxassetid://121518193382221", volume = 0.45 }, -- selling, collecting, prizes
	spend = { id = "rbxassetid://1169806635", volume = 0.4 }, -- buying an upgrade or item
	click = { id = "rbxassetid://88442833509532", volume = 0.35 }, -- UI buttons
	dash = { id = "rbxassetid://137081214744553", volume = 0.6 },
	net = { id = "rbxassetid://138890894929151", volume = 0.6 },
	trap = { id = "rbxassetid://9116723292", volume = 0.5 },
	wheelWin = { id = "rbxassetid://1840076509", volume = 0.5 },
	radiation = { id = "rbxassetid://17541330396", volume = 0.12 }, -- looping in a ring; louder further out
}

return Sounds
