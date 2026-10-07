# Publishing checklist

Steps to take Catch a Freak live. The code is ready; these are the parts only
the owner can do in Studio and Creator Hub.

## 1. Save and publish the place

- [ ] In Studio, **File → Save to Roblox** (or Publish to Roblox). The map,
      terrain and biome props live in the place file, not in Rojo, so they
      only exist once saved.
- [ ] Make sure Rojo has synced first: the Rojo plugin shows Connected and
      the Output has no errors.

## 2. Create the products in Creator Hub

Open the experience in Creator Hub → **Monetization**.

**Developer Products:** create these three, then copy each ID into
`src/shared/Config/Products.luau` (replacing the negative placeholder):

| Key | Name | Suggested price |
|---|---|---|
| `money2x` | 2x Money (1 hour) | 49 R$ |
| `extraSpin` | Extra Wheel Spin | 25 R$ |
| `revive` | Respawn with Caught Freaks | 29 R$ |

**Passes:** create these three, then copy each ID into `passId` for the
matching skin set:

| Key | Name | Suggested price |
|---|---|---|
| `labCoat` | Lab Coat Set | 99 R$ |
| `toxic` | Toxic Set | 149 R$ |
| `gold` | Gold Set | 249 R$ |

Prices are set in Creator Hub, not in code. Each needs an icon (512×512); a
screenshot of a skin works for the passes.

## 3. Experience settings (Creator Hub → Configure)

- [ ] **Name, description, genre** and an **icon** (512×512) plus at least
      one **thumbnail** (1920×1080). In-game screenshots of the rings work
      well.
- [ ] **Maturity / content questionnaire:** fill it in. The game has
      cartoon creatures and no violence.
- [ ] **Devices:** Computer, Phone, Tablet (the UI scales down for phones).
- [ ] **Max players:** about 12. There are 8 farm plots, so more than 8
      players means some have no plot.
- [ ] **Security:** leave **Allow HTTP Requests** off (not used). Turn
      **Enable Studio Access to API Services** on only if you want to keep
      testing saves in Studio.

## 4. Test the live game before going public

Keep the experience **private** (or friends-only) at first and play it from
the Roblox app:

- [ ] Data saves: earn money, leave, rejoin, money is still there.
- [ ] Each Robux product: buy it once with a real account (the sale
      shows up in Creator Hub; you can refund test purchases there).
- [ ] Freak meshes load. If a freak shows as a plain colored ball, its mesh
      failed to load; tell Claude which one.
- [ ] Play a few minutes on a phone: the carry bar, item buttons and panels
      should fit and be tappable, and nothing should sit under the jump
      button.
- [ ] Debug chat commands (`/money`, `/tier` …) must do nothing outside
      Studio.

## 5. Go public

- [ ] Creator Hub → Configure → set the experience **Public**.

## Known limitations at launch

- These props are still built from plain shapes until better ones are
  generated (see `docs/generating-models.md`): hay bale, car wreck, rock
  formation, mossy log.
- Freak icons in menus are simple shape glyphs.
