import { assertEquals, assertRejects, assertThrows } from 'jsr:@std/assert@1.0.19';
import { loadConfig, parseDotEnv } from './config.ts';

const R2 = { R2_ACCOUNT_ID: 'account', R2_ACCESS_KEY_ID: 'SECRET_ID', R2_SECRET_ACCESS_KEY: 'SECRET_VALUE', R2_BUCKET: 'videos' };

Deno.test('C-2: dotenv supports comments, export, quotes and equals in secret values', () => {
  assertEquals(parseDotEnv('# comment\nexport R2_BUCKET=videos # comment\nR2_SECRET_ACCESS_KEY="a=b # c"\nR2_ACCOUNT_ID=\'account\'\n'),
    { R2_BUCKET: 'videos', R2_SECRET_ACCESS_KEY: 'a=b # c', R2_ACCOUNT_ID: 'account' });
  assertThrows(() => parseDotEnv('SECRET_VALUE broken line'));
});

Deno.test('C-2: explicit client JSON overrides Supabase env; process R2 overrides dotenv', async () => {
  const config = await loadConfig('staging.json', {
    env: { ...R2, SUPABASE_URL: 'https://other.test', SUPABASE_PUBLISHABLE_KEY: 'other' },
    readText: (path) => Promise.resolve(path === 'staging.json'
      ? '{"SUPABASE_URL":"https://project.test","SUPABASE_PUBLISHABLE_KEY":"publishable"}'
      : 'R2_BUCKET=file-bucket'),
  });
  assertEquals(config.supabaseUrl, 'https://project.test');
  assertEquals(config.publishableKey, 'publishable');
  assertEquals(config.r2.bucket, 'videos');
});

Deno.test('SEC-01: missing configuration names the variable and never includes provided secrets', async () => {
  const error = await assertRejects(() => loadConfig(undefined, {
    env: { ...R2, SUPABASE_URL: 'https://project.test' },
    readText: () => Promise.resolve(''),
  }), Error);
  assertEquals(error.message.includes('SUPABASE_PUBLISHABLE_KEY'), true);
  assertEquals(error.message.includes('SECRET_'), false);
});

Deno.test('SEC-01: malformed dotenv and JSON do not leak contents', async () => {
  for (const envFile of [undefined, 'broken.json']) {
    const error = await assertRejects(() => loadConfig(envFile, { env: R2, readText: () => Promise.resolve('SECRET_VALUE broken') }), Error);
    assertEquals(error.message.includes('SECRET_VALUE'), false);
  }
});
