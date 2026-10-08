// Video pipeline (ADR-002): source .mp4 → AES-128 encrypted HLS (720p + 480p), one key per video.
//
//   deno run -A tools/video-pipeline/package.ts <input.mp4> <assetId> [--out <dir>] [--upload]
//
// Writes <out>/<assetId>/ (playlists + encrypted .ts segments) and <out>/<assetId>.key.hex.
// The key file is NEVER uploaded: it goes to private.video_keys (SEC-01) and is served only by
// video-otp. --upload pushes the <assetId>/ folder to R2 under videos/<assetId>/ and needs
// R2_ACCOUNT_ID, R2_ACCESS_KEY_ID, R2_SECRET_ACCESS_KEY, R2_BUCKET in the environment.
// Spike quality (docs/superpowers/specs/2026-10-08-adr002-hls-spike-design.md).
import { AwsClient } from 'npm:aws4fetch@1.0.20';
import { join } from 'jsr:@std/path@1.1.4';

const SEGMENT_SECONDS = 6;
// The playlists reference the key by this relative URI; the server serves it next to them.
const KEY_URI = 'key';
const RENDITIONS = [
  { name: '720p', height: 720, videoKbps: 2800, maxKbps: 3000 },
  { name: '480p', height: 480, videoKbps: 1200, maxKbps: 1300 },
] as const;

function parseArgs(args: string[]) {
  const positional: string[] = [];
  let out = 'out/videos';
  let upload = false;
  for (let i = 0; i < args.length; i++) {
    if (args[i] === '--out') out = args[++i];
    else if (args[i] === '--upload') upload = true;
    else positional.push(args[i]);
  }
  const [input, assetId] = positional;
  if (!input || !assetId || !/^[A-Za-z0-9_-]+$/.test(assetId)) {
    console.error('usage: package.ts <input.mp4> <assetId> [--out <dir>] [--upload]');
    Deno.exit(2);
  }
  return { input, assetId, out, upload };
}

async function run(cmd: string, args: string[]): Promise<string> {
  const { code, stdout, stderr } = await new Deno.Command(cmd, { args }).output();
  if (code !== 0) {
    throw new Error(`${cmd} failed (${code}):\n${new TextDecoder().decode(stderr).slice(-2000)}`);
  }
  return new TextDecoder().decode(stdout);
}

async function hasAudio(input: string): Promise<boolean> {
  const out = await run('ffprobe', [
    '-v', 'error', '-select_streams', 'a', '-show_entries', 'stream=index', '-of', 'csv=p=0', input,
  ]);
  return out.trim().length > 0;
}

function toHex(bytes: Uint8Array): string {
  return Array.from(bytes, (b) => b.toString(16).padStart(2, '0')).join('');
}

export function ffmpegArgs(
  input: string, dir: string, keyInfoPath: string, audio: boolean,
): string[] {
  const split = RENDITIONS.map((_, i) => `[v${i}]`).join('');
  const scales = RENDITIONS.map((r, i) => `[v${i}]scale=-2:${r.height}[o${i}]`).join(';');
  const args = [
    '-y', '-hide_banner', '-loglevel', 'error', '-i', input,
    '-filter_complex', `[0:v]split=${RENDITIONS.length}${split};${scales}`,
  ];
  RENDITIONS.forEach((r, i) => {
    args.push('-map', `[o${i}]`);
    if (audio) args.push('-map', '0:a:0');
    args.push(
      `-b:v:${i}`, `${r.videoKbps}k`, `-maxrate:v:${i}`, `${r.maxKbps}k`,
      `-bufsize:v:${i}`, `${r.maxKbps * 2}k`,
    );
  });
  args.push(
    '-c:v', 'libx264', '-preset', 'veryfast', '-profile:v', 'main', '-pix_fmt', 'yuv420p',
    // A keyframe at every segment boundary so all renditions cut at the same times.
    '-force_key_frames', `expr:gte(t,n_forced*${SEGMENT_SECONDS})`, '-sc_threshold', '0',
  );
  if (audio) args.push('-c:a', 'aac', '-b:a', '128k', '-ac', '2');
  const streamMap = RENDITIONS
    .map((r, i) => (audio ? `v:${i},a:${i},name:${r.name}` : `v:${i},name:${r.name}`))
    .join(' ');
  args.push(
    '-f', 'hls', '-hls_time', String(SEGMENT_SECONDS), '-hls_playlist_type', 'vod',
    '-hls_key_info_file', keyInfoPath,
    '-hls_segment_filename', join(dir, '%v_%03d.ts'),
    '-master_pl_name', 'master.m3u8',
    '-var_stream_map', streamMap,
    join(dir, '%v.m3u8'),
  );
  return args;
}

const CONTENT_TYPES: Record<string, string> = {
  '.m3u8': 'application/vnd.apple.mpegurl',
  '.ts': 'video/mp2t',
};

async function uploadToR2(dir: string, assetId: string) {
  const env = (name: string) => {
    const v = Deno.env.get(name);
    if (!v) throw new Error(`${name} is not set`);
    return v;
  };
  const r2 = new AwsClient({
    accessKeyId: env('R2_ACCESS_KEY_ID'),
    secretAccessKey: env('R2_SECRET_ACCESS_KEY'),
    service: 's3',
    region: 'auto',
  });
  const base = `https://${env('R2_ACCOUNT_ID')}.r2.cloudflarestorage.com/${env('R2_BUCKET')}`;
  for await (const entry of Deno.readDir(dir)) {
    if (!entry.isFile) continue;
    const ext = entry.name.slice(entry.name.lastIndexOf('.'));
    const res = await r2.fetch(`${base}/videos/${assetId}/${entry.name}`, {
      method: 'PUT',
      body: await Deno.readFile(join(dir, entry.name)),
      headers: { 'content-type': CONTENT_TYPES[ext] ?? 'application/octet-stream' },
    });
    if (!res.ok) throw new Error(`upload ${entry.name} failed: ${res.status} ${await res.text()}`);
  }
}

if (import.meta.main) {
  const { input, assetId, out, upload } = parseArgs(Deno.args);
  const dir = join(out, assetId);
  await Deno.mkdir(dir, { recursive: true });

  const key = crypto.getRandomValues(new Uint8Array(16));
  const keyHexPath = join(out, `${assetId}.key.hex`);
  await Deno.writeTextFile(keyHexPath, toHex(key), { mode: 0o600 });

  // ffmpeg reads the key from a binary file named in the key-info file. Both live in a temp dir
  // that is removed afterwards, so the raw key never sits next to the upload folder.
  const tmp = await Deno.makeTempDir({ prefix: 'hls-key-' });
  try {
    const keyBinPath = join(tmp, 'key.bin');
    const keyInfoPath = join(tmp, 'key.info');
    await Deno.writeFile(keyBinPath, key, { mode: 0o600 });
    await Deno.writeTextFile(keyInfoPath, `${KEY_URI}\n${keyBinPath}\n`);
    await run('ffmpeg', ffmpegArgs(input, dir, keyInfoPath, await hasAudio(input)));
  } finally {
    await Deno.remove(tmp, { recursive: true });
  }
  console.log(`packaged ${dir} (key: ${keyHexPath})`);

  if (upload) {
    await uploadToR2(dir, assetId);
    console.log(`uploaded to R2 videos/${assetId}/`);
  }
}
