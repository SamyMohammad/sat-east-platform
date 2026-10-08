// deno run -A spikes/paymob/server/main.ts
//
// Env (server only, never in the client or env/*.json):
//   PAYMOB_SECRET_KEY, PAYMOB_PUBLIC_KEY, PAYMOB_HMAC_SECRET, PAYMOB_INTEGRATION_IDS (comma list),
//   PUBLIC_BASE_URL (tunnel URL Paymob can reach), PAYMOB_BASE_URL (default https://accept.paymob.com),
//   PORT (8790).
import { fromFileUrl } from 'jsr:@std/path@1.1.4';
import { createApp } from './app.ts';
import { HttpPaymobClient } from './paymob.ts';
import { Store } from './store.ts';

function env(name: string, fallback?: string): string {
  const v = Deno.env.get(name) ?? fallback;
  if (v === undefined || v === '') throw new Error(`${name} is not set`);
  return v;
}

const integrationIds = env('PAYMOB_INTEGRATION_IDS').split(',').map((s) => Number(s.trim()));
if (integrationIds.some((n) => !Number.isInteger(n) || n <= 0)) throw new Error('PAYMOB_INTEGRATION_IDS must be numbers');

// Spike catalogue (docs/06 prices). Amounts in minor units.
const store = new Store({ graceDays: 14, minDays: 60 });
store.prices.push(
  { id: 'price-sat-egp', courseId: 'sat-math', currency: 'EGP', amountMinor: 150_000, active: true },
  { id: 'price-sat-usd', courseId: 'sat-math', currency: 'USD', amountMinor: 4_900, active: true },
);
store.coupons.push({
  code: 'SPIKE10', courseId: 'sat-math', percentOff: 10, amountOffMinor: null,
  maxUses: 5, usedCount: 0, expiresAt: null, active: true,
});

const app = createApp({
  store,
  paymob: new HttpPaymobClient({
    baseUrl: env('PAYMOB_BASE_URL', 'https://accept.paymob.com'),
    secretKey: env('PAYMOB_SECRET_KEY'),
    publicKey: env('PAYMOB_PUBLIC_KEY'),
  }),
  hmacSecret: env('PAYMOB_HMAC_SECRET'),
  integrationIds,
  publicBaseUrl: env('PUBLIC_BASE_URL').replace(/\/$/, ''),
  page: await Deno.readTextFile(fromFileUrl(new URL('../web/index.html', import.meta.url))),
  now: () => Date.now(),
  log: (event, fields) => console.log(JSON.stringify({ event, ...fields })),
});

Deno.serve({ port: Number(env('PORT', '8790')) }, app.fetch);
