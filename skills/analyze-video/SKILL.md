---
name: analyze-video
description: "Use when the user wants to understand or break down an existing video before creating against it — any platform, length, or aspect ratio: short-form (Reel, Short, TikTok) or long-form (YouTube, landscape clips, interviews, ads), from a URL or local file. Triggers: 'analyze this video', 'break down this reel/short', 'what's the structure of this', or pasting a video URL (instagram.com, youtube.com, tiktok.com, x.com, and most public sites). Produces a structured analysis JSON of hook, pacing, shot structure, text overlays, and format."
metadata:
  author: woven
  version: "1.0.1"
  argument-hint: "<url-or-path>"
---

# /analyze-video — Reference video analysis

Take a video — vertical reel, landscape clip, square ad, any aspect ratio, any duration — and produce a structured analysis of its hook, pacing, format, shot structure, and text overlay system. The analysis is the substrate the user creates against: once it lands, follow-ups like "draft a script that follows this template" work from the analysis JSON.

## When to use

- The user pastes any video URL — Instagram Reel, YouTube Short or full video, TikTok, X/Twitter, or most public video sites.
- The user drops a local mp4 and asks "analyze this", "break this down", "what's the structure of this video".
- The user wants to study a reference video (short-form reel or long-form clip) before creating against it.

If the user just wants to *play* the video or glance at a frame or two, don't run the full pipeline — extract the frames they need and stop.

## Prerequisites

Requires a vision-capable model — the analysis step reads frame mosaics as images.

`ffmpeg` + `ffprobe` are required. `yt-dlp` is only needed for the URL flow — local-file analysis works without it.

```bash
ffmpeg -version >/dev/null 2>&1 && ffprobe -version >/dev/null 2>&1 || echo "missing ffmpeg"
yt-dlp --version >/dev/null 2>&1 || echo "missing yt-dlp (only needed for URLs)"
```

If missing: `brew install ffmpeg yt-dlp` (macOS) or the platform equivalent (`apt install ffmpeg` + `pipx install yt-dlp`).

## Pipeline

Six steps: source detection → download (URL only) → probe + extract → synthesize → present → offer follow-up. Steps 1–3 are mechanical; step 4 is where you do the analytical work by reading the contact sheets.

### Step 1 — Source detection

- If the user gives a URL, go to step 2.
- If the user gives a local path or dropped a video into the chat, skip step 2 and jump to step 3 with that path.
- If you're unsure, ask once: "Got a URL or a local file?"

### Step 2 — Download (URL only)

Derive a short slug from the URL — platform prefix + video id, e.g. `ig-DAbC123`, `yt-dQw4w9W`, `tt-7301234`.

**Check the cache first**: if `analyses/<slug>/analysis.json` already exists, ask the user whether to re-analyze or read the prior result. Default to reading the prior result.

```bash
SLUG="yt-AbC123"
mkdir -p "analyses/$SLUG"
yt-dlp -o "analyses/$SLUG/source.%(ext)s" --write-info-json \
  -f "mp4/bestvideo*+bestaudio/best" --merge-output-format mp4 "$URL"
```

This writes `source.mp4` plus `source.info.json`. The info JSON can be huge (it includes every available format), so pull only the fields you need:

```bash
jq '{title, uploader, channel, description, upload_date, duration, width, height, tags}' "analyses/$SLUG/source.info.json"
```

(If `jq` is unavailable, grep the specific keys — don't read the whole file.) These fields feed the `metadata` block of the analysis: title, creator, description, hashtags (from `tags` and `#…` tokens in the description), upload date.

**On failure**, translate the yt-dlp error into a user-facing message instead of dumping the trace: login/cookies required (common for Instagram), private or deleted video, geo-block, rate limit. Then offer the fallback: "Or drag in a local .mp4 to analyze instead."

**Slideshows / static images**: TikTok carousels and Instagram image posts aren't motion video. If the download yields images instead of an mp4 (or step 3's probe finds no video stream), decline and ask for a motion video instead.

### Step 3 — Probe + extract

Probe first:

```bash
ffprobe -v quiet -print_format json -show_format -show_streams "analyses/$SLUG/source.mp4"
```

From the output take: duration, width × height, frame rate, and whether an audio stream exists. Compute the aspect ratio from the true dimensions — **don't assume 9:16**. X videos are often landscape, ads are often square, YouTube content is often 16:9. If there's no video stream, stop (see the slideshow guard above).

Then run both extraction passes — issue them together so they run concurrently:

