// deno run -A spikes/pdf-viewer/server/main.ts
//
// Env: PDF_TOKEN_SECRET (required, 32+ chars), PORT (8792), TOKEN_TTL_S (300), STAMP (0|1),
//      PDF_DIR (folder of <assetId>.pdf; default: a generated 40-page sample as asset "notes1").
import { join } from 'jsr:@std/path@1.1.4';
import { createApp } from './app.ts';
import { makeSamplePdf } from './stamp.ts';

const secret = Deno.env.get('PDF_TOKEN_SECRET') ?? '';
if (secret.length < 32) throw new Error('PDF_TOKEN_SECRET must be at least 32 characters');
const dir = Deno.env.get('PDF_DIR');
const sample = await makeSamplePdf(40);

async function files(assetId: string): Promise<Uint8Array | null> {
  if (!/^[A-Za-z0-9_-]+$/.test(assetId)) return null;
  if (!dir) return assetId === 'notes1' ? sample : null;
  try {
    return await Deno.readFile(join(dir, `${assetId}.pdf`));
  } catch {
    return null;
  }
}

const app = createApp({
  files,
  secret,
  tokenTtlSeconds: Number(Deno.env.get('TOKEN_TTL_S') ?? '300'),
  stamp: Deno.env.get('STAMP') === '1',
  now: () => Math.floor(Date.now() / 1000),
  log: (line) => console.log(`${new Date().toISOString().slice(11, 19)} ${line}`),
});

Deno.serve({ port: Number(Deno.env.get('PORT') ?? '8792'), hostname: '0.0.0.0' }, app.fetch);
