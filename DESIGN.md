# Catch a Freak — Game Design

Roblox game. Run out into radioactive rings, catch as many freaks as you can carry, and get back alive. Farm them for money or sell them. Spend money on upgrades, turn in specific freaks to unlock the next ring, repeat.

All numbers in this document are **starting values to tune during playtests**. Keep every number in a config module (see "Code layout") so tuning never means editing game logic.

---

## 1. Design decisions (final)

| Topic | Decision |
|-------|----------|
| Tiers | 5 tiers at launch, one ring per tier, built to grow to 10. Tiers are data, so more can be added later. |
| Layout | Concentric rings, every ring the same 150 studs wide. A cylindrical barrier protects the shop and inner ring. Each tier is a ring further out, separated from the previous one by a giant wall. Later rings feel different through their environment, not their size. |
| Doors | Every barrier and wall has 4 doors. The barrier's doors are always open to everyone. Tier wall doors open per player once that player has unlocked the tier. |
| Shared world | The outer rings and the freaks in them are shared by everyone on the server. |
| Rarities | 5: Common, Uncommon, Rare, Epic, Legendary. Rarities are data and can be edited later. |
| Rarity odds | Common 50%, Uncommon 30%, Rare 14%, Epic 5%, Legendary 1%, rolled on every spawn. |
| Species | 3 per tier, 15 at launch. |
| Population | A fixed 70–90 freaks per ring: 70, 75, 80, 85, 90 for Rings 1–5; later rings 90. Only rings with players near them have freaks at all (section 12). |
| Carrying | Up to 9 freaks at once. |
| Value | Each tier is worth 10× the one before it. |
| Death | Lose every carried freak. Keep money, upgrades, items, and farm. Respawn at the shop. |
| Farms | One private plot per player, 8 plots, 8 players per server. Every plot is a fixed size with 16 glass incubators on one floor. Capacity upgrades unlock incubators; the plot never changes size. |
| Radiation | Constant damage per second, doubling every ring. No healing in the rings. |
| Gates | Each gate asks for 2 specific freaks. A freak of the required species at the required rarity **or higher** counts. Wheel prizes count. |
| Pacing | Fast at the start, slowing sharply. Each tier multiplies income by 10. Gear (Shoes, Hazmat, Grip) unlocks 5 more levels per ring, and each ring's 5 levels cost 10× the previous ring's, so gear keeps pace with both income and radiation. |

---

## 2. World layout

A circular map. Distances are in studs from the map center. Which zone a player or freak is in is decided purely by distance from the center.

| Zone | Radius | Contents | Radiation |
|------|--------|----------|-----------|
| Shop | 0–40 | Shop, sell counter, gate counter, daily wheel, spawn point | None |
| Inner ring | 40–175 | 8 farm plots (layout in section 6) | None |
| Ring 1 (Tier 1) | 175–325 | Tier 1 freaks | 8 HP/s |
| Ring 2 (Tier 2) | 325–475 | Tier 2 freaks | 16 HP/s |
| Ring 3 (Tier 3) | 475–625 | Tier 3 freaks | 32 HP/s |
| Ring 4 (Tier 4) | 625–775 | Tier 4 freaks | 64 HP/s |
| Ring 5 (Tier 5) | 775–925 | Tier 5 freaks | 128 HP/s |

Ring N spans radius `175 + 150 × (N − 1)` to `175 + 150 × N`. Raw radiation is before the Hazmat Suit (section 4).

Walls:

| Wall | Radius | Height | Doors |
|------|--------|--------|-------|
| Safe-zone barrier | 175 | 60 | 4 openings, always open to everyone |
| Tier 2 wall | 325 | 120 | 4 doors, open per player after Gate 1 |
| Tier 3 wall | 475 | 120 | 4 doors, open per player after Gate 2 |
| Tier 4 wall | 625 | 120 | 4 doors, open per player after Gate 3 |
| Tier 5 wall | 775 | 120 | 4 doors, open per player after Gate 4 |
| Outer boundary | 925 | 120 | None |

Growing to 10 rings later: each new ring adds a tier wall at the old boundary and moves the boundary 150 studs out (10 rings → boundary at 1675). Two things to handle then: a Roblox part can't be wider than 2048 studs, so ground discs past radius 1024 must be split into pieces; and the outermost walls need longer segments to keep the part count reasonable.

