import { ToolError, type VideoFile } from './publish.ts';

export class PresignedUpload {
  constructor(private readonly read: (path: string) => Promise<Uint8Array<ArrayBuffer>> = Deno.readFile,
    private readonly request: typeof fetch = fetch) {}

  async upload(files: VideoFile[], urls: Record<string, string>): Promise<void> {
    let next = 0;
    let failed = false;
    let status = 'network error';
    const worker = async () => {
      while (!failed && next < files.length) {
        const file = files[next++];
        try {
          const value = urls[file.name];
          const url = new URL(value);
          if (url.protocol !== 'https:' || url.username || url.password) throw new Error();
          const res = await this.request(value, { method: 'PUT', redirect: 'error', body: await this.read(file.path),
            headers: { 'content-type': file.name.endsWith('.m3u8') ? 'application/vnd.apple.mpegurl' : 'video/mp2t' } });
          if (!res.ok) {
            // Only the S3 error code (e.g. SignatureDoesNotMatch) is shown; the body is otherwise dropped.
            const code = (await res.text().catch(() => '')).match(/<Code>([A-Za-z]{1,64})<\/Code>/)?.[1];
            status = code ? `HTTP ${res.status} ${code}` : `HTTP ${res.status}`;
            throw new Error();
          }
          await res.body?.cancel();
        } catch { failed = true; }
      }
    };
    // Drain every in-flight PUT before rollback can delete its object prefix.
    await Promise.all(Array.from({ length: Math.min(4, files.length) }, worker));
    if (failed) throw new ToolError('upload_failed', `Video upload failed (${status}). Check connectivity and retry publishing.`);
  }
}
