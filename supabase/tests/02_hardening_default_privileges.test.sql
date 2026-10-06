-- F-2 / NFR-08 — Layer 3 (docs/16 §1): nothing is callable or readable by API roles unless granted.
begin;
create extension if not exists pgtap with schema extensions;
select plan(10);

create function public.f_probe() returns int language sql as 'select 1';
create function private.f_probe() returns int language sql as 'select 1';
create table public.t_priv_probe (id bigint generated always as identity primary key);

-- functions
select ok(not has_function_privilege('anon', 'public.f_probe()', 'execute'),
          'anon cannot execute a new public function');
select ok(not has_function_privilege('authenticated', 'public.f_probe()', 'execute'),
          'authenticated cannot execute a new public function');
select ok(not has_function_privilege('anon', 'private.f_probe()', 'execute'),
          'anon cannot execute a new private function (global PUBLIC revoke)');
select ok(not has_function_privilege('anon', 'private.rls_auto_enable()', 'execute'),
          'anon cannot execute private.rls_auto_enable');
select ok(has_function_privilege('service_role', 'public.f_probe()', 'execute'),
          'service_role keeps execute on new public functions (Edge Functions)');

-- tables and sequences (D1)
select ok(not has_table_privilege('anon', 'public.t_priv_probe', 'select'),
          'anon has no privileges on a new public table');
select ok(not has_table_privilege('authenticated', 'public.t_priv_probe', 'select,insert,update,delete'),
          'authenticated has no privileges on a new public table');
select ok(not has_sequence_privilege('authenticated', 'public.t_priv_probe_id_seq', 'usage'),
          'authenticated has no usage on a new public sequence');

-- the template path: an explicit grant restores access
grant execute on function public.f_probe() to authenticated;
select ok(has_function_privilege('authenticated', 'public.f_probe()', 'execute'),
          'explicit grant execute restores access');

-- the global PUBLIC revoke must not lock API roles out of pgTAP (RLS tests switch role, then call is()/ok())
select ok(has_function_privilege('authenticated', 'extensions.ok(boolean,text)', 'execute'),
          'pgTAP still callable by authenticated after role switch');

select * from finish();
rollback;
