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

## Layout

```
skills/
└── <skill-name>/
    └── SKILL.md
```

Each skill is a folder under `skills/` containing a `SKILL.md` (YAML frontmatter + imperative instructions). See [skills.sh](https://skills.sh) for the format.
