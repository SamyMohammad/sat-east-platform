import { assert, assertEquals, assertRejects } from 'jsr:@std/assert@1.0.19';
import { ffmpegArgs, probeDuration } from './ffmpeg.ts';

Deno.test('C-2: ffmpeg has one 540p rendition, mono AAC, key info and six second segments', () => {
  const args = ffmpegArgs('input.mp4', 'output', 'secret/key.info', true);
  assertEquals(args.filter((arg) => arg === '-map').length, 2);
  assertEquals(args[args.indexOf('-vf') + 1], 'scale=-2:540');
  assertEquals(args[args.indexOf('-var_stream_map') + 1], 'v:0,a:0,name:540p');
  assertEquals(args[args.indexOf('-hls_key_info_file') + 1], 'secret/key.info');
  assertEquals(args[args.indexOf('-hls_time') + 1], '6');
  assertEquals(args[args.indexOf('-b:v') + 1], '600k');
  assertEquals(args[args.indexOf('-b:a') + 1], '96k');
  assertEquals(args[args.indexOf('-ac') + 1], '1');
  assertEquals(args[args.indexOf('-master_pl_name') + 1], 'master.m3u8');
  assert(!args.join(' ').includes('720p'));
});

Deno.test('C-2: silent inputs have one video map and no audio encoder', () => {
  const args = ffmpegArgs('silent.mp4', 'output', 'key.info', false);
  assertEquals(args.filter((arg) => arg === '-map').length, 1);
  assertEquals(args.includes('-c:a'), false);
  assertEquals(args[args.indexOf('-var_stream_map') + 1], 'v:0,name:540p');
});

Deno.test('C-2: probe duration rounds up and requires a finite positive duration', async () => {
  assertEquals(await probeDuration('clip.mp4', () => Promise.resolve('30.01')), 31);
  for (const value of ['0', '-1', 'NaN', 'Infinity', '', 'bad']) {
    await assertRejects(() => probeDuration('clip.mp4', () => Promise.resolve(value)));
  }
});
