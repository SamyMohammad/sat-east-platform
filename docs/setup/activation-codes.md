# Activation codes (PAY-06, PAY-07)

Run these statements as `postgres` in the Supabase SQL editor. The private generator is
not executable by `anon`, `authenticated` or `service_role`; there is no code-generation API.

Generate a batch for a course (replace the slug, count and note):

```sql
select * from private.generate_activation_codes((select id from public.courses where slug = 'sat-math'), 25, 'Closed beta batch 1');
```

The result contains 25 unique, stored, 12-character codes from
`ABCDEFGHJKMNPQRSTUVWXYZ23456789`, with `created_by` null. Each code grants its course to one
student. Share each code only with its intended student and keep exports private.

List unused codes for that course:

```sql
select a.code, a.note, a.created_at
from public.activation_codes a
join public.courses c on c.id = a.course_id
where c.slug = 'sat-math' and a.redeemed_by is null and a.redeemed_at is null
order by a.created_at, a.code;
```

The course must be published before a student can redeem. The student submits the code and a
test date to `redeem_activation_code`; lowercase, spaces and dashes are accepted. Date bounds
are yesterday through today + `settings.test_date_max_days` (default 548 days), inclusive.

Access ends at the later of server now + `settings.access_min_days` (60 days) and midnight UTC
after the test date + `settings.access_grace_days` (14 days). The chosen test date is read-only
for students after redemption. An existing enrollment in any status blocks activation for that
course and leaves the code unused; expired/refunded students should contact their teacher.

The per-student quota is `settings.rate_redeem_per_min` (five attempts per minute), including
wrong guesses. `code_invalid`, `code_used` and `already_enrolled` are returned as
`{ok:false,error}`; other failures are raised. The client must handle both shapes.
