# Generating models

The freaks and many props are AI-generated meshes from Roblox's mesh generator,
used through Studio's **Assistant**. Generations count against Roblox's own
daily Assistant limit, not against anything else.

## Steps

1. Open the **Assistant** in Studio (its button is in the top toolbar).
2. Type `Generate a 3D model of ...` followed by a prompt built from the
   template below. The model is inserted into Workspace near the camera; it
   can take a minute.
3. Generate **2 of each** and keep the better one. Results vary a lot.
4. Hand them over:
   - Put keepers in the `Workspace.PropPicks` folder.
   - Give them simple names: `DeadTree`, `HayBale`, `CarWreck`.
   - Delete the rejects and **save the place**.
   - Ask Claude to wire them in. That means making them matte, scaling them,
     and adding their mesh and texture IDs to `tools/BuildBiomes.luau` (props)
     or `src/shared/Config/Freaks.luau` (freaks). Once the IDs are in the
     code, the folder copies can be deleted.

Don't worry about size: models come out small and get scaled when they're
wired in.

## Prompt template (World of Warcraft style)

> `<object>` in World of Warcraft art style, hand-painted texture, angular
> faceted low-poly shapes, `<shape details>`, muted `<colors>`, matte, no
> shine, stylized fantasy game prop

For a creature, end with "stylized fantasy game creature" instead of "prop".

| Prop | Object, shape details and colors |
|---|---|
| Dead tree | Dead tree; gnarled trunk, sharp twisted bare branches; warm brown and grey |
| Hay bale | Round hay bale lying on its side; rough straw with a spiral end; dull gold and tan |
| Scarecrow | Scarecrow on a wooden post; burlap sack head, straw hat, tattered shirt; faded brown and blue |
| Car wreck | Rusted abandoned car wreck; crushed roof, missing wheels, holes; rust orange and grey |
| Rock formation | Wide flat-topped desert mesa; layered cracked sandstone; dusty red and tan |
| Swamp tree | Dying swamp tree; twisted trunk, flared roots, hanging moss, few leaves; murky olive and dark brown |
| Mossy log | Long fallen rotten log; broken ends, moss on top; dark brown and olive |
| Crystals | Crystal cluster; sharp jagged shards from a rock base; muted purple and teal |
| Stalagmite | Cave stalagmite; tall sharp rock spike, layered ridges; dark slate grey |
| Mushrooms | Cluster of cave mushrooms; three heights, ragged caps; pale stems, muted teal caps |
| Chemical tank | Industrial chemical tank; riveted metal panels, ladder, pipes, hazard stripe; worn grey and yellow |
| Toxic barrel | Dented toxic barrel; radiation symbol, dripping goo; faded yellow and toxic green |

## Still needed

These props are still built from plain shapes, because their generated
versions missed:

- **Hay bale:** came out with magenta bands.
- **Car wreck:** came out as a shiny new sports car.
- **Rock formation:** came out as a tall pillar.
- **Mossy log:** came out tiny.

The generated dead tree, swamp tree, scarecrow, crystals, stalagmite,
mushrooms, chemical tank and toxic barrel are in use, but they're in the
older, softer style. The dead tree is the only one in the World of Warcraft
style. Regenerating the rest with the template would make the style
consistent.

## Tips

- One object per prompt, and say how it sits ("lying on its side", "on a
  wooden post").
- Name the colors explicitly; the generator defaults to bright saturated ones.
- Moderation rejects some words. "Fangs", "skull", and fire or flame words
  ("blazing", "fire spirit") have all failed. "Glowing", "toxic" and
  "radioactive" are fine.
- Generated models face -Z (the front), which is what the game expects.