Because rings are concentric and equally wide, outer rings have more ground area (Ring 5 has about 2.7× Ring 1's area), so the same 70–90 freaks are more spread out. If that ever feels sparse, tighten freak wandering or add a few freaks rather than widening rings.

- Doors sit at north, east, south, and west on every wall, lined up so a player can run straight out through all of them.
- Each door is 24 studs wide.
- The safe-zone barrier should look like a containment field (glowing, semi-transparent cylinder) so it reads as the thing keeping radiation out.
- Players must not be able to jump or climb over any wall.
- A player can enter or leave through any door they have access to.

Per-player doors: the door is solid for players who have not unlocked the tier and passable for those who have. Do this with a client-side door state plus a server check. If the server finds a player in a ring above their unlocked tier, it teleports them back to the shop.

Safe zone = shop + inner ring. Health regenerates at 10 HP/sec there. Roblox's default health regeneration is disabled.

---

## 3. Core loop

1. Leave the safe zone through a barrier door. Radiation starts draining health.
2. Find a freak and hold the grab input until the grab bar fills. It goes into a carry slot.
3. Keep catching, up to 9, while health holds out.
4. Get back inside the barrier before health reaches zero. Dying loses the whole haul.
5. Place freaks on your farm (earns money over time) or sell them at the shop (one-time payout).
6. Stand on your farm's collection pad to move earned money into your wallet.
7. Spend money on upgrades and items.
8. Turn in the 2 freaks the current gate asks for. The next tier's wall doors open for you.
9. Higher rings are further out, so you cross the earlier rings going in and coming back.

---

## 4. Player

- Health: 100
- Walk speed: `min(16 + 2.5 × shoesLevel, 55)`. Each Shoes level is a noticeable jump; the cap of 55 is reached around Ring 4. Above that, Roblox characters get hard to steer and the client struggles to stream the map in ahead of the player, so later rings need travel aids rather than more raw speed.
- Carry slots: 9. Each slot holds one freak.
- Carrying does not slow the player.
- Carried freaks trail behind the player as miniatures (about 40% size) in carry-slot order, each over a small disc glowing in its rarity color. Everyone sees every player's trail. Placing, selling or dying removes them from the trail.

### Radiation

Damage per second while in a ring:

`damage = tier.radiationDps × 0.85 ^ hazmatLevel`

Raw radiation doubles every ring (8, 16, 32, 64, 128 HP/s for Rings 1–5). Each Hazmat level multiplies damage by 0.85, and 5 more levels unlock with each ring (section 7), so gear grows at the same pace as radiation. A player geared for ring N finds every earlier ring progressively cheaper, so crossing them costs about the same however far out the target ring is. That's what keeps 10 rings survivable. With no suit, 100 HP lasts 12.5 seconds in Ring 1: enough to grab one or two freaks near the barrier and get back.

The server applies it once per second based on the player's distance from the center. The client only displays it.

Tuning target: a ring is tense the moment it unlocks and comfortable once the player has bought that ring's gear. Seconds a player can spend inside ring N after crossing the earlier rings both ways and saving enough health to get back (100 HP, rings 150 wide, Shoes and Hazmat at the same level):

| Ring | Just unlocked (gear level 5 × (N − 1)) | Fully geared for it (gear level 5 × N) |
|------|----------------------------------------|----------------------------------------|
| 1 | 12.5 | 28 |
| 2 | 9 | 28 |
| 3 | 10 | 32 |
| 4 | 13 | 36 |
| 5 | 15 | 40 |
| 10 (future) | 31 | 77 |

### Death

- All carried freaks are destroyed.
- Money, upgrades, items, and farm are untouched.
- Respawn at the shop.
- If the player was carrying at least one freak of any rarity, offer the "Respawn with Caught Freaks" purchase for 10 seconds (see Monetization).

---

## 5. Freaks

A freak is defined by species, tier, and rarity.

### Tiers

| Tier | Ring | Population | Radiation DPS | Base income ($/sec) | Base hold (sec) | Freak speed |
|------|------|------------|---------------|---------------------|-----------------|-------------|
| 1 | Ring 1 | 70 | 8 | 1 | 1.0 | 6 |
| 2 | Ring 2 | 75 | 16 | 10 | 2.0 | 9 |
| 3 | Ring 3 | 80 | 32 | 100 | 3.5 | 12 |
| 4 | Ring 4 | 85 | 64 | 1,000 | 5.5 | 14 |
| 5 | Ring 5 | 90 | 128 | 10,000 | 8.0 | 16 |

### Rarities

| Rarity | Spawn chance | Income multiplier | Hold multiplier | Color |
|--------|--------------|-------------------|-----------------|-------|
| Common | 50% | ×1 | ×1 | Gray |
| Uncommon | 30% | ×2 | ×1.5 | Green |
| Rare | 14% | ×5 | ×2.5 | Blue |
| Epic | 5% | ×15 | ×4 | Purple |
| Legendary | 1% | ×50 | ×6 | Gold |

### Value

- `income per second = tier.baseIncome × rarity.incomeMultiplier`
- `sell price = 30 × income per second`

Income per second by tier and rarity:

| Tier | Common | Uncommon | Rare | Epic | Legendary |
|------|--------|----------|------|------|-----------|
| 1 | 1 | 2 | 5 | 15 | 50 |
| 2 | 10 | 20 | 50 | 150 | 500 |
| 3 | 100 | 200 | 500 | 1,500 | 5,000 |
| 4 | 1,000 | 2,000 | 5,000 | 15,000 | 50,000 |
| 5 | 10,000 | 20,000 | 50,000 | 150,000 | 500,000 |

### Species

Names are placeholders. Rename freely. Species within a tier have identical stats. They differ in look (each species has its own body shape and color) and in which gate asks for them.

| Tier | Species A | Species B | Species C |
|------|-----------|-----------|-----------|
| 1 | Glowbug | Twitcher | Sludgelet |
| 2 | Tri-Eye | Rustback | Fizzler |
| 3 | Gloomhound | Splitjaw | Wobbler |
| 4 | Voidmoth | Gnashling | Bloatworm |
| 5 | Hexwing | Grimjaw | Pulsar |

### Spawning

- Each ring keeps its population constant. When a freak is caught or expires, a new one spawns 3 seconds later at a random point in the ring, at least 10 studs from any wall.
- Each spawn picks a species at random (equal odds) and rolls rarity from the table above.
- **Lifetime:** every freak expires 120–240 seconds after spawning (random per freak) and is replaced by a fresh roll. Without this, players take the rare ones and leave the Commons, nothing respawns, and the ring fills up with Commons. A freak that is being grabbed or is pinned by a trap does not expire.
- Rarity is shown by an outline in the rarity color, on every rarity including Common. Only the nearest 6 freaks to the player are outlined at a time (Roblox renders at most ~31 outlines at once, and this keeps the view uncluttered), so a rare is something you spot up close rather than from across the ring. The body stays in its species color.
- Freaks placed in incubators show rarity through the incubator's floor light instead of an outline.
- Freaks are shared by everyone on the server. The first player to finish a grab gets it.

### Behavior

- Wander: pick a random point within 60 studs (inside the same ring), walk there, wait 1–3 seconds, repeat.
- Freaks never leave their ring.
- No fleeing or attacking at launch.

### Grabbing

- Each freak has a `ProximityPrompt` with a 10-stud range. `HoldDuration` is set per player on the client from the formula below.
- `holdTime = tier.baseHold × rarity.holdMultiplier × 0.93 ^ gripLevel`. Base holds grow per tier, and Grip unlocks 5 levels per ring like the other gear, so a fully geared player's Common grab stays around 1 second in every ring (0.7 s in Ring 1, 1.3 s in Ring 5).
- Leaving range or releasing the input cancels the grab and resets the bar.
- On completion the server checks that the player is alive, in the same ring, within range, held for the required time, and has a free carry slot. Then the freak moves into the first free slot.
- Implementation note: Roblox checks a prompt's range against the server's copy of the freak, which only moves at the start of each waypoint. So the server-side prompt has a range of grab range + wander radius and a hold time of 0, and each client sets its own copy to the real 10-stud range and per-player hold time. The server's own checks above are what actually decide a grab.

Hold time in seconds at Grip level 0:

| Tier | Common | Uncommon | Rare | Epic | Legendary |
|------|--------|----------|------|------|-----------|
| 1 | 1.0 | 1.5 | 2.5 | 4.0 | 6.0 |
| 2 | 2.0 | 3.0 | 5.0 | 8.0 | 12.0 |
| 3 | 3.5 | 5.3 | 8.8 | 14.0 | 21.0 |
| 4 | 5.5 | 8.3 | 13.8 | 22.0 | 33.0 |
| 5 | 8.0 | 12.0 | 20.0 | 32.0 | 48.0 |

---

## 6. Farm

The farm is also a showcase. Every freak a player keeps stands in its own glass incubator where the whole server can see it.

- Each player is assigned a free plot when they join. The plot shows their name on an owner sign.
- Plot layout: a lab floor with a center aisle running front to back (front = the side facing the shop), 16 glass incubators in a 4×4 grid split by the aisle, a collection pad on the ground just in front of the plot, and a value sign beside it. Incubators are numbered front row first. Incubators up to the player's capacity look unlocked; the rest look locked. Each capacity level unlocks the next one.
- Starting capacity: 3 freaks (incubators 1–3 unlocked).
- To place freaks, use the **Farm** prompt at the front of your own plot's aisle to open the farm panel, then place freaks one at a time or with **Place all**. Each one goes to the lowest-numbered empty unlocked incubator. With every unlocked incubator full, placing is refused with a "Farm full" message. The Farm prompt only exists on your own plot; the panel closes with its X or when you walk off the plot.
- Placed freaks are visible to everyone.

### Plot layout

Every plot is the same fixed size and never grows. All 16 incubators exist from the start; capacity only changes how many are unlocked. The look is a laboratory, not a farm: white lab floor, metal grating aisle, glass incubators.

Placement in the inner ring:

- 8 plots, centered at 22.5°, 67.5°, 112.5°, and so on every 45°. This keeps the four straight lanes from the shop to the N/E/S/W barrier doors clear (every plot part stays more than 12 studs from each lane's center line).
- Each plot is 60×60 studs, centered at radius 137 (covering radius 107 to 167), with its front edge facing the shop.

Inside a plot, measured from the front-left corner (x across the width, y back along the depth; negative y is in front of the plot):

| Part | Size | Position |
|------|------|----------|
| Center aisle | 8 wide | x 26–34, running front to back |
| Incubators | 11×11 footprint, 16 studs tall inside, 16 total | 4 columns at x 1–12, 14–25, 35–46, 48–59. 4 rows at y 2–13, 17–28, 32–43, 47–58. |
| Collection pad | 6×6, on the ground | x 27–33, y −8 to −2 |
| Value sign | 10 wide, on posts | x 16–26, y −5, facing the shop. Shows "VALUE GENERATED": the uncollected pool in dollars, and the farm's income per second below it. |
| Owner sign | 16 wide, raised above the incubators | Back end of the aisle, facing the shop. Shows the player's name and the farm's total income per second. |

- Incubators are numbered 1–16, front row first, left to right.
- An incubator is a lit floor, four glass walls, metal corner posts, and a glass lid. The plot itself has no outer walls or roof, so the freaks can be seen from outside.
- Unlocked incubators have clear glass and a lit floor. Locked incubators are greyed out (smoky glass, dark floor, light off) until upgraded. They carry no number or icon; the order is implied.
- Capacity tops out at 16 (3 starting + 13 Farm Capacity levels), so a fully upgraded farm fills every incubator.

Freaks in incubators:

- A placed freak is scaled to fit inside its incubator (up to about 9 studs wide and 15 tall), stands centered, and faces the front.
- The incubator's floor light glows in the freak's rarity color.
- A freak's name, rarity, and income label only appears when a player is within 20 studs.
- Each placed freak adds its income per second to the farm's uncollected pool.
- Standing on the collection pad moves the whole pool into the wallet.
- From the farm panel a player can pick a placed freak back up into a free carry slot (to sell it or turn it in at a gate).
- Other players cannot interact with your farm.

### Offline earnings

- When the player leaves, save the timestamp.
- When they return, add `farm income per second × seconds away` to the uncollected pool, capped at the offline limit.
- Starting offline limit: 1 hour of earnings.
- Offline earnings are never doubled by the 2x Money boost.
- Show a "While you were away you earned $X" popup on join.

---

## 7. Shop

### Upgrades

Cost of the next level = `baseCost × growth ^ currentLevel`, rounded to the nearest dollar.

**Gear** (Shoes, Hazmat Suit, Stronger Grip) unlocks with progress: a player can buy up to `5 × highestTier` levels of each, so 5 more levels open every time a ring unlocks. Gear grows ×10^(1/5) ≈ ×1.585 per level, which makes each ring's 5 levels cost exactly 10× the previous ring's, matching the 10× income of each new ring.

| Upgrade | Effect per level | Max level | Level cap | Base cost | Growth | Cost of level 5 | Cost of last level |
|---------|------------------|-----------|-----------|-----------|--------|-----------------|--------------------|
| Shoes | +2.5 walk speed (capped at 55) | 16 | 5 per unlocked tier | 50 | ×1.585 | 315 | 50K |
| Hazmat Suit | Radiation damage ×0.85 | 25 (5 per ring; 50 at 10 rings) | 5 per unlocked tier | 75 | ×1.585 | 473 | 4.73M |
| Stronger Grip | Grab hold time ×0.93 | 25 (5 per ring; 50 at 10 rings) | 5 per unlocked tier | 60 | ×1.585 | 379 | 3.79M |
| Farm Capacity | Unlocks the next incubator | 13 | — | 150 | ×2.8 | 9,220 | 34.8M |
| Offline Capacity | +1 hour offline limit | 7 | — | 300 | ×4 | 76,800 | 1.2M |

Shoes stops at 16 because level 16 reaches the 55 speed cap. Farm Capacity uses ×2.8 so its 13 levels (enough to unlock all 16 incubators) cost about 54M in total.

The first levels of each ring cost less than one run's haul there. Buying a ring's full set takes a few dozen runs or a stretch of farm income. This is the main pacing lever.

### Items

Consumable. Bought at the shop. Price scales with the player's highest unlocked tier: `price = basePrice × 10 ^ (highestTier − 1)`. Players can hold up to 5 of each.

Items are used with dedicated buttons, not carry slots: Q for Net Launcher, R for Bear Trap, plus on-screen buttons for mobile.

| Item | Base price | Behavior |
|------|-----------|----------|
| Net Launcher | 100 | Fires at a target point up to 40 studs away. Instantly catches up to 3 freaks within 15 studs of the impact, limited by free carry slots, with no hold time. Works on Common, Uncommon, and Rare. Has no effect on Epic or Legendary. One use. |
| Bear Trap | 50 | Placed on the ground. The first freak to walk over it is pinned for 30 seconds. A pinned freak takes 0.5 seconds to grab regardless of tier or rarity, and only the trap's owner can grab it while pinned. The trap disappears after it triggers or after 120 seconds. One active trap per player. One use. |

### Selling

The **Sell** prompt at the sell counter opens the sell panel: the player's carried freaks with each one's price, sold individually or with "Sell all". Payout is the sum of the sell prices. The shop counter works the same way with a **Shop** prompt. Panels close with their X or when the player walks away, and the server refuses any sell, buy or place request made away from the counter or plot.

---

## 8. Progression gates

Each gate asks for 2 specific freaks. A freak counts if it is the required species at the required rarity or higher. Turn them in at the gate counter in the shop, from the carry slots or straight from the farm. Turned-in freaks are consumed.

| Gate | Unlocks | Requirement 1 | Requirement 2 |
|------|---------|---------------|---------------|
| 1 | Tier 2 (Ring 2) | Uncommon Twitcher | Rare Glowbug |
| 2 | Tier 3 (Ring 3) | Rare Rustback | Epic Fizzler |
| 3 | Tier 4 (Ring 4) | Rare Gloomhound | Epic Wobbler |
| 4 | Tier 5 (Ring 5) | Rare Gnashling | Epic Bloatworm |

- The gate panel always shows the current requirements and which are done.
- Requirements can be turned in one at a time. Progress is saved.
- Ring 5 is the last ring at launch.

---

## 9. Daily wheel

Located in the shop. One free spin per UTC day. The player needs one free carry slot to spin. The prize freak goes into a carry slot, and they place or sell it like any other.

| Odds | Prize |
|------|-------|
| 47% | Common freak, current tier |
| 40% | Rare freak, current tier |
| 10% | Common freak, next tier |
| 3% | Rare freak, next tier |

- "Current tier" is the player's highest unlocked tier.
- Species is random within the prize tier.
- The wheel never gives anything above Rare from the next tier. This keeps it from skipping progression.
- If the player is already on the last tier, the 10% result gives an Epic freak of that tier and the 3% result gives a Legendary one.
- The odds table is shown on the wheel UI at all times.
- The server rolls the result. The client only plays the animation.

---

## 10. Monetization

Build this last, after the loop is fun. Product IDs go in a config module as placeholders until the products are created in Creator Hub.

| Product | Type | Behavior |
|---------|------|----------|
| 2x Money (1 hour) | Developer Product | Doubles farm income and sell payouts for 60 minutes of in-game time. The timer only counts down while the player is online. Buying again adds another 60 minutes. Shown as a HUD timer. |
| Extra Wheel Spin | Developer Product | Grants one extra spin, usable immediately. |
| Upgrade Skins | Game Pass per skin set | Cosmetic only. Changes the look of shoes, hazmat suit, and so on. No gameplay effect. |
| Respawn with Caught Freaks | Developer Product | Offered for 10 seconds after dying while carrying at least one freak of any rarity. On purchase the player respawns at the shop still carrying everything. |

Rules:

- Handle all Developer Products in a single `MarketplaceService.ProcessReceipt` callback. Grant the item, save, then return `PurchaseGranted`. Record processed purchase IDs so a receipt is never granted twice.
- **Paid wheel spins are "paid random items" under Roblox policy.** The wheel must show every possible outcome with its numerical odds before purchase. Check `PolicyService:GetPolicyInfoForPlayerAsync()` and hide the Extra Wheel Spin purchase when `ArePaidRandomItemsRestricted` is true. The free daily spin stays available to everyone. Reference: https://create.roblox.com/docs/production/monetization/paid-random-items

---

## 11. UI

| Screen | Contents |
|--------|----------|
| HUD | Money, health bar, radiation warning while in a ring, item buttons with counts, 2x timer when active |
| Carry bar | 9 slots along the bottom. Each filled slot shows the species icon with a rarity-colored border. This is a custom UI, not the Roblox backpack. Disable the default backpack. |
| Grab bar | Fills while holding a grab |
| Shop | Tabs: Upgrades, Items, Skins. Each row shows current level, effect, and next cost. |
| Sell panel | Carried freaks with sell price each, "Sell all" |
| Gate panel | The 2 required freaks, checkmarks for done ones, turn-in buttons |
| Farm panel | Placed freaks with income each, total income per second, capacity, place and pick-up buttons |
| Wheel | Wheel, odds table, spin button, time until next free spin |
| Popups | Offline earnings on join, revive offer on death, tier unlocked |

---

## 12. Technical rules

### Server authority

The server owns and validates everything that matters: money, health, radiation, grabs, carry slots, farm contents, upgrade levels, gate progress, wheel results, purchases. The client sends requests ("I want to buy Shoes") and the server decides. Never accept a value from the client (an amount, a price, a freak's tier or rarity).

### Freak performance

A full 5-ring map holds 400 freaks (1,000+ at 10 rings), so ring count must not drive the cost:

- **Only rings near players are simulated.** A ring's freaks spawn (its full population at once) when any player comes within 60 studs of it, and all despawn once no player has been that close for 60 seconds. With 8 players, at most 8 rings are ever active and usually 2–3, so 10 rings cost about what 2–3 do. Despawning ends any traps and pins in that ring.
- **Clients only animate nearby freaks**, within 300 studs; farther ones are left where they are. Workspace streaming keeps distant parts of the map off the client entirely.

- Freaks are anchored models with no `Humanoid`.
- The server does not move them every frame. For each freak it stores a current waypoint (start position, target position, start time, speed) and publishes it as attributes on the model whenever the waypoint changes.
- Each client moves the freak models locally by interpolating along the waypoint.
- When the server needs a freak's position (grab range, net radius, trap trigger), it calculates it from the same waypoint data.
- Keep `StreamingEnabled` on.

### Studio-only debug commands

For playtesting, available only when `RunService:IsStudio()` is true: set money, set highest tier, set any upgrade level, spawn a freak of a given tier and rarity next to the player. Use these to test Rings 2 and 3 before gates exist.

### Code layout

Code lives in `src/` and syncs through Rojo.

```
src/
  shared/            -> ReplicatedStorage
    Config/
      World.luau         radii, wall heights, door angles from section 2;
                         farm plot placement and incubator layout from section 6
      Tiers.luau         section 5 tier table
      Rarities.luau      section 5 rarity table
      Freaks.luau        species list
      Upgrades.luau      section 7 table
      Items.luau
      Gates.luau         section 8 table
      Wheel.luau         odds
      Products.luau      product and game pass IDs
    Formulas.luau        income, sellPrice, holdTime, radiation, upgradeCost, itemPrice, zoneFromPosition
    Remotes.luau         creates and exposes all RemoteEvents/Functions
  server/            -> ServerScriptService
    DataService.luau     load, save, autosave, offline earnings
    ZoneService.luau     zone per player, tier access enforcement
    RadiationService.luau
    FreakService.luau    spawning, lifetime, waypoints, grabbing
    CarryService.luau    each player's 9 carry slots
    FarmService.luau     plots, placing, income, collecting
    ShopService.luau     upgrades, items, selling
    ItemService.luau     net launcher, bear trap
    GateService.luau     turn-ins, tier unlocks
    WheelService.luau
    MonetizationService.luau
    DebugService.luau    Studio-only commands
  client/            -> StarterPlayerScripts
    FreakRenderer.luau   moves freak models along their waypoints
    DoorController.luau  per-player door state
    one controller per UI screen in section 11
```

All formulas live in `Formulas.luau` so the client can display the same numbers the server enforces.

### Saved data

One record per player, saved with **ProfileStore** (decided in Milestone 6) for session locking: a player's data is only ever open on one server, so fast rejoins and server hops can't duplicate or roll back progress. Autosave every 60 seconds; ProfileStore also saves when the player leaves and on server shutdown (`BindToClose`). ProfileStore is vendored in `src/server/Vendor/` (Apache-2.0, license in `third_party/ProfileStore/`). `lastSeen` is stamped on every save, so offline earnings work even after a crash.

```lua
{
  version = 1,
  money = 0,
  upgrades = { shoes = 0, hazmat = 0, grip = 0, farmCapacity = 0, offlineCapacity = 0 },
  items = { netLauncher = 0, bearTrap = 0 },
  highestTier = 1,
  gateProgress = { false, false },   -- current gate's two requirements
  farm = {                            -- placed freaks
    -- { species = "Twitcher", tier = 1, rarity = "Uncommon", effects = {} },
  },
  uncollected = 0,
  lastSeen = 0,                       -- os.time() at last save
  wheel = { lastFreeSpinDay = 0, extraSpins = 0 },
  boost2xSecondsLeft = 0,
  ownedSkins = {},
  processedReceipts = {},             -- last 50 purchase IDs
}
```

- Carried freaks are not saved. Leaving the game while carrying loses them.
- Every freak record has an `effects` list. It stays empty at launch. It exists so status effects (section 14) can be added later without migrating saved data. The income formula should already multiply by an effects multiplier that is 1 when the list is empty.

### Studio setup needed before Milestone 6

- Publish the place to Roblox.
- Game Settings → Security → enable "Studio Access to API Services" so DataStores work in Studio.

---

## 13. Milestones

Build in this order. Do not start a milestone until the previous one passes its check in a playtest with no errors in the output log.

| # | Milestone | Done when |
|---|-----------|-----------|
| 1 | Greybox map and farm plots | If an earlier greybox exists at different dimensions, rebuild it to these. The shop, safe-zone barrier, both tier walls, and outer boundary exist at the section 2 radii. Each wall has 4 doors at N/E/S/W. All 8 farm plots exist at the section 6 positions and size (60×60). Each plot has a lab floor, a center aisle, 16 glass incubators in a 4×4 grid numbered front row first, a collection pad in front, a value sign, and an owner sign. Incubators 1–3 look unlocked and 4–16 look locked (greyed out). A player can walk from spawn straight down each N/E/S/W lane, through the barrier door, into Ring 1 without crossing a plot. The Tier 2 and Tier 3 doors block the player. No wall can be jumped or climbed. A top-down screenshot shows no plots overlapping each other, the shop, or the barrier. |
| 2 | Zones and radiation | Zone is detected from distance to center. Health drains at 8/sec in Ring 1 and regenerates in the safe zone. Dying respawns the player at the shop. HUD shows health and a radiation warning. The debug command to set highest tier works: with tier 3 set, the player can pass both walls and takes 16/sec in Ring 2 and 32/sec in Ring 3, divided by (1 + 1.7 × Hazmat level). A player found in a ring above their tier is sent back to the shop. |
| 3 | Freaks and grabbing | Ring 1 holds 70 wandering freaks. Over 1,000 simulated spawns the rarity split is within 2 points of 50/30/14/5/1. The nearest 6 freaks are outlined in their rarity colors. Freaks expire and are replaced. Holding the prompt fills the grab bar; hold times match the section 5 table. Caught freaks fill the carry bar up to 9, and the 10th grab is refused. Dying clears the carry bar. The server stays smooth with all 70 moving. |
| 4 | Money loop | Money shows on the HUD. The sell panel sells one freak or all, at 30× income. Placing a freak puts it in the lowest-numbered empty unlocked incubator, scaled to fit, with the incubator's floor light in its rarity color. Placing is refused when all unlocked incubators are full. The pool grows every second by the right amount, the value sign shows the pool and income per second, the owner sign shows the player's name, and standing on the collection pad collects it. Picking a freak back up empties its incubator. |
| 5 | Shop | All 5 upgrades can be bought, cost `base × growth^level`, stop at max level, and change what they say they change. Each Farm Capacity level unlocks the next incubator, stopping at incubator 16. Net Launcher catches up to 3 Common/Uncommon/Rare freaks and ignores Epic/Legendary. Bear Trap pins one freak and makes it a 0.5-second grab for its owner. |
| 6 | Saving | Leaving and rejoining restores money, upgrades, items, farm, uncollected pool, and highest tier. Carried freaks are gone. Offline earnings are added, capped, and shown in a popup. |
| 6.5 | Haul, place, and sell flow | This completes and re-checks Milestone 4's flow end to end. First audit what already exists against sections 4, 6, and 7, then fix or build whatever is missing. Done when all of this works in one continuous playtest: (1) The player catches 3 freaks in Ring 1 and a miniature of each trails behind them. (2) Back at their own plot, the Farm prompt opens the farm panel. Placing 2 freaks puts them on pads, removes them from the carry bar and the trail, and raises the income on the owner sign. (3) At the shop, the Sell prompt opens the sell panel. Selling the third freak adds 30× its income to money and clears its slot. (4) "Place all" and "Sell all" both work with a full carry bar of 9. (5) With every unlocked pad full, placing is refused with a "Farm full" message. (6) The Farm prompt does not appear on other players' plots, and the server refuses place and sell requests made away from the plot or counter. (7) Picking a freak up from a pad returns it to the carry bar. (8) After leaving and rejoining, the placed freaks are back on their pads. |
| 7 | Gates and tiers 2–3 | The gate panel shows Gate 1's requirements. A freak of the right species at the required rarity or higher is accepted, others are refused. Completing Gate 1 opens all 4 Tier 2 doors for that player only; Gate 2 does the same for Tier 3. Rings 2 and 3 hold 80 and 90 freaks of their own tier. The server stays smooth with all 240 freaks and 8 players. |
| 7.5 | Scaling to 5 rings | Rebuild the map to the section 2 radii: five 150-wide rings, a Tier 2–5 wall each with 4 doors at N/E/S/W, and the outer boundary at 925; the shop and plots are unchanged. Tiers 4 and 5 exist with their species, values, hold times and populations from section 5, and Gates 3 and 4 work like Gates 1 and 2. Radiation is 8/16/32/64/128 HP/s raw, reduced ×0.85 per Hazmat level. Walk speed is 16 + 2.5 per Shoes level, capped at 55. Grip multiplies hold time by 0.93 per level. Gear costs `base × 1.585^level`, and buying above `5 × highestTier` is refused while the shop shows which tier unlocks the next level. Existing saves keep the levels they have. A ring with no player within 60 studs has no freaks; it fills to its population when a player approaches and empties 60 seconds after the last one leaves. Clients only animate freaks within 300 studs. Using /tier and /upgrade to set the section 4 "just unlocked" gear, a player can reach each ring, stay about the table's time, and get back alive. The server stays smooth with players spread across all 5 rings. |
| 8 | Daily wheel | One free spin per UTC day. Over 10,000 simulated server-side rolls the results are within 1 point of 47/40/10/3. The prize lands in a carry slot. A last-tier player gets Epic and Legendary freaks of their tier in place of the next-tier results. Odds are displayed. |
| 9 | Monetization | All four products work in Studio test purchases. The revive is offered when dying with any freak and restores the full carry bar. A receipt replayed twice grants once. The paid spin is hidden when the policy check says restricted. |
| 10 | Polish | Real freak models, sounds, particles, UI pass, mobile controls check, economy tuning against the section 4 tuning target. |

---

## 14. After launch (not in version 1)

- **Status effects.** Freaks can carry effects such as Shocked, Frozen, or Flamed that raise their income multiplier. Effects come from changing environment conditions in the rings. The `effects` field and the multiplier hook in section 12 are there for this.
- More tiers beyond Ring 3
- Extra farm floors. When capacity needs to pass 16, each new floor adds 16 more incubators on the same footprint. Keep the space above every plot empty for this.
- More or different rarities
- Radiation that ramps up the longer you stay in a ring
- Freaks that flee or fight back in higher tiers
- A collection index with rewards for catching every species at every rarity
- Trading or stealing between players
- A rebirth system
- Leaderboards