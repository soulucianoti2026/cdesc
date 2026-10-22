# Integração Supabase

O aplicativo funciona offline com o mock. A integração real é uma implementação preparada e testada localmente; nenhuma migração ou função foi enviada a um projeto remoto.

## Configurar o ambiente

1. Crie/selecione o projeto Supabase e vincule a CLI ao project ref correto. Aplique `supabase db push`. `supabase/seed.sql` contém apenas escola e eleição fictícias, para um ambiente de homologação. Não execute esse seed em uma base institucional.
2. Configure o provedor OAuth/OIDC `custom:govbr` no Supabase Auth com credenciais aprovadas do gov.br, issuer/endpoints e callback fornecidos pelo provedor. Não use um provedor genérico que permita cadastrar CPFs arbitrários. Mantenha PKCE e validação de nonce. Autorize `br.sc.cde://login-callback` na lista de redirects. Android e iOS já têm esse deep link configurado.
3. Gere três segredos independentes de 32 bytes aleatórios, codificados em base64: `PII_ENCRYPTION_KEY`, `CPF_HMAC_KEY`, `BALLOT_ENCRYPTION_KEY`. Guarde-os no cofre operacional e configure Edge Function Secrets. Use IDs de versão em `PII_KEY_ID` e `BALLOT_KEY_ID`. Nunca coloque os segredos em Flutter, no SQL seed ou em arquivos versionados.
4. Copie `supabase/functions/.env.example` para um arquivo privado, preencha e execute `supabase secrets set --env-file <arquivo-privado>`. `SUPABASE_URL` e `SUPABASE_SERVICE_ROLE_KEY` são variáveis do ambiente Edge. Restrinja `ALLOWED_ORIGINS` às origens web efetivamente utilizadas; apps nativos não enviam Origin.
5. Publique com `supabase functions deploy cde-api`. `verify_jwt=false` na configuração não torna a função pública: ela exige Bearer JWT, valida-o com `auth.getUser` e verifica o provedor de identidade antes de executar operações. Essa validação explícita também suporta as signing keys do Auth.
6. Copie `config.example.json` para `config.local.json`, preencha a URL HTTPS e a chave publicável. Execute `flutter run --dart-define-from-file=config.local.json`. O modo real falha se a configuração estiver ausente; não recorre silenciosamente ao mock.

O SDK Flutter instalado ainda aceita um enum no método de OAuth. O adaptador gera a URL e o verificador PKCE pelo SDK e troca apenas o identificador do provedor para `custom:govbr`. Esse caminho requer homologação com o provedor real. As sessões são mantidas em memória (`persistSession: false`) para aparelhos compartilhados. A aplicação foi preparada para Android/iOS; não foi criado um target Flutter Web neste projeto.

## Vincular identidades confiáveis

O perfil não é escolhido pelo usuário em produção. `cde_private.profiles` associa o UUID de `auth.users` a uma escola e ao papel diretor/eleitor. Somente uma operação administrativa confiável pode preencher essa tabela.

Antes de criar o vínculo, o operador/backend de provisionamento deve verificar a identidade retornada pelo gov.br e conferir o CPF autenticado com o registro institucional. Para um eleitor, compare o HMAC do CPF verificado com `voters.cpf_digest`, usando exatamente a implementação `digestCpf`. Para a direção, confira o CPF na base institucional de diretores. Não aceite `user_metadata`, CPF digitado ou e-mail como comprovação de identidade. Não há endpoint público de autoatribuição de perfis.

Após essa conferência, um administrador do banco pode executar, com parâmetros reais verificados:

```sql
-- Direção: vínculo restrito à escola cuja direção foi validada.
insert into cde_private.profiles(user_id, school_id, role)
values (:verified_auth_user_id, :verified_school_id, 'director');

-- Eleitor: voter_id deve pertencer à mesma escola e ao CPF autenticado.
insert into cde_private.profiles(user_id, school_id, role, voter_id)
values (:verified_auth_user_id, :verified_school_id, 'voter', :verified_voter_id);
```

Esses placeholders não são comandos prontos para copiar. A automação institucional desse provisionamento não foi implementada, pois o contrato/issuer gov.br e a fonte de diretores não foram fornecidos. Sem o vínculo, o acesso é negado. CPFs de eleitores já vinculados não podem ser substituídos pelo formulário; correções de identidade exigem reprovisionamento confiável.

## Contrato da API

`POST /functions/v1/cde-api`, com `Authorization: Bearer <access_token>`, chave publicável do projeto e JSON. O ator sempre vem do token validado; o cliente não escolhe escola, papel ou eleitor autenticado.

