# Eleição CDE — Santa Catarina<img width="330" height="240" alt="image" src="https://github.com/user-attachments/assets/39fa4e47-68e9-4bde-8a31-4bbcf5c475ce" />


Aplicativo Flutter com as dez telas do Figma, recursos visuais locais e fonte Inter. Inicia em modo demonstrativo, sem conta Supabase, sem autenticação real e sem enviar dados.

Problema: Ajudar na participação da comunidade escolar na eleição de membros do Conselho Deliberativo Escolar (CDE) observado quando eu fui membro do segmento de pais/responsáveis e observei a baixa participação dos alunos e membros aptos a votar.

Solução: Um app onde atendendo as regras do Pleito o diretor possa criar as chapas e os membros da comunidade aptos possam votar.

## Executar

A abertura usa um degradê verde, branco e vermelho com o ícone de urna e
confirmação. O splashscreen permanece por pelo menos 1,4 segundo enquanto o
repositório inicializa; falhas de inicialização oferecem uma nova tentativa.
Os ícones de Android e iOS estão incluídos no projeto. No Android 12 ou superior,
a abertura controlada pelo sistema usa fundo verde sólido e o símbolo da urna,
seguida pela tela Flutter com o degradê completo.

Os arquivos de identidade ficam em `assets/branding/`. Para regenerar os PNGs
e todas as resoluções nativas no Windows, execute
`powershell -NoProfile -ExecutionPolicy Bypass -File tooling/generate-branding.ps1`.

```sh
flutter pub get
flutter run
```

Toque em **Entrar com gov.br** e escolha **direção** ou **eleitor** na demonstração. O seletor existe apenas no modo mock. Os cadastros permanecem em memória durante a execução; reiniciar o app restaura os exemplos. Sair encerra a sessão visual, mas não permite repetir o voto demonstrativo até reiniciar.

A direção pode alterar contatos, cadastrar/editar chapas, filtrar segmentos, buscar eleitores por nome ou CPF completo, cadastrar/editar e habilitar eleitores. O eleitor pode escolher chapa ou voto em branco, conferir, corrigir e confirmar. A conclusão não exibe a escolha. O mock inclui seis chapas e quatro eleitores detalhados; os totais do Figma incluem 128 registros adicionais apenas agregados. Os totais se atualizam com os cadastros visíveis. CPF sintético para testar a busca: `52998224725`.

## Telas

| Figma | Tela | Acesso |
|---|---|---|
| 5:6560 | Acesso gov.br | Inicial |
| 5:6605 | Painel | Perfil direção |
| 5:6686 | Vincular escola | Escola |
| 5:6780 | Chapas | Chapas |
| 5:6859 | Cadastrar chapa | Cadastrar chapa / Editar |
| 5:6956 | Eleitores | Eleitores |
| 5:7057 | Habilitar eleitor | Cadastrar eleitor / selecionar eleitor |
| 5:7161 | Cédula | Perfil eleitor |
| 5:7228 | Conferir voto | Conferir voto |
| 5:7285 | Voto registrado | Confirmar voto |

O cabeçalho, cartões, ícones, cores e tipografia seguem o arquivo CDE-SC. As barras de status/bateria e de gestos são responsabilidade nativa do dispositivo, com `SafeArea`; não simulamos sinal ou bateria. Conteúdo rola em telas pequenas e a navegação administrativa permanece fixa. Formulários novos começam vazios para evitar duplicar cadastros existentes. O campo de aluno abre a lista de alunos da escola.

## Estrutura

- `lib/ui`: componentes, telas e formulários.
- `lib/data`: modelos, contrato de repositório, mock e adaptador Supabase.
- `assets/figma`: imagens/SVGs originais e manifesto por nó; nenhuma URL temporária em runtime.
- `assets/fonts`: Inter e licença OFL.
- `supabase/migrations`: schema privado, RLS, permissões e operações transacionais.
- `supabase/functions/cde-api`: API autenticada, validações, AES-256-GCM e HMAC-SHA-256.
- `docs/SUPABASE.md`: implantação, autenticação, provisionamento e limites.

## Verificação

```sh
flutter analyze
flutter test --timeout 120s
cd tooling
npm ci
node sql-test.mjs
cd ..
./tooling/node_modules/.bin/deno test supabase/functions/cde-api/crypto_test.ts
./tooling/node_modules/.bin/deno check supabase/functions/cde-api/index.ts
```

Os testes Flutter percorrem as dez telas e geram capturas em `build/screenshots/`. Também verificam filtros, correção de voto, voto em branco, sigilo da conclusão, retorno após votar, validação de CPF e conflitos de cadastro. Os testes SQL executam o PostgreSQL local em PGlite, verificando acessos negados, isolamento de escolas, período da votação, unicidade e repetição idempotente. Não substituem uma homologação no Supabase hospedado. Os testes criptográficos verificam IV aleatório, autenticação de conteúdo/contexto e HMAC com chaves distintas.

A conexão de produção não foi implantada: é necessário configurar projeto, segredos e provedor gov.br conforme a documentação. Não há credenciais reais no repositório.

## Resultados da eleição

No perfil de direção, abra **Painel → Resultados da eleição**. A tela mantém os componentes e cores das telas anteriores e oferece:

- Geração de resultado parcial ou final, com seleção explícita do modo.
- Participação geral, votos válidos, brancos e abstenções (ou eleitores que ainda não votaram no parcial).
- Filtros pelos três segmentos, ranking das chapas e percentuais sobre votos válidos.
- Identificação de liderança provisória, maior votação e empate, sem declarar homologação automaticamente.
- Relatório completo selecionável e copiável, contendo todos os segmentos.

Os resultados do modo demonstrativo são agregados fictícios independentes do voto simulado: 67 votos no parcial e 115 no final, de 128 habilitados. Nenhuma escolha individual é reconstruída. Capturas: `build/screenshots/11-results-partial.png` e `12-results-final.png`.

A integração real consulta resultados agregados previamente publicados pela comissão, por meio da nova migração `202610210002_results.sql`. O pipeline de descriptografia/apuração e publicação não é executado pelo celular; precisa ser implementado no ambiente confiável da comissão antes de usar resultados reais.
