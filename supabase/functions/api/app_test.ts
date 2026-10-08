// deno test -A supabase/functions/api/
import { assertEquals } from 'jsr:@std/assert@1.0.19';
import { type Caller, createApp, type Deps } from './app.ts';

type RpcResult = Awaited<ReturnType<Caller['rpc']>>;

function setup(o: {
  signedIn?: boolean;
  rpcResult?: RpcResult;
  appCheck?: Deps['appCheck'];
} = {}) {
  const calls: { fn: string; args: Record<string, unknown> }[] = [];
  const reported: string[] = [];
  const logs: string[] = [];
  const app = createApp({
    appCheck: o.appCheck ?? { projectNumber: undefined, mode: 'monitor' },
    reportError: (_e, ctx) => {
      reported.push(`${ctx.route}:${ctx.code}`);
      return Promise.resolve();
    },
    log: (l) => logs.push(l),
    authenticate: () =>
      Promise.resolve(o.signedIn === false ? null : {
        userId: 'user-1',
        rpc: (fn, args) => {
          calls.push({ fn, args });
          return Promise.resolve(o.rpcResult ?? { data: { status: 'ok', device_id: 'd1' }, error: null });
        },
      }),
  });
  const post = (body: unknown, headers: Record<string, string> = {}) =>
    app.request('http://local/api/register-device', {
      method: 'POST',
      headers: { 'content-type': 'application/json', ...headers },
      body: JSON.stringify(body),
    });
  return { post, calls, reported, logs };
}

const FP = 'device-aaaa-1111-phone';

Deno.test('AUTH-04 register-device: signed-in call reaches register_device with the fields', async () => {
  const s = setup();
  const res = await s.post({ fingerprint: FP, platform: 'android', label: 'Phone' });
  assertEquals(res.status, 200);
  assertEquals(await res.json(), { status: 'ok', device_id: 'd1' });
  assertEquals(s.calls, [{
    fn: 'register_device', args: { p_fingerprint: FP, p_platform: 'android', p_label: 'Phone' },
  }]);
});

Deno.test('AUTH-04 register-device: limit_reached is passed through for S-11', async () => {
  const limit = { status: 'limit_reached', devices: [{ id: 'a' }, { id: 'b' }], changes_left: 1 };
  const s = setup({ rpcResult: { data: limit, error: null } });
  assertEquals(await (await s.post({ fingerprint: FP })).json(), limit);
  assertEquals(s.calls[0].args.p_platform, null);
});

Deno.test('AUTH-04 register-device: not signed in → 401, no RPC', async () => {
  const s = setup({ signedIn: false });
  const res = await s.post({ fingerprint: FP });
  assertEquals(res.status, 401);
  assertEquals(s.calls.length, 0);
});

Deno.test('AUTH-04 register-device: missing fingerprint → invalid_input', async () => {
  const s = setup();
  const res = await s.post({ platform: 'web' });
  assertEquals(res.status, 400);
  assertEquals((await res.json()).error.code, 'invalid_input');
  assertEquals(s.calls.length, 0);
});

Deno.test('AUTH-04 register-device: RPC error codes map to docs/07 §9, others to internal + report', async () => {
  const known = setup({ rpcResult: { data: null, error: { message: 'invalid_input', code: 'P0001' } } });
  const res = await known.post({ fingerprint: 'x' });
  assertEquals([res.status, (await res.json()).error.code], [400, 'invalid_input']);
  assertEquals(known.reported, []);

  const unknown = setup({ rpcResult: { data: null, error: { message: 'connection reset', code: '08006' } } });
  const res2 = await unknown.post({ fingerprint: FP });
  assertEquals([res2.status, (await res2.json()).error.code], [500, 'internal']);
  assertEquals(unknown.reported, ['register-device:08006']);
});

Deno.test('AUTH-04 register-device: App Check enforce blocks a missing token, monitor only logs', async () => {
  const enforce = setup({ appCheck: { projectNumber: '123', mode: 'enforce' } });
  const res = await enforce.post({ fingerprint: FP });
  assertEquals([res.status, (await res.json()).error.code], [403, 'forbidden']);
  assertEquals(enforce.calls.length, 0);

  const monitor = setup({ appCheck: { projectNumber: '123', mode: 'monitor' } });
  assertEquals((await monitor.post({ fingerprint: FP })).status, 200);
  assertEquals(monitor.logs, ['app-check monitor register-device: missing']);
});
