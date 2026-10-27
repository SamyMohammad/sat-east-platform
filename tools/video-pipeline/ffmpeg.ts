import { join, resolve } from 'jsr:@std/path@1.1.4';
import { ToolError } from './publish.ts';

type Run = (command: string, args: string[]) => Promise<string>;

async function run(command: string, args: string[]): Promise<string> {
  try {
    const { code, stdout } = await new Deno.Command(command, { args, stdin: 'null', stdout: 'piped', stderr: 'null' }).output();
    if (code !== 0) throw new Error();
    return new TextDecoder().decode(stdout);
  } catch {
    throw new ToolError('ffmpeg_failed', `${command} failed. Check that ffmpeg/ffprobe are installed and the input is a readable video.`);
  }
}

export async function probeDuration(input: string, execute: Run = run): Promise<number> {
  const text = await execute('ffprobe', ['-v', 'error', '-show_entries', 'format=duration', '-of', 'default=noprint_wrappers=1:nokey=1', resolve(input)]);
  const value = Number(text.trim());
  if (!Number.isFinite(value) || value <= 0 || !Number.isSafeInteger(Math.ceil(value))) throw new ToolError('invalid_duration', 'ffprobe must return a positive video duration.');
  return Math.ceil(value);
}

export function ffmpegArgs(input: string, dir: string, keyInfoPath: string, audio: boolean): string[] {
  const args = ['-y', '-hide_banner', '-loglevel', 'error', '-i', input, '-map', '0:v:0', '-vf', 'scale=-2:540'];
  if (audio) args.push('-map', '0:a:0', '-c:a', 'aac', '-b:a', '96k', '-ac', '1');
  args.push('-c:v', 'libx264', '-preset', 'veryfast', '-profile:v', 'main', '-pix_fmt', 'yuv420p',
    '-b:v', '600k', '-maxrate:v', '650k', '-bufsize:v', '1300k',
    '-force_key_frames', 'expr:gte(t,n_forced*6)', '-sc_threshold', '0',
    '-f', 'hls', '-hls_time', '6', '-hls_playlist_type', 'vod', '-hls_key_info_file', keyInfoPath,
    '-hls_segment_filename', join(dir, '%v_%03d.ts'), '-master_pl_name', 'master.m3u8',
    '-var_stream_map', audio ? 'v:0,a:0,name:540p' : 'v:0,name:540p', join(dir, '%v.m3u8'));
  return args;
}

export async function packVideo(input: string, output: string, keyDir: string, key: Uint8Array<ArrayBuffer>): Promise<void> {
  const keyPath = resolve(keyDir, 'key.bin');
  const keyInfo = resolve(keyDir, 'key.info');
  await Deno.writeFile(keyPath, key, { mode: 0o600 });
  // No IV: HLS uses the segment sequence number. Never put these files in output.
  await Deno.writeTextFile(keyInfo, `key\n${keyPath}\n`, { mode: 0o600 });
  const audio = (await run('ffprobe', ['-v', 'error', '-select_streams', 'a:0', '-show_entries', 'stream=index', '-of', 'csv=p=0', resolve(input)])).trim() !== '';
  await run('ffmpeg', ffmpegArgs(resolve(input), resolve(output), keyInfo, audio));
}
