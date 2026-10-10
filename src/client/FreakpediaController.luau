--!strict
-- Freakpedia panel (DESIGN.md sections 5 and 11): the book button on the left
-- of the HUD (or P) opens it. One page per ring, picked with tabs; each
-- species shows its model (a black silhouette until it's been caught at any
-- rarity), its name ("???" until caught), and a pip per rarity, lit for the
-- rarities caught. The footer shows the page reward and the total bonus.
-- Discoveries and rewards are decided by the server (FreakpediaService); this
-- only displays the "Freakpedia" attribute.

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage.Shared
local Formulas = require(Shared.Formulas)
local FreakConfig = require(Shared.Config.Freaks)
local Freakpedia = require(Shared.Config.Freakpedia)
local Rarities = require(Shared.Config.Rarities)
local Release = require(Shared.Config.Release)
local UiKit = require(script.Parent.UiKit)
local Sfx = require(script.Parent.Sfx)

local player = Players.LocalPlayer

local CARD_WIDTH = 180
local CARD_HEIGHT = 250

local RAINBOW = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 60, 60)),
	ColorSequenceKeypoint.new(0.25, Color3.fromRGB(255, 220, 50)),
	ColorSequenceKeypoint.new(0.5, Color3.fromRGB(70, 230, 90)),
	ColorSequenceKeypoint.new(0.75, Color3.fromRGB(60, 150, 255)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(190, 80, 255)),
})

local FreakpediaController = {}

local function discovered(): { [string]: { string } }
	local ok, value = pcall(HttpService.JSONDecode, HttpService, (player:GetAttribute("Freakpedia") :: string?) or "{}")
	return if ok and typeof(value) == "table" then value else {}
end

local function totalEntries(): number
	local count = 0
	for _, list in FreakConfig.species do
		count += #list * #Rarities.list
	end
	return count
end

-- A ViewportFrame showing the species' mesh, lit normally or as a silhouette.
local function viewport(parent: Instance, species: any, known: boolean)
	local frame = UiKit.make("ViewportFrame", {
		Position = UDim2.fromOffset(8, 8),
		Size = UDim2.new(1, -16, 0, 140),
		BackgroundColor3 = Color3.fromRGB(28, 32, 38),
		Ambient = if known then Color3.fromRGB(170, 170, 170) else Color3.new(0, 0, 0),
		LightColor = if known then Color3.new(1, 1, 1) else Color3.new(0, 0, 0),
		LightDirection = Vector3.new(-1, -1, 1),
		Parent = parent,
	})
	UiKit.corner(frame, 8)
	local meshes = ReplicatedStorage:FindFirstChild("FreakMeshes")
	local template = meshes and meshes:FindFirstChild(species.name) :: BasePart?
	local body: BasePart
	if template then
		body = template:Clone()
	else
		body = UiKit.make("Part", { Shape = Enum.PartType.Ball, Size = species.size, Color = species.color })
	end
	body.Anchored = true
	body.CFrame = CFrame.new()
	if not known then
		body.Color = Color3.new(0, 0, 0)
		if body:IsA("MeshPart") then
			body.TextureID = ""
		end
	end
	body.Parent = frame
	-- Three-quarter view from the front (freaks face -Z), far enough to fit.
	local size = body.Size
	local reach = math.max(size.X, size.Y, size.Z)
	local camera = Instance.new("Camera")
	camera.FieldOfView = 40
	local eye = CFrame.Angles(0, math.rad(-25), 0) * Vector3.new(0, size.Y * 0.25, -reach * 1.75)
	camera.CFrame = CFrame.lookAt(eye, Vector3.new(0, 0, 0))
	camera.Parent = frame
	frame.CurrentCamera = camera
end

local function pip(parent: Instance, order: number, rarity: any, caught: boolean)
	local dot = UiKit.make("Frame", {
		LayoutOrder = order,
		Size = UDim2.fromOffset(16, 16),
		BackgroundColor3 = if caught then rarity.color else Color3.fromRGB(45, 49, 57),
		Parent = parent,
	})
	UiKit.corner(dot, 8)
	UiKit.make("UIStroke", {
		Color = rarity.color,
		Thickness = 1.5,
		Transparency = if caught then 0 else 0.55,
		Parent = dot,
	})
	if caught and rarity.rainbow then
		dot.BackgroundColor3 = Color3.new(1, 1, 1)
		UiKit.make("UIGradient", { Color = RAINBOW, Parent = dot })
	end
end

