--!strict
-- Freakpedia panel (DESIGN.md sections 5 and 11): the book button on the left
-- of the HUD (or P) opens it. One page per ring, picked with tabs; each
-- species shows its model (a black silhouette until it's been collected at
-- any rarity), its name ("???" until then), and a pip per rarity, lit for the
-- rarities collected. The footer shows the page reward and the total bonus.
--
-- A freak becomes a new entry once it's put in an incubator. New entries wait
-- on their species' card (a half-lit pip and a CLAIM button that pays the
-- reward); the red badge on the book button counts them, and each ring tab
-- shows how many it has. A "P" keycap on the button shows the shortcut
-- (keyboards only). The panel can be dragged around by its title bar and stays
-- where it's put.
-- Discoveries and rewards are decided by the server (FreakpediaService); this
-- only displays the "Freakpedia" and "FreakpediaPending" attributes.

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage.Shared
local Formulas = require(Shared.Formulas)
local Format = require(Shared.Format)
local Remotes = require(Shared.Remotes)
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

local tierOf: { [string]: number } = {}
for tier, list in FreakConfig.species do
	for _, species in list do
		tierOf[species.name] = tier
	end
end

local function decodeBook(attribute: string): { [string]: { string } }
	local ok, value = pcall(HttpService.JSONDecode, HttpService, (player:GetAttribute(attribute) :: string?) or "{}")
	return if ok and typeof(value) == "table" then value else {}
end

-- Claimed entries: species -> rarities.
local function discovered(): { [string]: { string } }
	return decodeBook("Freakpedia")
end

-- Entries in an incubator but not claimed yet.
local function pendingEntries(): { [string]: { string } }
	return decodeBook("FreakpediaPending")
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

