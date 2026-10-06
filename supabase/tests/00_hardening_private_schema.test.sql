-- F-2 / NFR-08 — Layer 1 (docs/16 §1): secrets live in a schema the API roles cannot use.
begin;
create extension if not exists pgtap with schema extensions;
select plan(3);

select has_schema('private', 'private schema exists');
select ok(not has_schema_privilege('anon', 'private', 'usage'),
          'anon has no usage on schema private');
select ok(not has_schema_privilege('authenticated', 'private', 'usage'),
          'authenticated has no usage on schema private');

select * from finish();
rollback;
