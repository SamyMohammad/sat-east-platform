import { AwsClient } from 'npm:aws4fetch@1.0.20';

export interface VideoStorage {
  getText(prefix: string, file: string): Promise<string | null>;
  segmentUrl(prefix: string, file: string, ttlSeconds: number): Promise<string>;
  presignPut(prefix: string, file: string, ttlSeconds: number): Promise<string>;
  list(prefix: string): Promise<string[]>;
  delete(keys: string[]): Promise<void>;
}

type Client = Pick<AwsClient, 'fetch' | 'sign'>;
type Config = { accountId: string; accessKeyId: string; secretAccessKey: string; bucket: string };

function xmlText(text: string): string {
  return text.replace(/&(?:amp|lt|gt|quot|apos|#\d+|#x[\da-f]+);/gi, (entity) => {
    const named: Record<string, string> = { '&amp;': '&', '&lt;': '<', '&gt;': '>', '&quot;': '"', '&apos;': "'" };
    return named[entity] ?? String.fromCodePoint(entity.startsWith('&#x')
      ? parseInt(entity.slice(3, -1), 16) : parseInt(entity.slice(2, -1), 10));
  });
}

export class R2Storage implements VideoStorage {
  private readonly client: Client;
  private readonly base: string;

  constructor(cfg: Config, client?: Client) {
    this.client = client ?? new AwsClient({ accessKeyId: cfg.accessKeyId, secretAccessKey: cfg.secretAccessKey, service: 's3', region: 'auto' });
    this.base = `https://${cfg.accountId}.r2.cloudflarestorage.com/${encodeURIComponent(cfg.bucket)}`;
  }

  private objectUrl(key: string): string {
    return `${this.base}/${key.split('/').map(encodeURIComponent).join('/')}`;
  }

  async getText(prefix: string, file: string): Promise<string | null> {
    const res = await this.client.fetch(this.objectUrl(`${prefix}/${file}`));
    if (res.status === 404) return null;
    if (!res.ok) throw new Error('R2 read failed.');
    return res.text();
  }

  async segmentUrl(prefix: string, file: string, ttlSeconds: number): Promise<string> {
    const url = new URL(this.objectUrl(`${prefix}/${file}`));
    url.searchParams.set('X-Amz-Expires', String(ttlSeconds));
    return (await this.client.sign(url.toString(), { method: 'GET', aws: { signQuery: true } })).url;
  }

  async presignPut(prefix: string, file: string, ttlSeconds: number): Promise<string> {
    const url = new URL(this.objectUrl(`${prefix}/${file}`));
    url.searchParams.set('X-Amz-Expires', String(ttlSeconds));
    return (await this.client.sign(url.toString(), { method: 'PUT', aws: { signQuery: true } })).url;
  }

  async list(prefix: string): Promise<string[]> {
    const keys: string[] = [];
    const seen = new Set<string>();
    let token: string | undefined;
    do {
      const url = new URL(this.base);
      url.searchParams.set('list-type', '2');
      url.searchParams.set('encoding-type', 'url');
      url.searchParams.set('prefix', prefix);
      if (token) url.searchParams.set('continuation-token', token);
      const res = await this.client.fetch(url.toString());
      if (!res.ok) throw new Error('R2 list failed.');
      const xml = await res.text();
      if (!/<ListBucketResult(?:\s[^>]*)?>/.test(xml) || !/<\/ListBucketResult>/.test(xml)) throw new Error('Invalid R2 listing.');
      for (const match of xml.matchAll(/<Key>([\s\S]*?)<\/Key>/g)) {
        const key = decodeURIComponent(xmlText(match[1]));
        if (!key.startsWith(prefix)) throw new Error('Unexpected R2 object prefix.');
        keys.push(key);
      }
      const flag = xml.match(/<IsTruncated>\s*(true|false)\s*<\/IsTruncated>/)?.[1];
      if (!flag) throw new Error('Invalid R2 truncation flag.');
      const truncated = flag === 'true';
      token = truncated ? xmlText(xml.match(/<NextContinuationToken>([\s\S]*?)<\/NextContinuationToken>/)?.[1] ?? '') : undefined;
      if (truncated && (!token || seen.has(token))) throw new Error('Invalid R2 continuation.');
      if (token) seen.add(token);
    } while (token);
    return keys;
  }

  async delete(keys: string[]): Promise<void> {
    // Individual DELETEs avoid XML body signing and are idempotent on retries.
    for (const key of keys) {
      const res = await this.client.fetch(this.objectUrl(key), { method: 'DELETE' });
      if (!res.ok && res.status !== 404) throw new Error('R2 delete failed.');
      await res.body?.cancel();
    }
  }
}
