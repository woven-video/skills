---
name: analyze-video
description: Analyze a video file to report its technical properties (duration, resolution, frame rate, codecs, bitrate), detect scene cuts, and summarize audio/visual content. Use when the user asks what's in a video, wants its specs, or needs a breakdown of its structure before editing.
---

# Analyze Video

Inspect a video file and produce a structured report of its technical properties, structure, and content.

## When to use

Use this skill when the user wants to understand a video before working with it — e.g. "what are the specs of this clip", "break down this video", "what's in this footage", or as a first step before trimming, transcoding, or editing.

## Prerequisites

Verify `ffprobe` and `ffmpeg` are available:

```bash
ffprobe -version >/dev/null 2>&1 && ffmpeg -version >/dev/null 2>&1 || echo "Install ffmpeg first (e.g. brew install ffmpeg)"
```

## Steps

1. **Confirm the input.** Get the absolute path to the video file. If none was given, ask for it.

2. **Extract technical metadata** with a single `ffprobe` JSON call:

   ```bash
   ffprobe -v quiet -print_format json -show_format -show_streams "$VIDEO"
   ```

   From the output, report:
   - Container/format and overall duration
   - Video stream: codec, resolution (width×height), frame rate, pixel format, bitrate
   - Audio stream(s): codec, sample rate, channels, bitrate
   - File size

3. **Detect scene cuts** (skip if the user only wants specs):

   ```bash
   ffprobe -v quiet -f lavfi -of csv=p=0 \
     -show_entries frame=pkt_pts_time \
     "movie=$VIDEO,select=gt(scene\,0.4)"
   ```

   Report the timestamps of detected cuts and the resulting number of scenes.

4. **Summarize content** (when the user asks "what's in it"):
   - Sample frames at even intervals: `ffmpeg -i "$VIDEO" -vf fps=1/10 -frames:v 8 /tmp/frame_%02d.png`
   - Describe the sampled frames to characterize the footage (setting, subjects, motion).
   - If audio matters, note whether speech or music is present.

5. **Produce the report.** Lead with a one-line summary (duration, resolution, fps, codec), then the detailed breakdown, then scenes/content if computed.

## Output format

```
analyze-video: clip.mp4
─────────────────────────────
Summary   00:01:32 · 1920×1080 · 30fps · h264/aac
Container mp4 · 48.2 MB
Video     h264, 1920×1080, 30fps, yuv420p, 4.1 Mb/s
Audio     aac, 48kHz, stereo, 128 kb/s
Scenes    7 cuts at 00:04, 00:11, ...
```

## Notes

- Always quote the file path to handle spaces.
- For large files, run metadata-only steps before any re-encode.
- Scene threshold `0.4` is a sensible default — raise it for fewer cuts, lower it for more.
