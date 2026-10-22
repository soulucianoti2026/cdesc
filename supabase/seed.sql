-- Fictional school/slates only; never create real identities or plaintext CPFs.
insert into cde_private.schools(id, name, city, director, email, phone)
values('10000000-0000-4000-8000-000000000001', 'EEB Caminhos do Vale', 'Florianópolis', 'Mariana Costa', 'direcao@escola.exemplo.br', '(48) 0000-0000')
on conflict do nothing;
insert into cde_private.elections(id, school_id, opens_at, closes_at)
values('20000000-0000-4000-8000-000000000001', '10000000-0000-4000-8000-000000000001', '2026-11-10 08:00:00-03', '2026-11-10 18:00:00-03')
on conflict do nothing;
-- Slates and voters must be registered through the API so CPF encryption and
-- validation run. The offline Flutter mock contains all fictional screen data.
