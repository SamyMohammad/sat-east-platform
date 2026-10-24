import { join } from 'jsr:@std/path@1.1.4';

export class ToolError extends Error {
  constructor(readonly code: string, message: string, readonly assetId?: string) {
    super(message);
  }
}

export type VideoFile = { name: string; path: string; bytes: number };
export type Quota = { used_mb: number; cap_mb: number };
export type CreateArgs = { p_topic_id: string; p_subtopic_id: string | null; p_title: string; p_duration_s: number; p_size_mb: number };
export type CreateResult = { ok: true; asset_id: string } | { ok: false; error: 'quota_exceeded'; used_mb: number; cap_mb: number };
export type VideoApi = {
  quota(): Promise<Quota>;
  create(args: CreateArgs): Promise<CreateResult>;
  confirm(assetId: string, keyHex: string): Promise<void>;
  delete(assetId: string): Promise<void>;
  list(topicId: string): Promise<unknown[]>;
  uploadUrls(assetId: string, files: string[]): Promise<Record<string, string>>;
};
export type PublishRequest = { topicId: string; subtopicId?: string; title: string; input: string; dryRun: boolean; out?: string };
export type PublishSummary = { title: string; durationS: number; sizeMb: number } & (
  { assetId: string; quota: Quota } | { output: string }
);
export type PublishDeps = {
  probe(input: string): Promise<number>;
  pack(input: string, output: string, keyDir: string, key: Uint8Array<ArrayBuffer>): Promise<void>;
  randomKey?: () => Uint8Array<ArrayBuffer>;
  api(): Promise<VideoApi>;
  storage: { upload(files: VideoFile[], urls: Record<string, string>): Promise<void> };
  fs: {
    tempDir(): Promise<string>;
    prepareOutput(dir: string): Promise<void>;
    files(dir: string): Promise<VideoFile[]>;
    remove(dir: string): Promise<void>;
  };
};

export function sizeMb(bytes: number[]): number {
  const total = bytes.reduce((sum, value) => {
    if (!Number.isSafeInteger(value) || value < 0 || !Number.isSafeInteger(sum + value)) throw new ToolError('invalid_size', 'Invalid packaged file size.');
    return sum + value;
  }, 0);
  return Math.ceil(total / 1048576);
}

function quotaError(quota: Quota): ToolError {
  return new ToolError('quota_exceeded', `Video storage quota exceeded: ${quota.used_mb} MB used / ${quota.cap_mb} MB cap.`);
}

export async function publish(request: PublishRequest, deps: PublishDeps): Promise<PublishSummary> {
  const durationS = Math.ceil(await deps.probe(request.input));
  if (!Number.isSafeInteger(durationS) || durationS <= 0) throw new ToolError('invalid_duration', 'Video duration must be positive.');
  const temp = await deps.fs.tempDir();
  let key: Uint8Array<ArrayBuffer> | undefined;
  try {
    key = deps.randomKey?.() ?? crypto.getRandomValues(new Uint8Array(16));
    if (key.length !== 16) throw new ToolError('invalid_key', 'Unable to generate a video key.');
    const output = request.dryRun ? request.out ?? await deps.fs.tempDir() : join(temp, 'hls');
    await deps.fs.prepareOutput(output);
    await deps.pack(request.input, output, temp, key);
    const files = await deps.fs.files(output);
    if (files.length === 0) throw new ToolError('pack_failed', 'No HLS files were produced.');
    const size = sizeMb(files.map((file) => file.bytes));
    const summary = { title: request.title, durationS, sizeMb: size };
    if (request.dryRun) return { ...summary, output };
    if (files.length > 2000) throw new ToolError('too_many_files', 'Video exceeds the 2000-file upload limit. Split it into shorter videos.');
    const api = await deps.api();
    const quota = await api.quota();
    if (quota.used_mb + size > quota.cap_mb) throw quotaError(quota);
    const reservation = await api.create({ p_topic_id: request.topicId, p_subtopic_id: request.subtopicId ?? null,
      p_title: request.title, p_duration_s: durationS, p_size_mb: size });
    if (!reservation.ok) throw quotaError(reservation);
    const id = reservation.asset_id;
    try {
      const urls = await api.uploadUrls(id, files.map((file) => file.name));
      await deps.storage.upload(files, urls);
      const hex = Array.from(key, (byte) => byte.toString(16).padStart(2, '0')).join('');
      await api.confirm(id, hex);
    } catch {
      try {
        await api.delete(id);
      } catch {
        throw new ToolError('rollback_failed', 'Publishing failed and cleanup could not finish. Run delete with this asset ID to retry.', id);
      }
      throw new ToolError('publish_failed', 'Publishing failed; the reservation and uploaded files were removed.', id);
    }
    // Reporting failure must not delete an already confirmed, playable asset.
    try {
      return { ...summary, assetId: id, quota: await api.quota() };
    } catch {
      throw new ToolError('quota_refresh_failed', 'Video was published, but quota refresh failed. Run quota to check usage.', id);
    }
  } finally {
    key?.fill(0);
    await deps.fs.remove(temp);
  }
}
