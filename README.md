# ffmpeg.wasm Editor

A browser-based video editor powered by [ffmpeg.wasm](https://github.com/ffmpegwasm/ffmpeg.wasm). <b><ins>No uploads, no servers -- all processing happens locally</ins></b> in your browser using WebAssembly.

---

## Use Cases

### 🎞 GIF Maker
Convert any video clip into an animated GIF. Set the frame rate and output width; height scales automatically to preserve the aspect ratio. Uses a two-pass palette generation for the best possible colour quality.

### 🔄 Video Format Converter
Re-encode a video to a different container and codec:
- **MP4** -- H.264 + AAC, widest compatibility
- **WebM** -- VP9 + Opus, open format optimised for the web (~45% smaller than MP4 at similar quality)
- **MKV / MOV** -- H.264 + AAC in alternative containers
- **AVI** -- legacy compatibility

### 🗜 Video Compression
Reduce file size without changing the resolution. Dial in the quality with a **CRF slider** (18 = near-lossless → 51 = maximum compression) and pick an encoding **preset** (ultrafast → veryslow) to trade encoding speed for compression efficiency. A live size estimate updates as you adjust the settings.

### ✂️ Video Trimming
Set a start and end point with the timeline sliders before running any operation. Trimming is applied on top of every other operation, so you can, for example, extract a short clip, compress it, and convert it to GIF all at once.

### 📐 Resize & Compress
Change the output dimensions and compress in one pass. Width and height are auto-filled from the source video; edit either value or leave it blank to let ffmpeg maintain the aspect ratio. Combines a `scale` filter with CRF-based H.264 encoding.

### 🎵 Audio Extraction
Pull the audio track out of any video into a standalone audio file:
- **MP3** -- universal playback
- **AAC** -- efficient lossy, great for mobile
- **WAV** -- uncompressed PCM
- **OGG Vorbis** -- open lossy format
- **FLAC** -- lossless compression

### 🔇 Mute Video
Strip the audio stream entirely. Output is the original video with no audio track -- useful for silent loops, social media clips, or before replacing the audio elsewhere.

### ⚡ Speed Change
Speed up or slow down playback (0.25× – 4×). Both the video PTS and the `atempo` audio filter chain are adjusted so audio pitch and sync are preserved. Chains multiple `atempo` stages automatically when the multiplier is outside the 0.5–2.0 range that a single filter accepts.

### 🔄 Rotate / Flip
Correct orientation or create mirror effects without re-uploading. Options: 90° clockwise, 90° counter-clockwise, 180°, flip horizontal, flip vertical, or flip both axes.

### ✂️ Crop
Trim the frame to a specific region. X/Y offset and width/height are auto-filled from the source video dimensions so you can immediately drag values down rather than starting from scratch.

### 🖼 Thumbnail Extractor
Pull a single frame from any point in the video and save it as a **JPEG** or **PNG** image. The timestamp field is pre-filled to the midpoint of the loaded clip.

### ⏪ Reverse
Play the video (and audio) backwards using ffmpeg's `reverse` + `areverse` filters.

### 🌅 Fade In / Out
Add a smooth fade-in, fade-out, or both. Set the duration in seconds for each direction independently; the filter is applied after any trim.

### 🎨 Adjust (Brightness / Contrast / Saturation)
Fine-tune the look of a clip with the `eq` filter. Three sliders control brightness (−1 → 1), contrast (0 → 2), and saturation (0 → 3). A **Grayscale** checkbox pins saturation to zero for instant black-and-white output.

### 🚫 Strip Metadata
Remove all embedded metadata -- GPS coordinates, camera make/model, creation timestamps, and any other tags -- before sharing a file. Uses `-map_metadata -1` during re-encoding.

### 📝 Embed Subtitles
Mux an `.srt`, `.vtt`, or `.ass` subtitle file into the video as a **soft subtitle track** -- toggleable on/off in any media player (VLC, browser, etc.) without re-encoding the picture. Output format choices:
- **MP4** -- subtitle stream encoded as `mov_text`
- **MKV** -- subtitle stream copied natively (preserves ASS/SSA styling)

Video and audio are stream-copied (zero quality loss, near-instant). Hard-burning subtitles into the picture requires a libass-enabled ffmpeg build and is not available in the standard WebAssembly core.

### 🛠 Raw FFmpeg
Full access to the ffmpeg command line directly in the browser. Type any arguments into the text area; they are inserted after `-i input` and before the output filename. Choose the output file extension and optionally bypass the trim range. A live **full command preview** updates as you type, showing the exact command that will be executed. Quoted values containing spaces are handled correctly.

An **Example Commands** library (collapsible) provides one-click recipes to get started:

| Example | What it does |
|---|---|
| 🔲 Color-bar watermark | Semi-transparent `drawbox` stamp in the bottom-right corner |
| 🎞 Cap framerate to 24 fps | `fps=24` filter + H.264 re-encode |
| 🎨 Convert to grayscale | `format=gray` + H.264 re-encode |
| 🔊 Loudness normalize | `loudnorm` filter, stream-copies video |
| 📦 Lossless remux (copy) | `-c copy` — change container, zero quality loss |
| 📐 Letterbox / pillarbox | Scales to 1920×1080, pads with black bars |
| 🌀 Denoise (hqdn3d) | Temporal + spatial denoising |
| 🔍 Sharpen (unsharp) | `unsharp` mask filter |
| 🎯 Stabilize (deshake) | `deshake` motion stabilization |
| 🌑 Vignette effect | `vignette` filter darkens edges |
| 🔇 Extract audio as WAV | `-vn -acodec pcm_s16le` lossless audio export |
| 🖼 Extract first frame | `-vframes 1` saves a single PNG |
| 🎵 Replace audio track | Strips original audio and muxes in `input2.mp3`; uses `-map 0:v:0 -map 1:a:0 -shortest` |

Clicking a recipe fills in the arguments and extension fields instantly.

> **Second input file** — the Raw FFmpeg panel includes an optional *Choose file* picker. The selected file is written to ffmpeg's virtual filesystem as `input2.<ext>` and can be referenced in your arguments (e.g. `-i input2.mp3`). Required by the *Replace audio track* recipe.

---

## How It Works

1. Click **Load ffmpeg** -- downloads the ffmpeg-core WebAssembly binary (~31 MB, cached after first load).
2. Drop or select a video file. The **Process Video** button activates; if ffmpeg is not yet loaded it reads **Load ffmpeg & Process** and will download it automatically on first click.
3. Optionally set trim points with the timeline sliders.
4. Pick an operation and adjust its settings. A **live size estimate** updates as you change parameters.
5. Click **Process Video** -- ffmpeg runs entirely in a Web Worker inside your browser.
6. Preview the result (video, audio player, or image depending on the operation) and download it.

All file I/O stays on your machine. Nothing is sent to any server.

---

## Running Locally

```bash
git clone https://github.com/tejaswigowda/ffmpeg.wasm.editor.
cd ffmpeg.wasm.editor
node server.js          # serves docs/ with the required COOP/COEP headers
```

The server sets `Cross-Origin-Opener-Policy: same-origin` and `Cross-Origin-Embedder-Policy: require-corp`, which are required for `SharedArrayBuffer` (used by ffmpeg.wasm).

Or serve the `docs/` folder with any static server that sets those two headers.
