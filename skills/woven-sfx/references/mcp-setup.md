# MCP setup

Add the woven-sfx stdio MCP server to your agent config.

## Cursor / Claude Desktop

Add to `~/.cursor/mcp.json` or Claude Desktop MCP settings:

```json
{
  "mcpServers": {
    "woven-sfx": {
      "command": "npx",
      "args": ["-y", "woven-sfx-mcp"]
    }
  }
}
```

The MCP inherits your workspace cwd, so sounds land in the project by default.

## Optional: pin library path

Override where `.wav` files are stored:

```json
{
  "mcpServers": {
    "woven-sfx": {
      "command": "npx",
      "args": ["-y", "woven-sfx-mcp"],
      "env": {
        "WOVEN_SFX_LIBRARY": "assets/sfx"
      }
    }
  }
}
```

Or set `sfx-library` in `.claude/project.md` (same field `/edit-plan` and `/assemble` read):

```yaml
sfx-library: assets/sfx/
```

## Path resolution order

1. `WOVEN_SFX_LIBRARY` env var
2. `sfx-library` in nearest `.claude/project.md`
3. `./sounds/sfx/` under cwd

## Tools

| Tool | Purpose |
|------|---------|
| `sfx_search` | Search catalog by tag, transition, or query |
| `sfx_pull` | Download a sound by id to the project library |
| `sfx_resolve` | Resolve + pull the best sound for a transition |
| `sfx_list_installed` | List cached `.wav` files in the project library |

## Catalog

`https://sfx.woven.video/catalog.json`