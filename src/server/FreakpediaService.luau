--!strict
-- The Freakpedia (Config/Freakpedia). A species at a rarity becomes a new
-- entry when the player puts it in an incubator (FarmService calls
-- discover()); catching alone isn't enough. New entries wait in the book, and
-- the player claims them by clicking the species' card (Remotes
-- ClaimFreakpedia), which pays the discovery reward and counts them toward
-- pages. Completed pages are announced on claim. The farm income bonus itself
-- is applied by FarmService (Formulas.collectionMultiplier over claimed entries).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Formulas = require(Shared.Formulas)
local Format = require(Shared.Format)
local Remotes = require(Shared.Remotes)
local Freakpedia = require(Shared.Config.Freakpedia)
local FreakConfig = require(Shared.Config.Freaks)
local DataService = require(script.Parent.DataService)

local FreakpediaService = {}

local tierOf: { [string]: number } = {}
for tier, list in FreakConfig.species do
	for _, species in list do
		tierOf[species.name] = tier
	end
end

function FreakpediaService.discover(player: Player, freak: { species: string, rarity: string })
	if DataService.get(player) and DataService.addPendingEntry(player, freak.species, freak.rarity) then
		-- The Freakpedia button's red badge counts entries waiting to be claimed.
		Remotes.FloatText:FireClient(player, "📖 New Freakpedia entry!", Color3.fromRGB(170, 235, 80))
	end
end

local function onClaim(player: Player, species: any)
	local data = DataService.get(player)
	if not data or typeof(species) ~= "string" or not tierOf[species] then
		return
	end
	local pagesBefore = Formulas.freakpediaProgress(data.freakpedia)
	local claimed = DataService.claimEntries(player, species)
	if #claimed == 0 then
		return
	end
	local reward = 0
	for _, rarity in claimed do
		reward += math.floor(Freakpedia.discoveryReward * Formulas.sellPrice(tierOf[species], rarity))
	end
	DataService.addMoney(player, reward)
	Remotes.FloatText:FireClient(player, ("📖 +%s"):format(Format.money(reward)), Color3.fromRGB(170, 235, 80))

	for _, tier in Formulas.freakpediaProgress(data.freakpedia) do
		if table.find(pagesBefore, tier) then
			continue
		end
		Remotes.Popup:FireClient(
			player,
			"Freakpedia page complete!",
			("You've collected every Ring %d freak at every rarity from Common to Legendary. Your Freakpedia farm income bonus is now +%d%%, for good."):format(
				tier,
				math.round((Formulas.collectionMultiplier(data.freakpedia) - 1) * 100)
			)
		)
	end
end

function FreakpediaService.start()
	Remotes.ClaimFreakpedia.OnServerEvent:Connect(onClaim)
end

return FreakpediaService
