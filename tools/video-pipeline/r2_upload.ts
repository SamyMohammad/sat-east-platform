import { AwsClient } from 'npm:aws4fetch@1.0.20';
import type { R2Config } from './config.ts';
import { ToolError, type VideoFile } from './publish.ts';

export class R2Upload {
  private readonly client: Pick<AwsClient, 'fetch'>;
  constructor(private readonly config: R2Config,
    private readonly read: (path: string) => Promise<Uint8Array<ArrayBuffer>> = Deno.readFile,
    client?: Pick<AwsClient, 'fetch'>) {
    this.client = client ?? new AwsClient({ accessKeyId: config.accessKeyId, secretAccessKey: config.secretAccessKey, service: 's3', region: 'auto' });
  }

  async upload(assetId: string, files: VideoFile[]): Promise<void> {
    if (!/^[0-9a-f-]{36}$/i.test(assetId)) throw new ToolError('invalid_asset', 'Invalid video asset ID.');
    for (const file of files) {
      if (!/^(?:master|540p)\.m3u8$|^540p_\d+\.ts$/.test(file.name)) throw new ToolError('invalid_output', 'Unexpected file in packaged video.');
      try {
        const url = `https://${this.config.accountId}.r2.cloudflarestorage.com/${encodeURIComponent(this.config.bucket)}/videos/${assetId}/${encodeURIComponent(file.name)}`;
        const res = await this.client.fetch(url, { method: 'PUT', body: await this.read(file.path),
          headers: { 'content-type': file.name.endsWith('.m3u8') ? 'application/vnd.apple.mpegurl' : 'video/mp2t' } });
        await res.body?.cancel();
        if (!res.ok) throw new Error();
      } catch { throw new ToolError('upload_failed', 'R2 upload failed. Check credentials and bucket permissions.'); }
    }
  }
}