function FreakpediaController.start()
	local gui = UiKit.make("ScreenGui", { Name = "Freakpedia", ResetOnSpawn = false, Enabled = false })
	local frame = UiKit.make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(CARD_WIDTH * 3 + 56, CARD_HEIGHT + 190),
		BackgroundColor3 = UiKit.colors.panel,
		BackgroundTransparency = 0.05,
		Parent = gui,
	})
	UiKit.corner(frame, 12)
	UiKit.make("UIStroke", { Color = UiKit.accents.freakpedia, Thickness = 3, Parent = frame })
	UiKit.make("TextLabel", {
		Position = UDim2.fromOffset(16, 10),
		Size = UDim2.new(1, -60, 0, 30),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBlack,
		TextSize = 26,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = UiKit.colors.text,
		Text = "Freakpedia",
		Parent = frame,
	})
	local count = UiKit.make("TextLabel", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -48, 0, 14),
		Size = UDim2.fromOffset(200, 22),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBold,
		TextSize = 14,
		TextXAlignment = Enum.TextXAlignment.Right,
		TextColor3 = UiKit.colors.muted,
		Text = "",
		Parent = frame,
	})
	local close = UiKit.make("TextButton", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -10, 0, 10),
		Size = UDim2.fromOffset(28, 28),
		BackgroundColor3 = UiKit.colors.row,
		Font = Enum.Font.GothamBlack,
		TextSize = 16,
		TextColor3 = UiKit.colors.muted,
		Text = "X",
		Parent = frame,
	})
	UiKit.corner(close, 6)

	local tabBar = UiKit.make("Frame", {
		Position = UDim2.fromOffset(16, 46),
		Size = UDim2.new(1, -32, 0, 30),
		BackgroundTransparency = 1,
		Parent = frame,
	})
	UiKit.make("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6), Parent = tabBar })

	local cards = UiKit.make("Frame", {
		Position = UDim2.fromOffset(16, 88),
		Size = UDim2.new(1, -32, 0, CARD_HEIGHT),
		BackgroundTransparency = 1,
		Parent = frame,
	})
	UiKit.make("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		Padding = UDim.new(0, 12),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = cards,
	})

	local function footerLine(y: number, font: Enum.Font, color: Color3): TextLabel
		return UiKit.make("TextLabel", {
			Position = UDim2.new(0, 16, 1, y),
			Size = UDim2.new(1, -32, 0, 20),
			BackgroundTransparency = 1,
			Font = font,
			TextSize = 14,
			TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = color,
			Text = "",
			Parent = frame,
		})
	end
	local pageLine = footerLine(-84, Enum.Font.GothamBold, UiKit.colors.text)
	local bonusLine = footerLine(-58, Enum.Font.GothamBold, UiKit.colors.money)
	local hintLine = footerLine(-34, Enum.Font.Gotham, UiKit.colors.muted)
	hintLine.Text = ("Every new entry pays its sell price. Each %s or %s entry adds +%d%% farm income."):format(
		Freakpedia.shinyRarities[1],
		Freakpedia.shinyRarities[2],
		math.round(Freakpedia.shinyBonus * 100)
	)

	local tierCount = #FreakConfig.species
	local page = 1
	local tabButtons: { TextButton } = {}

	local function render()
		if not gui.Enabled then
			return
		end
		local caughtBySpecies = discovered()
		local pages = Formulas.freakpediaProgress(caughtBySpecies)
		local highest = (player:GetAttribute("HighestTier") :: number?) or 1

		local entries = 0
		for _, list in caughtBySpecies do
			entries += #list
		end
		count.Text = ("%d / %d entries"):format(entries, totalEntries())

		for tier, button in tabButtons do
			button.BackgroundColor3 = if tier == page then UiKit.colors.action else UiKit.colors.row
			local locked = tier > math.min(highest, Release.releasedTiers)
			button.Text = ("Ring %d%s"):format(tier, if table.find(pages, tier) then " ✓" elseif locked then " 🔒" else "")
		end

		UiKit.clear(cards)
		for i, species in FreakConfig.species[page] do
			local caught = caughtBySpecies[species.name] or {}
			local known = #caught > 0
			local card = UiKit.make("Frame", {
				LayoutOrder = i,
				Size = UDim2.fromOffset(CARD_WIDTH, CARD_HEIGHT),
				BackgroundColor3 = UiKit.colors.row,
				Parent = cards,
			})
			UiKit.corner(card, 10)
			viewport(card, species, known)
			UiKit.make("TextLabel", {
				Position = UDim2.fromOffset(8, 154),
				Size = UDim2.new(1, -16, 0, 24),
				BackgroundTransparency = 1,
				Font = Enum.Font.GothamBlack,
				TextSize = 18,
				TextColor3 = if known then UiKit.colors.text else UiKit.colors.muted,
				Text = if known then species.name else "???",
				Parent = card,
			})
			local pips = UiKit.make("Frame", {
				Position = UDim2.fromOffset(8, 186),
				Size = UDim2.new(1, -16, 0, 16),
				BackgroundTransparency = 1,
				Parent = card,
			})
			UiKit.make("UIListLayout", {
				FillDirection = Enum.FillDirection.Horizontal,
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
				Padding = UDim.new(0, 6),
				SortOrder = Enum.SortOrder.LayoutOrder,
				Parent = pips,
			})
			for order, rarity in Rarities.list do
				pip(pips, order, rarity, table.find(caught, rarity.id) ~= nil)
			end
			UiKit.make("TextLabel", {
				Position = UDim2.fromOffset(8, 210),
				Size = UDim2.new(1, -16, 0, 30),
				BackgroundTransparency = 1,
				Font = Enum.Font.Gotham,
				TextSize = 13,
				TextWrapped = true,
				TextColor3 = UiKit.colors.muted,
				Text = if known then ("%d / %d rarities caught"):format(#caught, #Rarities.list) else ("Lives in Ring %d"):format(page),
				Parent = card,
			})
		end

		local pagePercent = math.round(Freakpedia.pageBonus * 100)
		pageLine.Text = if table.find(pages, page)
			then ("Ring %d page complete: +%d%% farm income"):format(page, pagePercent)
			else ("Catch all %d at %s–%s to complete this page: +%d%% farm income"):format(
				#FreakConfig.species[page],
				Freakpedia.pageRarities[1],
				Freakpedia.pageRarities[#Freakpedia.pageRarities],
				pagePercent
			)
		pageLine.TextColor3 = if table.find(pages, page) then UiKit.colors.money else UiKit.colors.text
		bonusLine.Text = ("Freakpedia farm income bonus: +%d%%   ·   Pages complete: %d / %d"):format(
			math.round((Formulas.collectionMultiplier(caughtBySpecies) - 1) * 100),
			#pages,
			tierCount
		)
	end

	for tier = 1, tierCount do
		local button = UiKit.make("TextButton", {
			Size = UDim2.new(1 / tierCount, -5, 1, 0),
			BackgroundColor3 = UiKit.colors.row,
			Font = Enum.Font.GothamBold,
			TextSize = 14,
			TextColor3 = UiKit.colors.text,
			Text = "Ring " .. tier,
			Parent = tabBar,
		})
		UiKit.corner(button, 6)
		button.Activated:Connect(function()
			Sfx.play("click")
			page = tier
			render()
		end)
		tabButtons[tier] = button
	end

	local function setOpen(open: boolean)
		if open and not gui.Enabled then
			-- Open on the player's newest ring.
			page = math.clamp((player:GetAttribute("HighestTier") :: number?) or 1, 1, tierCount)
		end
		gui.Enabled = open
		render()
	end

	close.Activated:Connect(function()
		Sfx.play("click")
		setOpen(false)
	end)

	-- The book button, on the left edge of the screen.
	local hud = UiKit.make("ScreenGui", { Name = "FreakpediaButton", ResetOnSpawn = false })
	local button = UiKit.make("TextButton", {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 16, 0.5, 0),
		Size = UDim2.fromOffset(160, 48),
		BackgroundColor3 = Color3.fromRGB(25, 28, 34),
		BackgroundTransparency = 0.1,
		Font = Enum.Font.GothamBlack,
		TextSize = 18,
		TextColor3 = UiKit.colors.text,
		Text = "📖 Freakpedia",
		Parent = hud,
	})
	UiKit.corner(button, 12)
	UiKit.make("UIStroke", { Color = UiKit.accents.freakpedia, Thickness = 2.5, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = button })
	button.Activated:Connect(function()
		Sfx.play("click")
		setOpen(not gui.Enabled)
	end)

	UserInputService.InputBegan:Connect(function(input, processed)
		if not processed and input.KeyCode == Enum.KeyCode.P then
			setOpen(not gui.Enabled)
		end
	end)

	player:GetAttributeChangedSignal("Freakpedia"):Connect(render)
	player:GetAttributeChangedSignal("HighestTier"):Connect(render)

	hud.Parent = player:WaitForChild("PlayerGui")
	gui.Parent = player:WaitForChild("PlayerGui")
end

return FreakpediaController
