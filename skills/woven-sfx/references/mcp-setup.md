# MCP setup

Required for `sfx_search`, `sfx_pull`, `sfx_resolve`, and `sfx_list_installed`. The skill install does not add MCP automatically.

## Cursor

Add to `~/.cursor/mcp.json` (global) or `.cursor/mcp.json` (project):

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

Merge into existing `mcpServers` if the file already has other servers. Restart Cursor.

## Claude Code

Add to `.mcp.json` in your project root (merge if the file exists):

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

Restart Claude Code in that project.

## Claude Desktop

Open **Settings → Developer → MCP** and add a custom server:

```json
{
  "command": "npx",
  "args": ["-y", "woven-sfx-mcp"]
}
```

Restart Claude Desktop.

## Verify

Confirm `sfx_resolve`, `sfx_pull`, `sfx_search`, and `sfx_list_installed` appear in your agent's MCP tool list before running `/edit-plan` SFX steps.

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

## Catalog

`https://sfx.woven.video/catalog.json`