| action | Payload adicional | Resultado |
|---|---|---|
| bootstrap | nenhum | escola, perfil, eleição, chapas permitidas e eleitores apenas para direção |
| save_school | email, phone | ok |
| save_slate | slate: id/number/name/segment/members, cpfs: lista | ok |
| save_voter | voter: id/name/category/link/student_id, cpf | ok |
| search_cpf | cpf completo | eleitores da própria escola, sem CPF |
| vote | slate_id UUID ou null para branco | ok, sem escolha ou recibo vinculável |

IDs vazios significam novo cadastro. CPF vazio só pode preservar um valor existente em produção. Não há armazenamento de CPF em texto claro; nomes e vínculo escolar continuam sendo dados pessoais protegidos pelo controle de acesso. Segmentos: 0 responsáveis, 1 alunos, 2 professores/colaboradores. Categorias: 0 aluno, 1 professor, 2 responsável, 3 funcionário.

As tabelas estão em `cde_private`, sem grants para anon/authenticated e com RLS habilitada sem políticas permissivas. As RPCs públicas só concedem EXECUTE a service_role e têm search_path vazio. As funções validam o perfil, a escola e o estado da eleição; a service_role fica apenas no servidor. Não exponha o schema privado na Data API.

## Criptografia e voto

CPFs usam AES-256-GCM com IV aleatório de 96 bits, tag de 128 bits e contexto autenticado (`cde:cpf:v1:<kid>`). A busca exata usa HMAC-SHA-256 com chave independente e prefixo de domínio. As respostas não retornam ciphertext, digest ou CPF. A chave de HMAC não pode ser trocada sem reindexar os dados.

Cédulas usam chave independente e contexto `cde:ballot:v1:<kid>`. A tabela de cédulas não possui user_id, voter_id, horário ou chave para a tabela de participação. A gravação da participação e da cédula ocorre na mesma transação, sob bloqueio do eleitor e chave única por eleição/eleitor. Repetir a confirmação retorna sucesso sem inserir outro voto ou alterar o anterior. Chapas de outra eleição/segmento, eleitores não habilitados, direção e votações fora do período são recusados. Cadastros são congelados quando a eleição sai de preparação.

Este é um backend de aplicação, não um protocolo de votação verificável ponta a ponta. O servidor processa a escolha antes de criptografá-la; operadores com acesso ao servidor/chaves ou aos logs de infraestrutura podem comprometer o sigilo. Não registre corpos de requisições ou parâmetros de voto no gateway, na função ou no banco. A função não registra esses dados. Separe custódia de chaves, acesso operacional e procedimentos de apuração antes de uso real. Não foi implementada apuração, pois não faz parte das telas solicitadas.

## Homologação pendente

- Login e retorno gov.br em dispositivos reais; conferir o valor efetivo de identity.provider e claims verificados.
- Provisionamento institucional e revogação dos perfis.
- Migrações e autorização no projeto Supabase escolhido; testes locais usam PostgreSQL/PGlite com roles de Auth simuladas.
- Política de retenção, rotação das chaves e backups; conservar as versões antigas enquanto houver ciphertext correspondente.
- Limitação de requisições no gateway conforme volume esperado, sem registrar payloads sensíveis.

Referências consultadas: [Supabase Flutter](https://supabase.com/docs/reference/dart/installing), [Row Level Security](https://supabase.com/docs/guides/database/postgres/row-level-security), [Custom OAuth/OIDC Providers](https://supabase.com/docs/guides/auth/custom-oauth-providers).

## Consulta de resultados parciais e finais

A nova tela consulta `action: results`, com `final_result: true|false`. A resposta é `{is_final, generated_at, segments: [{segment, eligible, blank, slates: [{id, number, name, votes}]}]}`. Aplique também `202610210002_results.sql` e publique novamente a Edge Function.

A RPC `cde_results` só permite consulta pela direção da própria escola. O resultado final exige eleição com status `closed` e horário de encerramento já atingido. Se não houver apuração publicada, a API retorna uma mensagem de indisponibilidade, sem inventar totais ou retornar dados mockados.

A tabela privada `result_snapshots` recebe somente totais agregados de um processo confiável de apuração da comissão. Nenhum endpoint permite ao aplicativo inserir esses totais ou acessar cédulas criptografadas. O processo de descriptografar as cédulas, conferir participação, aplicar regras eleitorais e publicar os snapshots ainda não foi implementado. Ao publicá-los, valide segmentos únicos (0–2), contagens inteiras não negativas, soma de votos não superior aos habilitados, IDs das chapas e consistência com a eleição. A interface não escolhe critérios de desempate e não declara chapa eleita automaticamente.

Os testes SQL verificam: ausência de resultado publicado, restrição ao diretor, isolamento entre escolas, bloqueio de consulta direta e bloqueio do final antes do encerramento. Os testes Flutter verificam agregações, filtros, relatório e tratamento de empate/segmento vazio.
