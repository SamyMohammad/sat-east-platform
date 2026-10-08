// Where packaged HLS files live. `r2` = the real target (private bucket, presigned GETs).
// `local` = a folder on disk, with segment URLs signed by this server, for tests and the sandbox.
import { AwsClient } from 'npm:aws4fetch@1.0.20';
import { join } from 'jsr:@std/path@1.1.4';
import { signToken } from './token.ts';

export interface VideoStorage {
  /** Text of `videos/<assetId>/<file>`, or null when it does not exist. */
  getText(assetId: string, file: string): Promise<string | null>;
  /** URL the player fetches the segment from, valid for `ttlSeconds`. */
  segmentUrl(assetId: string, file: string, ttlSeconds: number, origin: string): Promise<string>;
}

export class LocalStorage implements VideoStorage {
  constructor(
    private readonly dir: string,
    private readonly secret: string,
    private readonly now: () => number = () => Math.floor(Date.now() / 1000),
  ) {}

  async getText(assetId: string, file: string): Promise<string | null> {
    try {
      return await Deno.readTextFile(join(this.dir, assetId, file));
    } catch (e) {
      if (e instanceof Deno.errors.NotFound) return null;
      throw e;
    }
  }

  async segmentUrl(assetId: string, file: string, ttlSeconds: number, origin: string) {
    const e = this.now() + ttlSeconds;
    const t = await signToken({ k: 's', a: assetId, u: file, e }, this.secret);
    return `${origin}/s/${t}/${file}`;
  }

  async readSegment(assetId: string, file: string): Promise<Uint8Array<ArrayBuffer> | null> {
    try {
      return await Deno.readFile(join(this.dir, assetId, file));
    } catch (e) {
      if (e instanceof Deno.errors.NotFound) return null;
      throw e;
    }
  }
}

export class R2Storage implements VideoStorage {
  private readonly client: AwsClient;
  private readonly base: string;

  constructor(cfg: { accountId: string; accessKeyId: string; secretAccessKey: string; bucket: string }) {
    this.client = new AwsClient({
      accessKeyId: cfg.accessKeyId,
      secretAccessKey: cfg.secretAccessKey,
      service: 's3',
      region: 'auto',
    });
    this.base = `https://${cfg.accountId}.r2.cloudflarestorage.com/${cfg.bucket}/videos`;
  }

  async getText(assetId: string, file: string): Promise<string | null> {
    const res = await this.client.fetch(`${this.base}/${assetId}/${file}`);
    if (res.status === 404) return null;
    if (!res.ok) throw new Error(`r2 get ${file}: ${res.status}`);
    return await res.text();
  }

  async segmentUrl(assetId: string, file: string, ttlSeconds: number) {
    const url = new URL(`${this.base}/${assetId}/${file}`);
    url.searchParams.set('X-Amz-Expires', String(ttlSeconds));
    const signed = await this.client.sign(url.toString(), { method: 'GET', aws: { signQuery: true } });
    return signed.url;
  }
}
