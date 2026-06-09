# Woven Video — Skills

Agent skills for working with video, by [Woven Video](https://github.com/woven-video).

Install with the [skills CLI](https://skills.sh):

```bash
npx skills add woven-video/skills
```

## Skills

| Skill | Description |
|-------|-------------|
| [`analyze-video`](skills/analyze-video/SKILL.md) | Analyze a video file — technical metadata, scene/cut detection, and content summary. |

## Layout

```
skills/
└── <skill-name>/
    └── SKILL.md
```

Each skill is a folder under `skills/` containing a `SKILL.md` (YAML frontmatter + imperative instructions). See [skills.sh](https://skills.sh) for the format.
