--!strict
-- Studio-only playtest commands, typed in chat (DESIGN.md section 12):
--   /tier <1-5>               set your highest unlocked tier
--   /progress                 your play time, and when you reached each tier
--   /upgrade <id> <level>     set an upgrade level (shoes, hazmat, grip, farmCapacity, offlineCapacity)
--   /spawnfreak <tier> <rarity> [species]  spawn a freak in front of you,
--                             e.g. /spawnfreak 2 Epic or /spawnfreak 1 Rare Glowbug
--   /money <amount>           set your money
--   /item <id> <count>        set an item count (netLauncher, bearTrap, goldenTrap)
--   /offline <seconds>        pay out offline earnings as if you'd been away that long
--   /wipe                     reset your saved data to a new player's and kick you
--   /wheel reset              make today's free wheel spin available again
--   /wheel spins <count>      set your extra wheel spins
--   /buy <goldenTrap|extraSpin|revive> [purchaseId]  simulate a Developer Product
--                             purchase through the real receipt handler; reuse a
--                             purchaseId to replay a receipt
--   /buyskin <key>            simulate buying a skin set Game Pass
--   /buypass <key>            simulate buying a gameplay Game Pass (money2x)
--   /policy restricted|open   pretend paid random items are (not) restricted
--   /freeaccess on|off        turn free access (Config/FreeAccess) on or off for this session
--   /time <day|dusk|night|dawn>  jump the day/night cycle to that phase, for everyone
-- Results print to the Output window.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TextChatService = game:GetService("TextChatService")

local DataService = require(script.Parent.DataService)
local FreakService = require(script.Parent.FreakService)
local FarmService = require(script.Parent.FarmService)
local WheelService = require(script.Parent.WheelService)
local MonetizationService = require(script.Parent.MonetizationService)
local DayNight = require(game:GetService("ReplicatedStorage").Shared.Config.DayNight)

type Command = {
	alias: string,
	usage: string,
	run: (player: Player, args: { string }) -> string,
}

local commands: { Command } = {
	{
		alias = "/tier",
		usage = "/tier <1-5>",
		run = function(player, args)
			local tier = tonumber(args[1])
			assert(tier, "missing tier number")
			DataService.setHighestTier(player, tier)
			return ("highest tier = %d"):format(player:GetAttribute("HighestTier"))
		end,
	},
	{
		alias = "/progress",
		usage = "/progress",
		run = function(player)
			local played, reached = DataService.progress(player)
			local lines = { ("played %.0f min"):format(played / 60) }
			for tier = 2, 10 do
				local at = reached[tostring(tier)]
				local before = reached[tostring(tier - 1)]
				if at then
					table.insert(lines, ("tier %d at %.0f min%s"):format(tier, at / 60, if before then (" (Ring %d took %.0f min)"):format(tier - 1, (at - before) / 60) else ""))
				end
			end
			return table.concat(lines, "; ")
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
		alias = "/buy",
		usage = "/buy <goldenTrap|extraSpin|revive> [purchaseId]",
		run = function(player, args)
			assert(args[1], "expected a product key")
			return MonetizationService.simulatePurchase(player, args[1], args[2])
		end,
	},
	{
		alias = "/buyskin",
		usage = "/buyskin <key>",
		run = function(player, args)
			assert(args[1], "expected a skin key")
			return MonetizationService.simulateSkinPurchase(player, args[1])
		end,
	},
	{
		alias = "/buypass",
		usage = "/buypass <key>",
		run = function(player, args)
			assert(args[1], "expected a pass key")
			return MonetizationService.simulatePassPurchase(player, args[1])
		end,
	},
	{
		alias = "/freeaccess",
		usage = "/freeaccess on|off",
		run = function(player, args)
			assert(args[1] == "on" or args[1] == "off", "expected on or off")
			MonetizationService.setFreeAccess(player, args[1] == "on")
			return "FreeAccess = " .. tostring(args[1] == "on")
		end,
	},
	{
		alias = "/touchmode",
		usage = "/touchmode on|off",
		run = function(player, args)
			assert(args[1] == "on" or args[1] == "off", "expected on or off")
			-- GrabController treats the player as on a touch device (Studio only).
			player:SetAttribute("DebugTouchMode", args[1] == "on")
			return "DebugTouchMode = " .. tostring(args[1] == "on")
		end,
	},
	{
		alias = "/policy",
		usage = "/policy restricted|open",
		run = function(player, args)
			assert(args[1] == "restricted" or args[1] == "open", "expected restricted or open")
			MonetizationService.setPolicyRestricted(player, args[1] == "restricted")
			return "PaidRandomItemsRestricted = " .. tostring(args[1] == "restricted")
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
	{
		alias = "/time",
		usage = "/time <day|dusk|night|dawn>",
		run = function(_, args)
			-- Shifts the shared clock (BiomeController adds DayNightOffset).
			local phases = { "day", "dusk", "night", "dawn" }
			local lengths = { DayNight.daySeconds, DayNight.duskSeconds, DayNight.nightSeconds, DayNight.dawnSeconds }
			local index = table.find(phases, (args[1] or ""):lower())
			assert(index, "unknown phase")
			local start, cycle = 0, 0
			for i, length in lengths do
				if i < index then
					start += length
				end
				cycle += length
			end
			workspace:SetAttribute("DayNightOffset", start - workspace:GetServerTimeNow() % cycle)
			return "time = " .. phases[index]
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
