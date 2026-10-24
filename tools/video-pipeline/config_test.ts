import { assertEquals, assertRejects } from 'jsr:@std/assert@1.0.19';
import { loadConfig } from './config.ts';

Deno.test('C-2: only Supabase environment is required and no file is read', async () => {
  assertEquals(await loadConfig(undefined, {
    env: { SUPABASE_URL: 'https://project.test', SUPABASE_PUBLISHABLE_KEY: 'publishable' },
    readText: () => { throw new Error('No credentials file'); },
  }), { supabaseUrl: 'https://project.test', publishableKey: 'publishable' });
});
Deno.test('C-2: explicit JSON overrides Supabase environment', async () => {
  assertEquals(await loadConfig('staging.json', {
    env: { SUPABASE_URL: 'https://other.test', SUPABASE_PUBLISHABLE_KEY: 'other' },
    readText: (path) => { assertEquals(path, 'staging.json'); return Promise.resolve('{"SUPABASE_URL":"https://project.test","SUPABASE_PUBLISHABLE_KEY":"publishable"}'); },
  }), { supabaseUrl: 'https://project.test', publishableKey: 'publishable' });
});
Deno.test('SEC-01: missing configuration names the variable without supplied secrets', async () => {
  const error = await assertRejects(() => loadConfig(undefined, {
    env: { SUPABASE_URL: 'https://project.test', UNUSED: 'SECRET_VALUE' }, readText: () => Promise.resolve(''),
  }), Error);
  assertEquals(error.message.includes('SUPABASE_PUBLISHABLE_KEY'), true);
  assertEquals(error.message.includes('SECRET_VALUE'), false);
});
Deno.test('SEC-01: malformed JSON does not leak contents', async () => {
  const error = await assertRejects(() => loadConfig('broken.json', { env: {}, readText: () => Promise.resolve('SECRET_VALUE broken') }), Error);
  assertEquals(error.message.includes('SECRET_VALUE'), false);
});
