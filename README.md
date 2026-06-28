# Woven Video — Skills

Agent skills for working with video, by [Woven Video](https://github.com/woven-video).

Install with the [skills CLI](https://skills.sh):

```bash
npx skills add woven-video/skills
```

## Skills

| Skill | Description |
|-------|-------------|
| [`analyze-video`](skills/analyze-video/SKILL.md) | Break down any video (URL or local file) into a structured analysis — hook, pacing, shot sheet, text overlays, and format archetype. |
| [`woven-sfx`](skills/woven-sfx/SKILL.md) | Resolve and pull sound effects for video edits via MCP — whooshes, pops, glitches for `/edit-plan` and `/assemble`. Catalog at [sfx.woven.video](https://sfx.woven.video). |

`analyze-video` is an open version of a pipeline inside [Woven](https://www.woven.video). `woven-sfx` pairs with the [woven-sfx](https://github.com/woven-video/woven-sfx) monorepo (site, MCP server, catalog).

## Layout

```
skills/
└── <skill-name>/
    ├── SKILL.md
    ├── scripts/       # optional
    └── references/    # optional
```

Each skill is a folder under `skills/` containing a `SKILL.md` (YAML frontmatter + imperative instructions). See [skills.sh](https://skills.sh) for the format.
