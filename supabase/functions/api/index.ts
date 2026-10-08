import { createContextClient, verifyAuth } from 'npm:@supabase/server@1.9.1/core';
import { appCheckConfigFromEnv } from '../_shared/app_check.ts';
import { captureError, initSentry } from '../_shared/sentry.ts';
import { createApp } from './app.ts';

initSentry('api');

const app = createApp({
  appCheck: appCheckConfigFromEnv(),
  reportError: captureError,
  async authenticate(req) {
    const { data: auth, error } = await verifyAuth(req, { auth: 'user' });
    if (error) return null;
    const supabase = createContextClient({ auth: { token: auth.token, keyName: auth.keyName } });
    return {
      userId: auth.jwtClaims?.sub,
      rpc: async (fn, args) => {
        const { data, error } = await supabase.rpc(fn, args);
        return { data, error: error ? { message: error.message, code: error.code } : null };
      },
    };
  },
});

export default { fetch: app.fetch };
