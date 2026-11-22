# Spike: ffmpeg.wasm HLS transcode in Chrome (VID-01 Task 0)

Throwaway. Not part of the app, not analysed by CI.

Pins: `@ffmpeg/ffmpeg 0.12.15`, `@ffmpeg/core 0.12.10` (single-thread, UMD, self-served from
`node_modules`, no COOP/COEP headers). Args mirror `tools/video-pipeline/ffmpeg.ts`; key + key-info
are written into the wasm FS, input is mounted with WORKERFS (no copy of the source into MEMFS).

```sh
npm i
node serve.mjs                          # http://localhost:8099
# manual: open it, pick a video, Transcode, then Verify (decrypts every segment with WebCrypto)
# headless (Chrome path hard-coded in drive.mjs):
node drive.mjs media/src_120s.mp4 save  # `save` writes outputs to out/wasm/
```

Test media (git-ignored, regenerate with local ffmpeg):
```sh
ffmpeg -f lavfi -i "testsrc2=s=1920x1080:r=30,noise=alls=12:allf=t" -f lavfi -i sine=f=440:r=44100 \
  -t 120 -c:v libx264 -preset ultrafast -b:v 4M -maxrate 5M -bufsize 8M -pix_fmt yuv420p -c:a aac -b:a 128k media/src_120s.mp4
```

Gotcha: `ffmpeg.writeFile` transfers (detaches) the Uint8Array. Pass `key.slice()` or the key is
zeroed in the caller (needed afterwards for the upload).
