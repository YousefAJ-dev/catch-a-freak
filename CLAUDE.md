# Catch a Freak
Game design is in DESIGN.md. Read it before planning any feature.

- All Luau code lives in src and syncs to Studio through Rojo.
  Never create or edit scripts through the Studio MCP tools.
- Use the Studio MCP tools for building the map, inspecting the
  game tree, playtesting, and reading console output.
- After each feature, start a playtest, check the console for
  errors, and fix them before saying it's done.
- The server owns money, inventory, health, and catches. Never
  trust the client for these.