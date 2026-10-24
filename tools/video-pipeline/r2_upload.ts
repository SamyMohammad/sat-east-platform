import { ToolError, type VideoFile } from './publish.ts';

export class PresignedUpload {
  constructor(private readonly read: (path: string) => Promise<Uint8Array<ArrayBuffer>> = Deno.readFile,
    private readonly request: typeof fetch = fetch) {}

  async upload(files: VideoFile[], urls: Record<string, string>): Promise<void> {
    let next = 0;
    let failed = false;
    const worker = async () => {
      while (!failed && next < files.length) {
        const file = files[next++];
        try {
          const value = urls[file.name];
          const url = new URL(value);
          if (url.protocol !== 'https:' || url.username || url.password) throw new Error();
          const res = await this.request(value, { method: 'PUT', redirect: 'error', body: await this.read(file.path),
            headers: { 'content-type': file.name.endsWith('.m3u8') ? 'application/vnd.apple.mpegurl' : 'video/mp2t' } });
          await res.body?.cancel();
          if (!res.ok) throw new Error();
        } catch { failed = true; }
      }
    };
    // Drain every in-flight PUT before rollback can delete its object prefix.
    await Promise.all(Array.from({ length: Math.min(4, files.length) }, worker));
    if (failed) throw new ToolError('upload_failed', 'Video upload failed. Check connectivity and retry publishing.');
  }
}
