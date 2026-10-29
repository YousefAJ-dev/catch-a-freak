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
| Population | Every ring has the same density of freaks as Ring 1 (70 freaks, about 3 per 10,000 square studs), so freak counts grow with ring area: 70, 112, 154, 196, 238 for Rings 1–5. Only rings with players near them have freaks at all (section 12). |
| Carrying | Up to 9 freaks at once. |
| Value | Each tier is worth 10× the one before it. |
| Death | Lose every carried freak. Keep money, upgrades, items, and farm. Respawn at your farm. |
| Farms | One private plot per player, 8 plots, 8 players per server. Every plot is a fixed size with 16 glass incubators on one floor. Capacity upgrades unlock incubators; the plot never changes size. |
| Radiation | Constant damage per second, tied to the Hazmat Suit: each ring is hotter by exactly what that ring's Hazmat levels block, plus 3%. Fully geared players feel each ring slightly harder than the last; a newly unlocked ring runs about 2.3× hotter until its Hazmat is bought. No healing in the rings. |
| Gates | Each gate asks for a number of 2 specific freaks. A freak of the required species at the required rarity **or higher** counts. Wheel prizes count. |
| Progression pace | Buying a ring's full gear takes about 30 min for Ring 1, then 1 h, 2 h, 3 h and 4 h (N − 1 hours for Ring N; ≈ 10.5 h to finish Ring 5) for a player with a strong farm and no 2x Money. Gates are worked on during the same time. Collection, mutations, quests and events add playtime on top without slowing the rings. |
| Pacing | Fast at the start, slowing steadily. Each tier multiplies income by about 10. Every ring-priced upgrade unlocks more levels per ring (3 for Shoes and Hazmat, 2 for Farm and Offline Capacity, 5 for Grip), priced from the ring's income and target time (section 7), so gear keeps pace with income and radiation at any number of rings. |

---

## 2. World layout

A circular map. Distances are in studs from the map center. Which zone a player or freak is in is decided purely by distance from the center.

| Zone | Radius | Contents | Radiation |
|------|--------|----------|-----------|
| Shop | 0–40 | Shop, sell counter, gate counter, daily wheel | None |
| Inner ring | 40–175 | 8 farm plots (layout in section 6) | None |
| Ring 1 (Tier 1) | 175–325 | Tier 1 freaks | 6 HP/s |
| Ring 2 (Tier 2) | 325–475 | Tier 2 freaks | 14.1 HP/s |
| Ring 3 (Tier 3) | 475–625 | Tier 3 freaks | 33 HP/s |
| Ring 4 (Tier 4) | 625–775 | Tier 4 freaks | 77.5 HP/s |
| Ring 5 (Tier 5) | 775–925 | Tier 5 freaks | 181.9 HP/s |

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

Growing to 10 rings later: each new ring adds a tier wall at the old boundary and moves the boundary 150 studs out (10 rings → boundary at 1675). Things to handle then:

