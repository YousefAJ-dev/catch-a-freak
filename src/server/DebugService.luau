--!strict
-- Studio-only playtest commands, typed in chat (DESIGN.md section 12):
--   /tier <1-3>               set your highest unlocked tier
--   /upgrade <id> <level>     set an upgrade level (shoes, hazmat, grip, farmCapacity, offlineCapacity)
--   /spawnfreak <tier> <rarity> [species]  spawn a freak in front of you,
--                             e.g. /spawnfreak 2 Epic or /spawnfreak 1 Rare Glowbug
--   /money <amount>           set your money
--   /item <id> <count>        set an item count (netLauncher, bearTrap)
--   /offline <seconds>        pay out offline earnings as if you'd been away that long
--   /wipe                     reset your saved data to a new player's and kick you
--   /wheel reset              make today's free wheel spin available again
--   /wheel spins <count>      set your extra wheel spins
-- Results print to the Output window.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TextChatService = game:GetService("TextChatService")

local DataService = require(script.Parent.DataService)
local FreakService = require(script.Parent.FreakService)
local FarmService = require(script.Parent.FarmService)
local WheelService = require(script.Parent.WheelService)

type Command = {
	alias: string,
	usage: string,
	run: (player: Player, args: { string }) -> string,
}

local commands: { Command } = {
	{
		alias = "/tier",
		usage = "/tier <1-3>",
		run = function(player, args)
			local tier = tonumber(args[1])
			assert(tier, "missing tier number")
			DataService.setHighestTier(player, tier)
			return ("highest tier = %d"):format(player:GetAttribute("HighestTier"))
		end,
	},
	{
		alias = "/upgrade",
		usage = "/upgrade <id> <level>",
		run = function(player, args)
			local id, level = args[1], tonumber(args[2])
			assert(id and level, "expected an upgrade id and a level")
			DataService.setUpgradeLevel(player, id, level)
			return ("%s = %d"):format(id, player:GetAttribute("Upgrade_" .. id))
		end,
	},
	{
		alias = "/offline",
		usage = "/offline <seconds>",
		run = function(player, args)
			local seconds = tonumber(args[1])
			assert(seconds, "missing seconds")
			return ("offline earnings for %d s = %d"):format(seconds, FarmService.applyOfflineEarnings(player, seconds))
		end,
	},
	{
		alias = "/wheel",
		usage = "/wheel reset | /wheel spins <count>",
		run = function(player, args)
			if args[1] == "reset" then
				WheelService.resetFreeSpin(player)
				return "free spin available again"
			end
			local count = tonumber(args[2])
			assert(args[1] == "spins" and count, "expected 'reset' or 'spins <count>'")
			WheelService.setExtraSpins(player, count)
			return ("extra spins = %d"):format(count)
		end,
	},
	{
		alias = "/wipe",
		usage = "/wipe",
		run = function(player)
			DataService.wipe(player)
			task.defer(function()
				player:Kick("Your data was wiped (Studio debug). Start a new playtest.")
			end)
			return "data wiped"
		end,
	},
	{
		alias = "/item",
		usage = "/item <id> <count>",
		run = function(player, args)
			local id, count = args[1], tonumber(args[2])
			assert(id and count, "expected an item id and a count")
			DataService.setItemCount(player, id, count)
			return ("%s = %d"):format(id, player:GetAttribute("Item_" .. id))
		end,
	},
	{
		alias = "/money",
		usage = "/money <amount>",
		run = function(player, args)
			local amount = tonumber(args[1])
			assert(amount, "missing amount")
			DataService.setMoney(player, amount)
			return ("money = %d"):format(player:GetAttribute("Money"))
		end,
	},
	{
		alias = "/spawnfreak",
		usage = "/spawnfreak <tier> <rarity> [species]",
		run = function(player, args)
			local tier, rarity = tonumber(args[1]), args[2]
			assert(tier and rarity, "expected a tier and a rarity")
			-- Accept any capitalisation: "epic" -> "Epic".
			rarity = rarity:sub(1, 1):upper() .. rarity:sub(2):lower()
			return "spawned " .. FreakService.spawnNear(player, tier, rarity, args[3])
		end,
	},
}

local DebugService = {}

function DebugService.start()
	if not RunService:IsStudio() then
		return
	end
	for _, command in commands do
		local chatCommand = Instance.new("TextChatCommand")
		chatCommand.Name = "Debug" .. command.alias
		chatCommand.PrimaryAlias = command.alias
		chatCommand.Triggered:Connect(function(source: TextSource, text: string)
			local player = Players:GetPlayerByUserId(source.UserId)
			if not player then
				return
			end
			local args = string.split(text, " ")
			table.remove(args, 1)
			local ok, result = pcall(command.run, player, args)
			if ok then
				print(("[Debug] %s: %s"):format(player.Name, result))
			else
				warn(("[Debug] %s failed (%s). Usage: %s"):format(command.alias, tostring(result), command.usage))
			end
		end)
		chatCommand.Parent = TextChatService
	end
end

return DebugService