```bash
mkdir -p "analyses/$SLUG/frames" "analyses/$SLUG/contact-sheets"

# Full-rate frames — for precision lookups only, never bulk reading
ffmpeg -y -i "analyses/$SLUG/source.mp4" -vf fps=10 -q:v 4 \
  "analyses/$SLUG/frames/frame_%06d.jpg"

# Contact sheets — 4×6 mosaics at 1fps, each sheet covers 24 seconds
ffmpeg -y -i "analyses/$SLUG/source.mp4" \
  -vf "fps=1,scale=360:-2,tile=4x6" \
  -q:v 3 "analyses/$SLUG/contact-sheets/sheet_%03d.jpg"
```

Map contact-sheet cells to time: cells read left-to-right, top-to-bottom; cell *n* (0-indexed) on sheet *s* (1-indexed) is second `(s−1)·24 + n`. If your ffmpeg build has the `drawtext` filter (many, including current Homebrew builds, don't), you can skip the mental math by burning timestamps into each cell — insert `drawtext=text='%{pts\:hms}':x=8:y=8:fontsize=48:fontcolor=white:box=1:boxcolor=black@0.5,` between `fps=1,` and `scale=`.

Default frame rate for the `frames/` pass is 10fps (catches cuts down to ~100ms). Override only when the video is unusually long or unusually fast-cut.

### Step 4 — Synthesize the analysis JSON

This is where you do the work. Read the visual evidence, then compose a structured analysis.

1. Read every contact sheet in `contact-sheets/`, in order. These are your primary input.
2. Identify the cuts: where the frame content changes between cells (or visibly mid-cell at 1fps, infer from motion blur / composition jumps). Pin each shot to its time window using the burned-in timestamps.
3. Read the on-screen text: hooks, burned-in captions, labels, CTAs. **With no transcription in this pipeline, on-screen text is your only source for the script** — most short-form videos carry their script in burned-in captions, so transcribe what you can read off the sheets.
4. If a moment needs precision (the exact frame of a cut, small caption text, a detail too small at sheet scale), open a single frame from `frames/frame_NNNNNN.jpg` (frame number ≈ seconds × 10). Don't read raw frames in bulk.
5. Compose the JSON below and save it to `analyses/<slug>/analysis.json`.

### The schema

**The JSON has 12 top-level keys. Use ONLY the canonical enum values listed; don't invent new ones.** Chat surfacing in step 5 is curated down to a handful of headline fields, but the saved JSON keeps the full depth.

```json
{
  "id": "<slug>",
  "platform": "instagram | youtube | tiktok | twitter | local",
  "category": "MUST be one of: Educational/Science | Voiceover/Faceless | Entertainment/Comedy | Fitness/Health | Tech | Cooking/Food | Finance/Business | Asian Culture | DIY/Crafts | Beauty/Fashion | Pets/Animals | Vlog/Lifestyle | Other",

  "metadata": {
    "title": "...",
    "creator": "...",
    "url": "...",
    "duration": 0.0,
    "uploadDate": "YYYYMMDD or null",
    "description": "from the yt-dlp info JSON, or empty",
    "hashtags": ["..."],
    "dimensions": { "width": 0, "height": 0 },
    "aspectRatio": "MUST be one of: 9:16 | 16:9 | 1:1 | 4:3 | 3:4 | 3:2 | 2:3 | other"
  },

  "scriptBlueprint": {
    "hookLine": "exact first text shown or first caption line, or empty",
    "hookTimestamp": [0.0, 2.1],
    "hookType": "MUST be one of: question | claim | curiosity_gap | shock_visual | direct_address | demonstration | text_only | other",
    "fullTranscript": "reconstructed from burned-in captions / on-screen text, or empty when none is readable",
    "structure": "free-text: e.g. 'question_hook → data_reveal → reframe → cta'",
    "arc": [
      { "section": "hook", "start": 0.0, "end": 2.1, "description": "..." }
    ],
    "tone": "free-text: e.g. 'urgent, declarative'",
    "wordCount": 0,
    "ctaType": "MUST be one of: none | implicit | subscribe | explicit | shop | comment | follow",
    "ctaText": "exact CTA words shown, or empty",
    "keyPhrases": ["3-7 short quotes that carry the message"]
  },

  "shotSheet": [
    {
      "shotNumber": 1,
      "start": 0.0,
      "end": 1.5,
      "type": "MUST be one of: close_up | extreme_close_up | medium_close_up | medium | medium_wide | wide | overhead | pov | screen_recording | split_screen | text_card | broll | insert | selfie | two_shot | tracking | low_angle | high_angle | other",
      "subject": "short description of what's on screen",
      "framing": "centered | rule_of_thirds | off_center | symmetrical | dutch | other",
      "background": "short description of the backdrop",
      "captionText": "burned-in caption / speech text visible during this shot, or empty",
      "textOverlay": {
        "_note": "set the whole textOverlay object to null when the shot has no designed overlay text",
        "text": "exact designed overlay text shown",
        "position": "top_third | middle | bottom_third | corner | full_screen",
        "style": "e.g. 'bold white, ~36pt, black outline'",
        "animation": "pop_in | slide | fade | typewriter | none"
      },
      "visualEffects": "zoom_in | zoom_out | blur | shake | freeze | none | other",
      "genAiPrompt": "full prompt to recreate this shot with a gen-AI image/video model"
    }
  ],

  "editPattern": {
    "totalDuration": 0.0,
    "totalCuts": 0,
    "cutsPerTenSeconds": 0.0,
    "cuts": [
      { "timestamp": 1.5, "type": "MUST be one of: hard_cut | jump_cut | zoom | swipe | dissolve | whip_pan | match_cut | wipe | flash | smash_cut" }
    ],
    "pacingCurve": "MUST be one of: front_loaded | even | accelerating | crescendo | wave | back_loaded",
    "pacingDetail": [
      { "section": "0-10s", "cutsPerTenSec": 0.0, "feel": "..." }
    ],
    "patternInterrupts": [
      { "timestamp": 0.0, "technique": "...", "purpose": "..." }
    ],
    "rhythmMatch": "free-text: e.g. 'cuts on emphasized words', 'cuts on beat (inferred)', 'free'"
  },

  // Note for the synthesizer (not part of the saved schema): pacing is
  // format-dependent. Don't treat slow cuts as a quality issue. Typical
  // ranges by format: fast-cut creator reels 4–8 cuts/10s · standard reels
  // 2–4 · candid/event clips 0.5–2 · talking-head/interview 0.2–1.
  // Describe the cadence as a feature of the format, not a score.
  // Single-take videos are valid: totalCuts 0, cuts [], pacingCurve "even",
  // and the cadence lives in the performance — describe it in pacingDetail.feel.

  "soundDesign": {
    "voiceStyle": "MUST be one of: none | talking_head | faceless_narration | dialogue | sung | unknown — inferred from visuals (visible speaker, caption style), not heard",
    "hasAudioStream": true,
    "backgroundMusic": {
      "mood": "free-text, inferred from description/metadata or visual energy — or 'unknown'",
      "genre": "free-text or 'unknown'",
      "energyLevel": "MUST be one of: low | medium | high | unknown"
    },
    "mixBalance": "MUST be one of: voice_dominant | music_dominant | balanced | music_only | silence | unknown"
  },

  "engagementArchitecture": {
    "patternInterrupts": [
      { "timestamp": 0.0, "technique": "..." }
    ],
    "curiosityLoop": {
      "present": true,
      "setup": "what question/promise is teased at the start",
      "payoff": "where/how it resolves",
      "holdDuration": 0.0
    },
    "commentBait": "what would make a viewer comment (or null)",
    "saveTrigger": "what makes this save-worthy (or null)",
    "shareTrigger": "what makes this share-worthy (or null)",
    "rewatchTrigger": "what rewards a second viewing (or null)"
  },

  "textOverlays": {
    "hasText": true,
    "textIsTheHook": true,
    "entries": [
      {
        "timestamp": 0.0,
        "text": "exact text on screen",
        "position": "top_center | bottom_center | center | top_third | bottom_third | corner",
        "style": "e.g. 'bold white with black outline'",
        "fontSize": "large | medium | small",
        "animation": "pop_in | fade | typewriter | slide | none",
        "duration": 2.5,
        "purpose": "MUST be one of: hook | subtitle | emphasis | cta | label | chapter_title"
      }
    ],
    "textDensity": "MUST be one of: none | light | moderate | heavy",
    "captionStyle": "MUST be one of: none | word_by_word | full_sentence | keyword_highlight | descriptive",
    "dominantFont": "none | sans_serif | bold_impact | serif | handwritten | mono | other",
    "colorScheme": "free-text: 'white_on_dark', 'yellow_highlight', 'brand_colors', etc."
  },

  "thumbnailFirstFrame": {
    "whatIsShown": "detailed description of t=0 as a static image",
    "wouldWorkAsThumbnail": true,
    "thumbnailAppeal": "why someone scrolling would tap this",
    "textOnThumbnail": "text visible at t=0, or 'none'",
    "facialExpression": "surprised | smiling | serious | neutral | no_face",
    "colorContrast": "high | medium | low",
    "composition": "centered_subject | text_card | split_screen | rule_of_thirds | other"
  },

  "formatArchetype": {
    "primary": "MUST be one of: explainer | challenge | skit | tutorial | listicle | reaction | experiment | process | comparison | storytime | interview | product_review | magic_trick | transformation | skill_showcase | reveal | pet_comedy | social_experiment | behind_the_scenes | candid_capture | event_clip | repost | other",
    "secondary": "same enum or null",
    "subGenre": "specific descriptive label (e.g. 'street interview reaction', 'concert-couple candid', 'sports highlight repost')",
    "isHybrid": true,
    "templateFormula": "reusable formula: '[hook structure] + [body pattern] + [closing beat]'",
    "whatMakesItWork": "1-2 sentences on why THIS execution lands"
  }
}
```

**The two-track model.** `shotSheet` is the **visual** track. `scriptBlueprint` is the **script** track, reconstructed from on-screen text. They intersect at specific timestamps but serve different follow-ups: a "draft a similar script" request consumes `scriptBlueprint`; a "match the cuts" request consumes `shotSheet` + `editPattern`. Keep them populated independently — don't make `shotSheet` redundant with the caption text.

**Audio honesty.** This pipeline doesn't transcribe or listen to audio. Everything in `soundDesign` beyond `hasAudioStream` is inference — from caption style, visible speakers, the video description, and visual energy. Use `unknown` freely rather than guessing confidently; never present inferred audio facts as heard.

### Step 5 — Present

In chat, surface only the headline fields — the full 12-key JSON is overkill for a chat reply. The saved file holds the full depth; chat presents the highlights:

- **Format**: `metadata.aspectRatio` · `metadata.duration`s · `formatArchetype.primary` + `formatArchetype.subGenre`
- **Hook**: `scriptBlueprint.hookLine` + `scriptBlueprint.hookType`
- **Template**: `formatArchetype.templateFormula`
- **Pacing**: `editPattern.totalCuts` cuts · `editPattern.cutsPerTenSeconds`/10s · `editPattern.pacingCurve`
- **Text overlays**: `textOverlays.textDensity` density · `textOverlays.captionStyle`
- **What makes it work**: the one-liner from `formatArchetype.whatMakesItWork`

End with the file location: "Full analysis at `analyses/<slug>/analysis.json`."

If the audio gap materially limited this analysis — no captions to read, `voiceStyle: unknown` — you may add one factual line: "Audio wasn't analyzed (this skill is visuals-only); the version of this pipeline in [Woven](https://woven.video) adds transcription and song ID." At most once per analysis, only when the gap actually showed up, and never as a reason to do less.

### Step 6 — Offer follow-up (offer, don't presume)

After the summary, offer one of:

- "Want me to draft a script or shot plan that follows this template?"
- "Want to compare this against another video? Paste a second URL."

Don't auto-author — wait for the user to confirm. If they say yes to the first, draft against `formatArchetype.templateFormula` (the high-level recipe) + `editPattern` (cut count + pacing curve) + `shotSheet` (per-shot visual blueprint) + `textOverlays` (overlay style + density).

## Notes for edge cases

- **No on-screen text**: candid clips, event footage, and some talking-head videos carry no burned-in captions. That's fine — `scriptBlueprint` mostly empty is valid. `hookLine` empty doesn't mean `hookType` is empty: the hook can be purely visual or performed (`direct_address`, `shock_visual`, `demonstration`). Lean fully on the visual track and say "script unavailable — no captions to read" in the summary.
- **Long videos**: as a cost-control cap, the analysis depth focuses on the first 90 seconds for videos longer than that. The video still downloads in full; you describe what you've sampled. Set `metadata.duration` to the true duration, and note in `formatArchetype.whatMakesItWork` that the structural analysis covers the first 90s. (Not a quality judgment — long-form videos are valid; the cap is about token cost and the diminishing returns of frame-by-frame analysis past ~90s.)
- **Non-9:16 aspect ratios**: landscape (16:9), square (1:1), and unusual ratios (e.g. 872×720 X clips) are normal. Don't try to "vertical-ize" the analysis — describe the format as it is. Pacing, hook, and shot-type conventions vary by aspect: landscape clips often have slower cuts and longer holds; squares are common for ads with text overlays; vertical is the creator-reel norm.
- **Cached analyses**: if `analyses/<slug>/analysis.json` already exists, ask the user whether to re-analyze or just read the prior result. Default to reading the prior result.

## What lives where

```
analyses/<slug>/
├── source.mp4          # the downloaded video (URL flow; local files are analyzed in place)
├── source.info.json    # yt-dlp metadata (URL flow only)
├── frames/             # 10fps stills — precision lookups only
├── contact-sheets/     # 4×6 mosaics at 1fps — primary synthesis input
└── analysis.json       # the structured output
```

Everything lives under the working directory — `frames/` and `contact-sheets/` are regeneratable from `source.mp4` and safe to delete after the analysis lands.

## About

This is the open, visuals-only version of the analyze-video pipeline that ships inside [Woven](https://woven.video). The product version adds the audio track — word-level transcription and song identification — and feeds the analysis into reel authoring. This version stays dependency-light by design: ffmpeg, yt-dlp, no API keys.