- **Lifts (planned with Ring 6).** Walking out gets long (a round trip from the farm to Ring 10's edge is about 53 s at top speed), and crossing earlier rings costs almost nothing by then, so it adds time without tension. When Ring 6 is added, lifts in the safe zone carry a player to the inner door of Ring 5 and beyond, for any ring they've unlocked. Rings 1–4 keep the walk out.
- **Sector activation** (section 12) so a bigger ring doesn't cost more to run.
- A Roblox part can't be wider than 2048 studs, so ground discs past radius 1024 must be split into pieces, and the outermost walls need longer segments to keep the part count reasonable.
- Money past about 9 quadrillion ($9 × 10^15) can't be stored to the dollar, so the economy needs a look before Ring 10.

Because rings are concentric and equally wide, outer rings have more ground area (Ring 5 has 3.4× Ring 1's area). Freak counts scale with area (section 5), so every ring is equally crowded.

- Doors sit at north, east, south, and west on every wall, lined up so a player can run straight out through all of them.
- Each door is 24 studs wide.
- The safe-zone barrier is a solid lab containment wall: metal panels with a hazard-striped band and a glowing green light strip on the lab side, the Ring 1 palisade on the outside.
- Players spawn and respawn in front of their own farm plot, so they always know where it is. (A player found in a ring above their tier is still sent to the shop.)
- Players must not be able to jump or climb over any wall.
- A player can enter or leave through any door they have access to.

Per-player doors: the door is solid for players who have not unlocked the tier and passable for those who have. Do this with a client-side door state plus a server check. If the server finds a player in a ring above their unlocked tier, it teleports them back to the shop.

Safe zone = shop + inner ring. Stepping from a ring into the safe zone restores full health at once; after that, health regenerates at 10 HP/sec there (for damage taken inside it, such as carrying a Radioactive freak). Roblox's default health regeneration is disabled.

Biomes (looks in `Config/Biomes.luau`, built by `tools/BuildBiomes.luau`):

| Zone | Biome | Ground | Walls | Props |
|------|-------|--------|-------|-------|
| Safe zone | Radioactive lab | Concrete, steel-plate shop floor | Force-field barrier | Hazard stripes, glowing vats piped into the barrier |
| Ring 1 | Dry field | Dry grass, dirt patches | Wooden palisade | Dead trees, fences, hay bales, scarecrows, rocks, bushes |
| Ring 2 | Wasteland | Sand, rock patches | Rusted sheet metal | Rock piles, car wrecks, leaking barrels, tires, broken concrete |
| Ring 3 | Radioactive swamp | Mud, moss patches | Mossy stone | Ankle-deep toxic pools (walk-through), swamp trees, reeds, logs, glowing mushrooms |
| Ring 4 | Cavern | Slate, basalt patches | Cave rock | Rock masses along the walls, arches over the lanes, stalagmites, glowing crystals and mushrooms |
| Ring 5 | Chemical plant | Asphalt, pavement patches | Metal panels | Tanks, smokestacks, pipe runs, containers, glowing vats, barrels |

- The rings' ground is flat terrain exactly at ground level (freaks stand at a fixed height), with low banks sloping up against the walls. Freaks stay 16 studs from walls, clear of the banks.
- Freaks walk in straight lines through props, so big props stand along the walls and the open middle of each ring stays mostly clear. Nothing is placed in the N/E/S/W lanes.
- Each zone has its own daytime lighting (haze, color grading, ambient), switched on the client when the player enters it.
- **Day/night cycle** (`Config/DayNight`): a shared 20-minute cycle, run by every client off the server's clock: 14 min of day, 75 s dusk, 3.5 min night, 75 s dawn. During the day the sun only moves between 10:30 and 15:30 so the 120-stud walls don't shade the ring floors. Night blends each zone's look toward a moonlit one with strong blue ambient light, so freaks stay easy to spot. The Cavern (Ring 4) is always night and ignores the cycle.

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
- Walk speed: `min(16 + 4.2 × shoesLevel, 55)`. Each Shoes level is a noticeable jump; the cap of 55 is reached at level 10, the first Ring 4 level. Above that, Roblox characters get hard to steer and the client struggles to stream the map in ahead of the player, so later rings need travel aids rather than more raw speed.
- **Dash** (F, or an on-screen button on mobile): once Shoes is maxed, the player can buy a Dash that bursts them about 50 studs over 0.4 s in the direction they're moving (or facing). Walls and closed doors still stop it. The cooldown starts at 8 s and each Dash Recharge level takes 1 s off, down to 3 s. At 3 s it adds roughly 16 studs/s on average, about 30% faster trips to the outer rings. The dash runs on the player's own client for instant response; the server enforces the cooldown.
- Carry slots: 9. Each slot holds one freak.
- Carrying does not slow the player.
- Carried freaks trail behind the player as miniatures (about 40% size) in carry-slot order, each over a small disc glowing in its rarity color. Everyone sees every player's trail. Placing, selling or dying removes them from the trail.

### Radiation

Damage per second while in a ring:

`damage = tier.radiationDps × 0.76 ^ hazmatLevel`

`radiationDps = 6 × (1.03 / 0.76³) ^ (tier − 1)`: 6, 14.1, 33, 77.5 and 181.9 HP/s for Rings 1–5 (`Config/Tiers`). Each Hazmat level multiplies damage by 0.76, and 3 more levels unlock with each ring (section 7). Raw radiation grows by exactly what one ring's 3 levels block (0.76³ ≈ 0.44), times 1.03. Because it's computed from the Hazmat numbers, retuning Hazmat moves radiation with it, and the feel holds at any number of rings:

- **Unlock jump:** a newly unlocked ring runs about 2.3× hotter until the player buys its 3 Hazmat levels. This is the "each tier hits hard" moment, and it's the same every ring.
- **Slow creep:** fully geared, each ring is about 3% harder than the last (2.6 HP/s in Ring 1, 3.0 in Ring 5, 3.4 in Ring 10). Radiation that simply doubled per ring would instead get easier each ring (11% less per ring), because each ring's Hazmat blocks more than double.
- **Crossing earlier rings** gets cheaper the further a player's gear is ahead of them.

With no suit, 100 HP lasts about 17 seconds in Ring 1: enough to grab one or two freaks near the barrier and get back.

The server applies it once per second based on the player's distance from the center. The client only displays it.

Tuning target: a ring is tense the moment it unlocks and comfortable once the player has bought that ring's gear. Seconds a player can spend inside ring N after crossing the earlier rings both ways and saving enough health to get back (100 HP, rings 150 wide, Shoes and Hazmat at the same level):

| Ring | Just unlocked (gear level 3 × (N − 1)) | Fully geared for it (gear level 3 × N) |
|------|----------------------------------------|----------------------------------------|
| 1 | 17 | 38 |
| 2 | 12 | 34 |
| 3 | 11 | 32 |
| 4 | 11 | 31 |
| 5 | 11 | 30 |
| 10 (future) | 9 | 25 |

### Death

- All carried freaks are destroyed.
- Money, upgrades, items, and farm are untouched.
- Respawn at their farm.
- If the player was carrying at least one freak of any rarity, offer the "Respawn with Caught Freaks" purchase for 10 seconds (see Monetization). A "No thanks" button closes the offer early.
- A dead player can't grab freaks while waiting to respawn.

---

## 5. Freaks

A freak is defined by species, tier, and rarity.

### Tiers

| Tier | Ring | Population | Radiation DPS | Base income ($/sec) | Base hold (sec) | Freak speed |
|------|------|------------|---------------|---------------------|-----------------|-------------|
| 1 | Ring 1 | 70 | 6 | 1 | 1.0 | 6 |
| 2 | Ring 2 | 112 | 14.1 | 7.5 | 2.0 | 9 |
| 3 | Ring 3 | 154 | 33 | 75 | 3.5 | 12 |
| 4 | Ring 4 | 196 | 77.5 | 750 | 5.5 | 14 |
| 5 | Ring 5 | 238 | 181.9 | 7,500 | 8.0 | 16 |

Population is Ring 1's density (70 freaks over Ring 1's area) times each ring's area, computed in config, so it stays right if ring width or count changes. Future rings continue the pattern: 280, 322, 364, 406, 448 for Rings 6–10.

### Rarities

| Rarity | Spawn chance | Income multiplier | Hold multiplier | Color |
|--------|--------------|-------------------|-----------------|-------|
| Common | 50% | ×1 | ×1 | Gray |
| Uncommon | 30% | ×1.8 | ×1.5 | Green |
| Rare | 14% | ×3.5 | ×2.5 | Blue |
| Epic | 4.8% | ×9 | ×4 | Purple |
| Legendary | 1% | ×30 | ×6 | Gold |
| Rainbow | 0.1% | ×50 | ×8 | Cycles through the rainbow (pink in menus) |
| Radioactive | 0.1% | ×77 | ×8 | Yellow-green |

The two top rarities are made to be spotted from across a ring: a light, a stream of sparkles, and a tint over the whole body (Rainbow's cycling through the rainbow, Radioactive's a strong yellow-green). They get their own outline instead of competing for the nearest-12 outlines. Carrying a Radioactive freak costs the carrier 1 HP per second, anywhere, and the Hazmat Suit doesn't reduce it (the HUD radiation warning includes it).

### Freakpedia

A collection book with an entry for every species at every rarity (15 species × 7 rarities = 105 entries). Catching a freak isn't enough: a species at a rarity becomes a new entry the first time the player brings one home and uses it, by putting it in an incubator, turning it in at a gate or selling it. New entries wait in the book until the player claims them by clicking CLAIM on the species' card; only claimed entries pay out and count toward pages. Freaks already on a player's farm when the Freakpedia launched were added as claimed, once. Rewards (all in `Config/Freakpedia`):

- Claiming a new entry pays 1× that freak's sell price.
- A ring's page is complete once every species of that ring has been caught at Common, Uncommon, Rare, Epic and Legendary. Each complete page gives a permanent +5% farm income.
- Each Rainbow or Radioactive entry gives a permanent +1% farm income.

The bonuses add up and apply to farm income and offline earnings, but not to sell prices.

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

Names are placeholders. Rename freely. Species within a tier have identical stats. They differ in look (each is its own 3D model, suited to its ring's biome) and in which gate asks for them.

| Tier | Species A | Species B | Species C |
|------|-----------|-----------|-----------|
| 1 (dry field) | Glowbug | Twitcher | Gnashling |
| 2 (wasteland) | Rustback | Gloomhound | Splitjaw |
| 3 (radioactive swamp) | Sludgelet | Hexwing | Bloatworm |
| 4 (cavern) | Nightmare | Voidmoth | Tri-Eye |
| 5 (chemical plant) | Pulsar | Wobbler | Grimjaw |

### Spawning

- Each ring keeps its population constant. When a freak is caught or expires, a new one spawns 3 seconds later at a random point in the ring, at least 16 studs from any wall (clear of the terrain banks along the walls).
- Each spawn picks a species at random (equal odds) and rolls rarity from the table above.
- **Lifetime:** every freak expires 120–240 seconds after spawning (random per freak) and is replaced by a fresh roll. Without this, players take the rare ones and leave the Commons, nothing respawns, and the ring fills up with Commons. A freak that is being grabbed or is pinned by a trap does not expire.
- Rarity is shown by an outline in the rarity color, on every rarity including Common. Only the nearest 12 freaks to the player are outlined at a time (Roblox renders at most ~31 outlines at once, and this keeps the view uncluttered), so a rare is something you spot up close rather than from across the ring. The body stays in its species color.
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
- Touch devices (phones and tablets) tap instead of holding, using a Grab button on the right above the jump button (see Touch controls in section 11) (it replaces the floating prompt and names the nearest freak). One tap starts the grab, and the bar keeps filling as long as the player stays in range. Leaving range cancels it, and tapping the button (now "Stop") stops it. The server times tap grabs itself, with the same hold time and range checks. In Studio, `/touchmode on|off` switches to these controls.
- The freak is caught when the bar fills: grabs finish one ping early (capped at `grabLeadMax`, 0.2 s, inside the server's 0.25 s hold tolerance) so the catch reaches the player as their bar completes.
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
- Starting capacity: 2 freaks (incubators 1–2 unlocked), then 2 more per ring.
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
- Capacity tops out at 16 (2 starting + 14 Farm Capacity levels, all by Ring 7), so a fully upgraded farm fills every incubator. Rings 8+ need extra floors (section 14).

Freaks in incubators:

- A placed freak is scaled to fit inside its incubator (up to about 9 studs wide and 15 tall), stands centered, and faces the front.
- The incubator's floor light glows in the freak's rarity color.
- A freak's name, rarity, and income label only appears when a player is within 20 studs.
- Each placed freak adds its income per second to the farm's uncollected pool.
- Standing on the collection pad moves the whole pool into the wallet, and "+$amount" rises over the player's head. Each player sees only their own pad in green (plain, no glow) with its COLLECT label; every other pad is grey.
- A 2x Money pad sits on the other side of the collection pad. Each player sees only their own lit up (glowing gold, "2x MONEY" label, "2x MONEY ✓" once owned); every other one is grey. Stepping onto it opens the 2x Money Game Pass purchase prompt, once per visit to the pad. It's the only place the pass is sold.
- From the farm panel a player can pick a placed freak back up into a free carry slot (to sell it or turn it in at a gate).
- Other players cannot interact with your farm.

### Offline earnings

- When the player leaves, save the timestamp.
- When they return, add half of `farm income per second × seconds away` to the uncollected pool, capped at the offline limit.
- The offline limit is money, not time: a share of the player's current ring's gear budget (section 7). It starts at 1/4, and the ring's two Offline Capacity levels raise it to 1/3, then 1/2 (`Economy.offlineBudgetShares`). Unlocking a new ring drops it back to 1/4, but of a budget about 20× bigger.
- With the section 7 farm, the 1/4 limit fills in about 15 min away in Ring 1 and about 2 h in Ring 5; the 1/2 limit in about 25 min and 4 h.
- Offline earnings are never doubled by the 2x Money pass.
- Show a "While you were away you earned $X" popup on join.

---

## 7. Shop

### Upgrades

Cost of the next level = `baseCost × growth ^ currentLevel`, rounded to the nearest dollar.

**Ring-priced upgrades** (Shoes, Hazmat Suit, Stronger Grip, Farm Capacity, Offline Capacity) unlock `levelsPerTier` levels per unlocked tier and are priced per ring (`Formulas.upgradeCost`):

- **Gear budget.** A ring's full set of Shoes, Hazmat and Grip levels costs `gearBudgetRate × tier base income × average incubators × pace seconds` (`Config/Economy`). Average incubators is the mean of the Farm Capacity cap before and after the ring (2→4 for Ring 1, 4→6 for Ring 2, and so on). Pace is 0.5 h for Ring 1, then N − 1 hours. `gearBudgetRate` is 7. At 5.5 it is tuned so a farm of about 65% Rare, 25% Epic and 10% Legendary freaks (at the `Config/Rarities` income multipliers: Rare ×3, Epic ×9, Legendary ×20), plus selling the rest, buys each ring's gear in its pace time without 2x Money. Raising it slows every ring down evenly.
- **Split.** Each gear upgrade's first level in a ring takes a share of the budget given by its `priceWeight` (Shoes 400, Hazmat 600, Grip 250), and each further level in that ring costs `growth` times more (×3, ×3, ×2). Rings where Shoes is already maxed split the budget between Hazmat and Grip.
- **Farm and Offline Capacity** are priced off the same budget with their own weights (500 ×2.5, and 1000 ×2) but aren't part of it, since they pay for themselves.
- **New rings** price themselves from their tier's base income: add the tier, then raise the max levels (Hazmat +3, Grip +5, Offline Capacity +2 per ring; Farm Capacity +2 once extra floors exist).

Simulated time to buy each ring's gear (that farm, greedy cheapest-first buying, about 4 freaks per run): at 7, Ring 1 32 min, Ring 2 70 min, Ring 3 2.4 h, Ring 4 4 h, Ring 5 5.4 h; at 5.5, 25 min, 55 min, 1.9 h, 3.1 h, 4.25 h. Changing rarity income multipliers changes farm income, so re-tune `gearBudgetRate` with them.

| Upgrade | Effect per level | Max level | Levels per tier | Ring 1 prices | Growth in ring | Last level |
|---------|------------------|-----------|-----------------|---------------|----------------|------------|
| Shoes | +4.2 walk speed (capped at 55) | 10 | 3 | 729, 2.19k, 6.56k | ×3 | 12.8M (Ring 4) |
| Hazmat Suit | Radiation damage ×0.76 | 15 (+3 per added ring) | 3 | 1.09k, 3.28k, 9.84k | ×3 | 2.89B |
| Stronger Grip | Grab hold time ×0.93 | 25 (+5 per added ring) | 5 | 455 … 7.29k | ×2 | 2.14B |
| Farm Capacity | Unlocks the next incubator | 14 (all 16 incubators by Ring 7) | 2 | 911, 2.28k | ×2.5 | 668M (Ring 5) |
| Offline Capacity | Offline limit 1/4 → 1/3 → 1/2 of the ring's gear budget | 10 (+2 per added ring) | 2 | 1.82k, 3.64k | ×2 | 1.07B (Ring 5) |
| Dash | Unlocks the dash (section 4) | 1 | Requires Shoes 10 | 32M (2.5× the last Shoes level) | — | 32M |
| Dash Recharge | −1 s dash cooldown (8 s → 3 s) | 5 | Requires Dash | 32M | ×3 | 2.59B |

Saves from before the 3-level change convert once on load (data version 2): Shoes and Hazmat levels × 3/5, rounded up, so Shoes 16 becomes 10 and keeps the Dash. Data version 3 adds 1 to Farm Capacity (the farm now starts with 2 incubators, so everyone keeps theirs) and cuts Offline Capacity to 2 × highest tier.

Shoes stops at 10 because level 10 reaches the 55 speed cap; past that, the Dash is how players keep getting faster. Levels a player already owns above their tier's cap (from before Farm and Offline Capacity were ring-priced) are kept; only buying is capped.

The first levels of each ring cost a few minutes of that ring's income; the last ones are the long goals. This is the main pacing lever.

### Items

Consumable. Bought at the shop. Price scales with the player's highest unlocked tier: `price = basePrice × 15 ^ (highestTier − 1)`. Players can hold up to 5 of each.

Items are used with dedicated buttons, not carry slots: Q for Net Launcher, R for Bear Trap, T for Golden Bear Trap, plus on-screen buttons for mobile.

**Rainbow and Radioactive freaks can only be trapped with the Golden Bear Trap.** Nets and plain Bear Traps ignore them (they can still be grabbed by hand).

| Item | Base price | Behavior |
|------|-----------|----------|
| Net Launcher | 100 | Fires at a target point up to 40 studs away. Instantly catches up to 3 freaks within 15 studs of the impact, limited by free carry slots, with no hold time. Works on Common, Uncommon, and Rare. Has no effect on Epic or Legendary. One use. |
| Bear Trap | 50 | Placed on the ground. The first freak to walk over it is pinned for 30 seconds. A pinned freak takes 0.5 seconds to grab regardless of tier or rarity, and only the trap's owner can grab it while pinned. The trap disappears after it triggers or after 120 seconds. One active trap per player: setting another removes the old one. Rainbow and Radioactive freaks walk over it. One use. |
| Golden Bear Trap | Robux only (Developer Product) | Gold and sparkling. Only Rainbow and Radioactive freaks trigger it; any in the trap's zone within 150 studs walk straight to it, and the first to arrive is pinned for 60 seconds (a 0.5-second grab for the owner). Never rusts, and only comes off the player's count when it pins a freak: setting it again moves it, and leaving with it set loses nothing. Its own slot, separate from the plain trap. |

### Selling

The **Sell** prompt at the sell counter opens the sell panel: the player's carried freaks with each one's price, sold individually or with "Sell all". Payout is the sum of the sell prices. The shop counter works the same way with a **Shop** prompt. Panels close with their X or when the player walks away, and the server refuses any sell, buy or place request made away from the counter or plot.

---

## 8. Progression gates

Each gate asks for a number of freaks of specific species. A freak counts if it is the required species at the required rarity or higher. Turn them in at the gate counter in the shop, from the carry slots or straight from the farm. Turned-in freaks are consumed.

The counts roughly double the freaks a player has to meet per gate (about 21, 42, 80 and 180), alongside gear costs that double per ring, for the doubling pace in section 1.

| Gate | Unlocks | Requirements |
|------|---------|--------------|
| 1 | Tier 2 (Ring 2) | 1× Uncommon Twitcher, 1× Rare Glowbug |
| 2 | Tier 3 (Ring 3) | 2× Rare Rustback, 2× Uncommon Gloomhound |
| 3 | Tier 4 (Ring 4) | 3× Rare Sludgelet, 3× Rare Hexwing, 2× Epic Bloatworm, 1× Legendary of any Ring 3 species |
| 4 | Tier 5 (Ring 5) | 5× Uncommon Voidmoth, 4× Rare Tri-Eye, 3× Epic Nightmare, 1× Legendary of any Ring 4 species |

A requirement can name several species (`species = { "Bloatworm", "Hexwing", "Sludgelet" }` in `Config/Gates.luau`); a freak of any of them counts.

**Release cap.** `Config/Release.luau` sets how many tiers a build includes (`releasedTiers`; currently 5, all rings open). The gate past it says its ring opens in a later update, and the daily wheel never gives freaks from past it.

**Measuring the pace.** Each player's play time and the play time at which they reached each tier are saved. Reaching a tier prints `[Progress] … reached tier N after X min played (Ring N−1 took Y min)` to the server log and sends a `ReachedTierN` custom analytics event (value: minutes played), visible in Creator Hub > Analytics. In Studio, `/progress` shows the same.

- The gate panel always shows the current requirements and which are done.
- Requirements can be turned in one at a time. Progress is saved.
- Ring 5 is the last ring at launch.

---

## 9. Daily wheel

Located in the shop. One free spin per UTC day. The player needs one free carry slot to spin. The prize freak goes into a carry slot when the wheel stops (7 seconds), and they place or sell it like any other. Until then the prize is saved, so leaving mid-spin or filling the carry bar while it turns never loses it: it arrives as soon as there's a free slot.

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

Build this last, after the loop is fun. Product and Game Pass IDs live in `Config/Products.luau`; negative IDs are placeholders until the products are created in Creator Hub (prices are set there, not in code). While an ID is a placeholder its Buy button explains that instead of opening a purchase prompt, and in Studio `/buy <goldenTrap|extraSpin|revive> [purchaseId]`, `/buypass money2x` and `/buyskin <key>` run the real grant code with a simulated purchase. Studio playtests don't check real Game Pass ownership (Roblox reports the creator as owning every pass) and don't apply the free-access whitelist unless `applyInStudio` is set in `Config/FreeAccess`, so the developer plays as a normal player; `/removepass <key>` takes a simulated pass back off the save.

| Product | Type | Behavior |
|---------|------|----------|
| 2x Money | Game Pass | Permanently doubles farm income and sell payouts (never offline earnings). Sold from the gold 2x Money pad beside each player's collection pad (section 6), not the shop. Shown as a "2x MONEY · ACTIVE" badge under the money display. |
| Golden Bear Trap | Developer Product | One Golden Bear Trap (section 7, Items). |
| Extra Wheel Spin | Developer Product | Grants one extra spin, usable immediately. |
| Incubator Skins | Game Pass per skin | Cosmetic only, no gameplay effect. Nine skins (Tech, Nature, Volcano, Ice, Royal, Void, Alien, Beach, Sakura); the equipped one rebuilds the owner's lab plot in its style (see "Incubator skins" below). A skin set can instead carry a character `look` (suit, boots, goggles, glow), which recolors the character. |
| Respawn with Caught Freaks | Developer Product | Offered for 10 seconds after dying while carrying at least one freak of any rarity. On purchase the player respawns at their farm still carrying everything. |

**Incubator skins.** Each skin is a complete 16-cell lab building from the art handover (`CatchAFreak_Incubators_Handover`), not a single incubator. Its two banks of 2×4 glass cells either side of a walkway match the plot's grid, so it replaces the whole plot:

- **Templates.** Each `.glb` is imported once in Studio (Import 3D, "Merge meshes" off), rigged with `Shared.Incubators.IncubatorRig` (materials, collisions, 16 slot attachments, lights and particles), and kept in `ServerStorage.IncubatorSkins` as `Incubator_<Skin>`. They live in the place file, not in Rojo. Rigging touch-ups made in Studio after `Rig.setup`: the importer's per-part wrapper models are flattened; columns and roof frame don't collide (their collision shapes swell into the walkway); cell glass and base trim use precise collision so steps are real steps.
- **On a plot** (`FarmService`): while the owner has a skin set with an `incubator` equipped, a copy is scaled so its base fills the 60-stud plot (about 0.82×, cells about 13 studs wide and 15 tall), stood on the plot facing the shop, and the default incubators and aisle are hidden. Each incubator number takes the skin cell in the same spot. Freaks stand on the cell's tile, sized to 85% of the cell height. The tile glows in the occupant's rarity color, the skin's own color when empty, and dark grey when locked. The owner sign rises above the skin's roof. Unequipping or leaving restores the default lab.
- **Fitting the plot.** The skin's lights are dimmed to 40% and kept within 16 studs, or they bleach the freaks. Players can walk the walkway: an invisible block over each bank keeps them out of the cells, a skin whose floor starts more than 0.6 studs up gets an invisible entrance ramp, and solid Ice parts get normal grip. The collection and 2x Money pads are lifted onto ground cover a skin spreads in front of the plot (Volcano, Void and Beach), so they stay visible.
- **Animations** (`IncubatorVfxController`, client): ornament spin and bob, neon breathing, lantern flicker and particle rates scaled by graphics quality, only for skins within 450 studs of the camera.
- **Performance.** Nature (~322k triangles) and Royal (~199k) are heavy; the others are 39k–162k. Eight players all on Nature would be about 2.6M triangles, so trim Nature's `Foliage` and Royal's `Decor_Small` parts if phones struggle.

**Free access (whitelist).** Players listed by User ID in `Config/FreeAccess.luau` (or owning its optional VIP Game Pass, `passId`, 0 for none) get, for as long as they're on the list:

- every Game Pass (2x Money and all skins) for free;
- the revive offer as usual, but taking it is free;
- Golden Bear Traps for in-game money, at 3× the Bear Trap's money price (up to 5 held), as well as for Robux;
- nothing on the daily wheel: no free or extra spins.

It's checked on every join and never saved, so removing someone from the list takes it away the next time they join. In Studio, `/freeaccess on|off` toggles it for the session.

Rules:

- Handle all Developer Products in a single `MarketplaceService.ProcessReceipt` callback. Grant the item, save, then return `PurchaseGranted`. Record processed purchase IDs so a receipt is never granted twice.
- **Paid wheel spins are "paid random items" under Roblox policy.** The wheel must show every possible outcome with its numerical odds before purchase. Check `PolicyService:GetPolicyInfoForPlayerAsync()` and hide the Extra Wheel Spin purchase when `ArePaidRandomItemsRestricted` is true. The free daily spin stays available to everyone. Reference: https://create.roblox.com/docs/production/monetization/paid-random-items

---

## 11. UI

| Screen | Contents |
|--------|----------|
| HUD | Money (a large glowing badge in the top-right corner, level with the Roblox top bar, that bumps and floats "+$X" on every gain), health bar, radiation warning while in a ring, item buttons with counts, dash button with its cooldown (once owned), 2x Money badge for pass owners |
| Carry bar | 9 slots along the bottom. Each filled slot shows the species icon with a rarity-colored border. This is a custom UI, not the Roblox backpack. Disable the default backpack. |
| Grab bar | Fills while holding a grab |
| Shop | Tabs: Upgrades, Items, Skins. Each row shows current level, effect, and next cost. |
| Sell panel | Carried freaks with sell price each, "Sell all" |
| Gate panel | The 2 required freaks, checkmarks for done ones, turn-in buttons |
| Farm panel | Placed freaks with income each, total income per second, capacity, place and pick-up buttons |
| Wheel | Opened by the Spin prompt at the wheel. A strip of prize segments sized by their odds, with a pointer that sweeps and lands on the result while the wheel in the shop spins; the odds table; spin button; time until the next free spin and any extra spins |
| Panel style | Every menu panel (shop, sell, farm, gate, wheel) is 440×540, docked right, with a header bar and border in its own accent color (shop blue, sell gold, farm green, gate purple, wheel pink; `UiKit.accents`) and a drop shadow. While any of them is open, items can't be used and the item and Dash buttons hide, so a tap meant for the panel can't set a trap. |
| Touch controls | On phones and tablets (`TouchLayout`) the thumb buttons gather on the right: a bigger jump button bottom right, Grab above it, a round Freakpedia book above that, and a column to their left with Net, Trap and Gold from the bottom up, then Dash. Sized in screen pixels (phone: 92 px jump/grab, 62 px items; tablet: 140 and 92) and not shrunk by the UI scaling that fits the rest of the HUD on small screens. Key hints are hidden. The Freakpedia book hides while a menu panel is open, since panels open on that side. In Studio, `/touchmode on|off` switches to this layout. |
| Popups | Offline earnings on join, revive offer on death, tier unlocked, Freakpedia page complete |
| Freakpedia | Opened by the book button on the left of the HUD (on touch devices, a round book on the right; see Touch controls) (which shows a "P" keycap on keyboards), or P. The panel can be dragged by its title bar and stays where it's put. A new entry (on incubating, turning in or selling a freak) floats "📖 New Freakpedia entry!" over the player's head. The red badge on the button's top-right corner counts entries waiting to be claimed, and each ring tab shows its own count. A tab per ring. Each species card shows its model (a black silhouette until collected), its name ("???" until then) and a pip per rarity, lit once claimed and half-lit while waiting. A card with waiting entries gets a gold border and a CLAIM +$reward button, which claims all of them and floats the reward over the player's head. The footer shows the page reward, the total bonus and pages complete. |

---

## 12. Technical rules

### Server authority

The server owns and validates everything that matters: money, health, radiation, grabs, carry slots, farm contents, upgrade levels, gate progress, wheel results, purchases. The client sends requests ("I want to buy Shoes") and the server decides. Never accept a value from the client (an amount, a price, a freak's tier or rarity).

### Freak performance

A full 5-ring map holds 770 freaks (about 2,600 at 10 rings), so ring count must not drive the cost:

- **Only rings near players are simulated.** A ring's freaks spawn (its full population at once) when any player comes within 60 studs of it, and all despawn once no player has been that close for 60 seconds. With 8 players, at most 8 rings are ever active and usually 2–3, so 10 rings cost about what 2–3 do. Despawning ends any traps and pins in that ring.
- **Planned for Rings 6+: activate by sector, not whole ring.** Outer rings are much longer (Ring 10 holds 448 freaks around a circle about 10,000 studs long) but players only use a small stretch of one. Split each ring into angular sectors about 300 studs long and spawn and despawn by sector, using the same rules as rings now. Sectors are a server-side cost saving only: freaks are shared, so every player near an active sector sees the same freaks, positions and rarities. A sector stays active while anyone is near it. Density is unchanged, so a ring feels the same.
- **Clients only animate nearby freaks**, within 300 studs; farther ones are left where they are. Workspace streaming keeps distant parts of the map off the client entirely.

- Freaks are anchored models with no `Humanoid`.
- The server does not move them every frame. For each freak it stores a current waypoint (start position, target position, start time, speed) and publishes it as attributes on the model whenever the waypoint changes.
- Each client moves the freak models locally by interpolating along the waypoint.
- When the server needs a freak's position (grab range, net radius, trap trigger), it calculates it from the same waypoint data.
- Keep `StreamingEnabled` on.

### Studio-only debug commands

For playtesting, available only when `RunService:IsStudio()` is true: set money, set highest tier, set any upgrade level, spawn a freak of a given tier and rarity next to the player. `/time day|dusk|night|dawn` jumps the day/night cycle for everyone. The full list is at the top of `DebugService.luau`. Use these to test Rings 2 and 3 before gates exist.

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
      FreeAccess.luau    whitelisted User IDs and their perks
      Biomes.luau        each zone's ground, walls and lighting
      DayNight.luau      day/night cycle lengths, sun times and the night look
      Freakpedia.luau    collection rewards
      Release.luau       how many tiers this build ships (rings past it stay locked)
      Sounds.luau        sound effect IDs and volumes
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
    ItemService.luau     net launcher, bear trap, golden bear trap
    GateService.luau     turn-ins, tier unlocks
    FreakpediaService.luau  new entries on incubating, claims and their rewards
    WheelService.luau
    MonetizationService.luau
    DebugService.luau    Studio-only commands
  client/            -> StarterPlayerScripts
    FreakRenderer.luau   moves freak models along their waypoints
    DoorController.luau  per-player door state
    BiomeController.luau per-zone lighting and the day/night cycle
    FreakpediaController.luau  the Freakpedia button and panel
    MoneyPadController.luau    styles the 2x Money pads, prompts the pass on your own
    FeedbackController.luau  grab/money sounds and sparkles, radiation geiger loop
    UiScaleController.luau   shrinks every ScreenGui on small (phone) screens
    Sfx.luau             plays one-shot sound effects
    one controller per UI screen in section 11
tools/               -> ServerStorage.Tools (Studio-only builders, never run in game)
  BuildMap.luau        walls, doors, shop, farm plots, lab floor
  BuildBiomes.luau     terrain, wall cladding, biome props
  BuildShowcase.luau   every freak on a stage above the lab, for thumbnails (delete Workspace.Showcase before publishing)
```

Run a tool from the edit DataModel with `require(game.ServerStorage.Tools.<Name>:Clone())`, then save the place.

All formulas live in `Formulas.luau` so the client can display the same numbers the server enforces.

### Saved data

One record per player, saved with **ProfileStore** (decided in Milestone 6) for session locking: a player's data is only ever open on one server, so fast rejoins and server hops can't duplicate or roll back progress. Autosave every 60 seconds; ProfileStore also saves when the player leaves and on server shutdown (`BindToClose`). ProfileStore is vendored in `src/server/Vendor/` (Apache-2.0, license in `third_party/ProfileStore/`). `lastSeen` is stamped on every save, so offline earnings work even after a crash.

```lua
{
  version = 1,
  money = 0,
  upgrades = { shoes = 0, hazmat = 0, grip = 0, farmCapacity = 0, offlineCapacity = 0 },
  items = { netLauncher = 0, bearTrap = 0, goldenTrap = 0 },
  highestTier = 1,
  gateProgress = { 0, 0 },           -- freaks turned in for each requirement of the current gate
  playSeconds = 0,                   -- total play time, for tuning the pace
  tierReachedAt = { ["1"] = 0 },     -- tier -> playSeconds when it was reached
  farm = {                            -- placed freaks
    -- { species = "Twitcher", tier = 1, rarity = "Uncommon", effects = {} },
  },
  uncollected = 0,
  lastSeen = 0,                       -- os.time() at last save
  wheel = { lastFreeSpinDay = 0, extraSpins = 0 },  -- plus pendingPrize while a spin's prize is on its way
  ownedPasses = {},                   -- gameplay Game Pass keys ("money2x"); re-checked on join
  ownedSkins = {},                    -- skin set keys; Game Passes are re-checked on join
  equippedSkin = "",                  -- "" for none
  processedReceipts = {},             -- last 50 purchase IDs
  freakpedia = {},                    -- species -> rarities claimed, e.g. { Glowbug = { "Common", "Rare" } }
  freakpediaPending = {},             -- incubated but not claimed yet, same shape
  freakpediaBackfilled = false,       -- old farm freaks were added as claimed (once)
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
| 8.5 | Dash | The Dash shows as locked until Shoes is 16, then costs 4× the last Shoes level. Owning it shows a dash button; F or the button bursts the player about 50 studs forward, stopped by walls and closed doors. The cooldown is 8 s and the server refuses early dashes. Each Dash Recharge level takes 1 s off, down to 3 s. |
| 9 | Monetization | All four products work in Studio test purchases. The revive is offered when dying with any freak and restores the full carry bar. A receipt replayed twice grants once. The paid spin is hidden when the policy check says restricted. |
| 10 | Polish | Real freak models, sounds, particles, UI pass, mobile controls check, economy tuning against the section 4 tuning target. |

---

## 14. After launch (not in version 1)

- **Status effects.** Freaks can carry effects such as Shocked, Frozen, or Flamed that raise their income multiplier. Effects come from changing environment conditions in the rings. The `effects` field and the multiplier hook in section 12 are there for this.
- More tiers beyond Ring 3
- Extra farm floors. Capacity reaches 16 at Ring 7; Ring 8 needs incubator 17. Each new floor adds 16 more incubators on the same footprint, built on a plot only once its owner can unlock one there. Keep the space above every plot empty for this.
- More or different rarities
- Radiation that ramps up the longer you stay in a ring
- Freaks that flee or fight back in higher tiers
- Trading or stealing between players
- A rebirth system
- Leaderboards