-- A rarity pip: lit when claimed, half-lit when waiting to be claimed.
local function pip(parent: Instance, order: number, rarity: any, caught: boolean, pending: boolean)
	local dot = UiKit.make("Frame", {
		LayoutOrder = order,
		Size = UDim2.fromOffset(16, 16),
		BackgroundColor3 = if caught or pending then rarity.color else Color3.fromRGB(45, 49, 57),
		BackgroundTransparency = if pending then 0.55 else 0,
		Parent = parent,
	})
	UiKit.corner(dot, 8)
	UiKit.make("UIStroke", {
		Color = rarity.color,
		Thickness = 1.5,
		Transparency = if caught or pending then 0 else 0.55,
		Parent = dot,
	})
	if (caught or pending) and rarity.rainbow then
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

	-- Drag the panel by its title bar (everything above the tabs except the X).
	local handle = UiKit.make("Frame", {
		Name = "DragHandle",
		Size = UDim2.new(1, -48, 0, 44),
		BackgroundTransparency = 1,
		Active = true,
		ZIndex = 5,
		Parent = frame,
	})
	local dragging: InputObject? = nil
	local dragStart = Vector2.zero
	local centerStart = Vector2.zero
	handle.InputBegan:Connect(function(input)
		local kind = input.UserInputType
		if kind ~= Enum.UserInputType.MouseButton1 and kind ~= Enum.UserInputType.Touch then
			return
		end
		dragging = input
		dragStart = Vector2.new(input.Position.X, input.Position.Y)
		centerStart = frame.AbsolutePosition + frame.AbsoluteSize / 2
		local ended
		ended = input.Changed:Connect(function()
			if input.UserInputState == Enum.UserInputState.End then
				dragging = nil
				ended:Disconnect()
			end
		end)
	end)
	UserInputService.InputChanged:Connect(function(input)
		if not dragging then
			return
		end
		local moved = input.UserInputType == Enum.UserInputType.MouseMovement
			or (input.UserInputType == Enum.UserInputType.Touch and input == dragging)
		if not moved then
			return
		end
		-- Work in screen pixels, keep the title bar on screen, then convert back
		-- to an offset from the screen's center (undoing any UI scaling).
		local screen = gui.AbsoluteSize
		local size = frame.AbsoluteSize
		local center = centerStart + Vector2.new(input.Position.X, input.Position.Y) - dragStart
		center = Vector2.new(
			math.clamp(center.X, 40 - size.X / 2, screen.X - 40 + size.X / 2),
			math.clamp(center.Y, size.Y / 2, screen.Y - 44 + size.Y / 2)
		)
		local scale = size.X / frame.Size.X.Offset
		local offset = (center - screen / 2) / scale
		frame.Position = UDim2.new(0.5, offset.X, 0.5, offset.Y)
	end)

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
	hintLine.Text = ("Put a new freak in an incubator, then CLAIM it here for its sell price. Each %s or %s entry adds +%d%%."):format(
		Freakpedia.shinyRarities[1],
		Freakpedia.shinyRarities[2],
		math.round(Freakpedia.shinyBonus * 100)
	)

	local tierCount = #FreakConfig.species
	local page = 1

	-- Entries waiting to be claimed, in one ring or (tier nil) all of them.
	local function pendingCount(tier: number?): number
		local entries = 0
		for name, list in pendingEntries() do
			if tierOf[name] and (tier == nil or tierOf[name] == tier) then
				entries += #list
			end
		end
		return entries
	end
	local tabButtons: { TextButton } = {}

	local function render()
		if not gui.Enabled then
			return
		end
		local caughtBySpecies = discovered()
		local pendingBySpecies = pendingEntries()
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
			local waiting = pendingCount(tier)
			button.Text = ("Ring %d%s"):format(
				tier,
				if waiting > 0 then (" (%d)"):format(waiting) elseif table.find(pages, tier) then " ✓" elseif locked then " 🔒" else ""
			)
			button.TextColor3 = if waiting > 0 then Color3.fromRGB(255, 215, 90) else UiKit.colors.text
		end

		UiKit.clear(cards)
		for i, species in FreakConfig.species[page] do
			local caught = caughtBySpecies[species.name] or {}
			local pending = pendingBySpecies[species.name] or {}
			local known = #caught > 0 or #pending > 0
			local card = UiKit.make("Frame", {
				LayoutOrder = i,
				Size = UDim2.fromOffset(CARD_WIDTH, CARD_HEIGHT),
				BackgroundColor3 = UiKit.colors.row,
				Parent = cards,
			})
			UiKit.corner(card, 10)
			if #pending > 0 then
				UiKit.make("UIStroke", { Color = Color3.fromRGB(255, 205, 60), Thickness = 2.5, Parent = card })
			end
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
				pip(pips, order, rarity, table.find(caught, rarity.id) ~= nil, table.find(pending, rarity.id) ~= nil)
			end
			if #pending > 0 then
				local reward = 0
				for _, rarity in pending do
					reward += math.floor(Freakpedia.discoveryReward * Formulas.sellPrice(species.tier, rarity))
				end
				local claim = UiKit.make("TextButton", {
					Position = UDim2.fromOffset(10, 208),
					Size = UDim2.new(1, -20, 0, 34),
					BackgroundColor3 = Color3.fromRGB(255, 195, 40),
					Font = Enum.Font.GothamBlack,
					TextSize = 16,
					TextColor3 = Color3.fromRGB(50, 35, 0),
					Text = ("CLAIM +%s"):format(Format.money(reward)),
					Parent = card,
				})
				UiKit.corner(claim, 8)
				claim.Activated:Connect(function()
					Sfx.play("click")
					claim.Active = false
					claim.Text = "..."
					Remotes.ClaimFreakpedia:FireServer(species.name)
				end)
			else
				UiKit.make("TextLabel", {
					Position = UDim2.fromOffset(8, 210),
					Size = UDim2.new(1, -16, 0, 30),
					BackgroundTransparency = 1,
					Font = Enum.Font.Gotham,
					TextSize = 13,
					TextWrapped = true,
					TextColor3 = UiKit.colors.muted,
					Text = if known then ("%d / %d rarities collected"):format(#caught, #Rarities.list) else ("Lives in Ring %d"):format(page),
					Parent = card,
				})
			end
		end

		local pagePercent = math.round(Freakpedia.pageBonus * 100)
		pageLine.Text = if table.find(pages, page)
			then ("Ring %d page complete: +%d%% farm income"):format(page, pagePercent)
			else ("Collect all %d at %s–%s to complete this page: +%d%% farm income"):format(
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
		Size = UDim2.fromOffset(190, 48),
		BackgroundColor3 = Color3.fromRGB(25, 28, 34),
		BackgroundTransparency = 0.1,
		Text = "",
		Parent = hud,
	})
	local title = UiKit.make("TextLabel", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBlack,
		TextSize = 18,
		TextColor3 = UiKit.colors.text,
		Text = "📖 Freakpedia",
		Parent = button,
	})
	UiKit.corner(button, 12)
	UiKit.make("UIStroke", { Color = UiKit.accents.freakpedia, Thickness = 2.5, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = button })
	-- "P" keycap on the left of the button, for players with a keyboard.
	local keycap = UiKit.make("TextLabel", {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 10, 0.5, 0),
		Size = UDim2.fromOffset(26, 26),
		BackgroundColor3 = Color3.fromRGB(235, 238, 242),
		Font = Enum.Font.GothamBlack,
		TextSize = 16,
		TextColor3 = Color3.fromRGB(25, 28, 34),
		Text = "P",
		Parent = button,
	})
	UiKit.corner(keycap, 6)
	UiKit.make("UIStroke", { Color = UiKit.accents.freakpedia, Thickness = 1.5, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = keycap })
	local function updateKeycap()
		keycap.Visible = UserInputService.KeyboardEnabled
		-- Centered in the space right of the keycap when it shows.
		title.Position = UDim2.fromOffset(if keycap.Visible then 36 else 0, 0)
		title.Size = UDim2.new(1, if keycap.Visible then -36 else 0, 1, 0)
	end
	UserInputService:GetPropertyChangedSignal("KeyboardEnabled"):Connect(updateKeycap)
	updateKeycap()
	button.Activated:Connect(function()
		Sfx.play("click")
		setOpen(not gui.Enabled)
	end)

	-- Red badge on the button's top-right corner: new entries waiting to be claimed.
	local badge = UiKit.make("TextLabel", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(1, -4, 0, 4),
		Size = UDim2.fromOffset(28, 28),
		BackgroundColor3 = Color3.fromRGB(230, 40, 40),
		Font = Enum.Font.GothamBlack,
		TextSize = 16,
		TextColor3 = Color3.new(1, 1, 1),
		Text = "",
		Visible = false,
		ZIndex = 2,
		Parent = button,
	})
	UiKit.corner(badge, 14)
	UiKit.make("UIStroke", { Color = Color3.new(1, 1, 1), Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = badge })
	local badgeScale = UiKit.make("UIScale", { Parent = badge })
	local lastWaiting = 0
	local function updateBadge()
		local waiting = pendingCount(nil)
		badge.Visible = waiting > 0
		badge.Text = if waiting > 99 then "99+" else tostring(waiting)
		if waiting > lastWaiting then
			badgeScale.Scale = 1.5
			TweenService:Create(badgeScale, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
		end
		lastWaiting = waiting
	end
	player:GetAttributeChangedSignal("FreakpediaPending"):Connect(updateBadge)
	updateBadge()

	UserInputService.InputBegan:Connect(function(input, processed)
		if not processed and input.KeyCode == Enum.KeyCode.P then
			setOpen(not gui.Enabled)
		end
	end)

	player:GetAttributeChangedSignal("Freakpedia"):Connect(render)
	player:GetAttributeChangedSignal("FreakpediaPending"):Connect(render)
	player:GetAttributeChangedSignal("HighestTier"):Connect(render)

	hud.Parent = player:WaitForChild("PlayerGui")
	gui.Parent = player:WaitForChild("PlayerGui")
end

return FreakpediaController
