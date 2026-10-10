--!strict
-- The Freakpedia (Config/Freakpedia): records each new species-and-rarity a
-- player catches, pays the discovery reward, and announces new entries and
-- completed ring pages. Catching code (FreakService, WheelService) calls
-- record() for every newly caught freak. The farm income bonus itself is
-- applied by FarmService (Formulas.collectionMultiplier).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Formulas = require(Shared.Formulas)
local Format = require(Shared.Format)
local Remotes = require(Shared.Remotes)
local Freakpedia = require(Shared.Config.Freakpedia)
local DataService = require(script.Parent.DataService)

local FreakpediaService = {}

function FreakpediaService.record(player: Player, freak: { species: string, tier: number, rarity: string })
	local data = DataService.get(player)
	if not data then
		return
	end
	local pagesBefore = Formulas.freakpediaProgress(data.freakpedia)
	if not DataService.discover(player, freak.species, freak.rarity) then
		return
	end
	local reward = math.floor(Freakpedia.discoveryReward * Formulas.sellPrice(freak.tier, freak.rarity))
	DataService.addMoney(player, reward)
	Remotes.Notify:FireClient(player, ("New Freakpedia entry: %s %s!  +%s"):format(freak.rarity, freak.species, Format.money(reward)))

	for _, tier in Formulas.freakpediaProgress(data.freakpedia) do
		if table.find(pagesBefore, tier) then
			continue
		end
		Remotes.Popup:FireClient(
			player,
			"Freakpedia page complete!",
			("You've caught every Ring %d freak at every rarity from Common to Legendary. Your Freakpedia farm income bonus is now +%d%%, for good."):format(
				tier,
				math.round((Formulas.collectionMultiplier(data.freakpedia) - 1) * 100)
			)
		)
	end
end

return FreakpediaService
