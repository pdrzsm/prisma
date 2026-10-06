# Arquitetura do Prisma

Visão geral do código para quem vai contribuir. As regras de segurança estão em
[seguranca.md](seguranca.md).

## Visão geral

Monolito Rails 8.1 com MariaDB. As páginas são renderizadas no servidor (ERB e
Tailwind), sem JavaScript. Cores, fonte e layout estão em
[identidade-visual.md](identidade-visual.md). O código usa nomes em português para o domínio
(paciente, formulário, papel) e nomes em inglês para o que vem do Rails e das
gems. A interface é em português (`config/locales/pt-BR.yml`) e usa o horário
de Brasília (`PRISMA_FUSO_HORARIO` muda o fuso).

```
app/
  controllers/
    application_controller.rb          login obrigatório, Pundit, trava do consultor, no-store
    dashboard_controller.rb            "Visão geral"
    formularios_controller.rb          "Formulários": formulários disponíveis
    avaliacoes_clinicas_controller.rb  registros de um formulário (lista, ver, criar, editar)
    users/sessions_controller.rb       login com limite por IP
  models/
    formulario.rb                      motor de formulários: lê, normaliza e valida
    avaliacao_clinica.rb               um formulário preenchido (respostas cifradas)
    paciente.rb                        identificação mínima do paciente
    user.rb                            usuários do sistema e papéis
  policies/                            regras de permissão (Pundit)
  views/avaliacoes_clinicas/           telas geradas a partir da definição do formulário
  views/shared/                        barra lateral, menu, topo, logo e avisos
config/formularios/                    definição de cada formulário (YAML)
lib/cpf.rb                             CPF dos usuários: normalização, validação e geração
docs/                                  esta documentação
```

## Formulários

Cada formulário clínico é um arquivo YAML em
[config/formularios/](../config/formularios), com seções, perguntas, códigos de
resposta e regras. O primeiro é o
[seguimento de TB](../config/formularios/seguimento_tb.yml). A classe
[`Formulario`](../app/models/formulario.rb) lê esses arquivos e é a única fonte
de verdade para:

- **o que é permitido** (strong params só com as perguntas declaradas);
- **como normalizar** o que chega do navegador (espaços, números, listas vazias);
- **o que é válido** (tipos, opções, obrigatórias, comparações entre perguntas);
- **como mostrar** (as views percorrem seções e perguntas; não há HTML por formulário).

Um formulário novo, na maior parte dos casos, é só um YAML novo: não precisa
de model, controller, rota nem view. O passo a passo está em
[novo-formulario.md](novo-formulario.md).

### Abertura e encerramento

Um formulário pode ser preenchido ao longo do tempo, como o seguimento de TB,
que é aberto no início do tratamento e atualizado a cada mês:

- `obrigatoria: abertura`: precisa estar respondida para salvar.
- `obrigatoria: encerramento`: passa a ser exigida quando a pergunta indicada em
  `encerramento:` (a data de encerramento) é preenchida.

### Pergunta condicional sem JavaScript

Uma pergunta com `condicao` só vale para alguns valores da pergunta
**imediatamente anterior** (no TB, a pergunta 10 depende da 9). No navegador, o
CSS em [application.css](../app/assets/stylesheets/application.css) usa `:has()`
para mostrar a pergunta só quando a opção que a revela está marcada. No
servidor, a resposta de uma pergunta fora da condição é descartada. A regra da
pergunta anterior é conferida quando o YAML é carregado.

## Modelos

```
User 1 ── * AvaliacaoClinica * ── 1 Paciente
```

- **User**: conta de quem usa o sistema. O `role` é `operador`, `consultor` ou
  `admin`, gravado como texto. O login aceita `username` ou CPF.
- **Paciente**: só prontuário SAH, prontuário AGHUSE e iniciais, como no
  formulário em papel. Não há nome completo nem CPF de paciente.
  `Paciente.identificar` localiza o cadastro sem alterá-lo.
- **AvaliacaoClinica**: um formulário preenchido. `formulario` diz qual
  definição ele segue, `dados_formulario` guarda as respostas (JSON cifrado),
  `user` é quem registrou e `lock_version` impede que edições simultâneas se
  sobrescrevam.
- **PaperTrail::Version** (tabela `versions`): histórico de criação e alteração
  dos três modelos acima, com o autor.

## Rotas

```
GET   /formularios                                  seção Formulários
GET   /formularios/:formulario/avaliacoes           lista (busca por prontuário)
GET   /formularios/:formulario/avaliacoes/new       nova notificação
POST  /formularios/:formulario/avaliacoes           registrar
GET   /formularios/:formulario/avaliacoes/:id       ver
GET   /formularios/:formulario/avaliacoes/:id/edit  editar
PATCH /formularios/:formulario/avaliacoes/:id       salvar edição
```

`:formulario` é o nome do arquivo YAML (ex.: `seguimento_tb`). Um formulário
inexistente dá 404. Não há rota de exclusão.

## Fluxo de registro

`AvaliacoesClinicasController#create`:

1. `authorize AvaliacaoClinica`: só operador e admin passam, antes de qualquer
   leitura ou escrita.
2. `Paciente.identificar` procura o paciente pelos prontuários e confere as
   iniciais. Dados que não batem com o cadastro recusam o registro.
3. Paciente encontrado é só vinculado. Se não existir, é criado.
4. Paciente e respostas são validados juntos, para mostrar todos os erros de
   uma vez, cada um ao lado da sua pergunta.
5. Paciente novo e notificação são gravados numa transação; o PaperTrail
   registra o autor.
6. Em caso de erro, o formulário volta com o que foi digitado, nunca com dados
   do cadastro existente.

Na edição (`update`), as respostas são substituídas pelas enviadas, a
identificação do paciente não muda e o `lock_version` detecta se outra pessoa
salvou antes.

## Convenções

### Plural em português

O Rails pluraliza em inglês (`avaliacao_clinica` viraria `avaliacao_clinicas`).
O plural correto fica em
[config/initializers/inflections.rb](../config/initializers/inflections.rb), o
que mantém tabela, rotas, associações e `form_with` alinhados:

```ruby
inflect.irregular "avaliacao_clinica", "avaliacoes_clinicas"
```

Todo model novo com plural irregular precisa de uma linha ali **antes** de
criar a migration.

### CPF (usuários)

- `Cpf.normalizar` remove a pontuação. Letras continuam no valor, para a
  validação recusar a entrada em vez de ela virar vazia sem aviso.
- `Cpf.valido?` confere os dígitos verificadores; `validates :cpf, cpf: true`.
- `Cpf.gerar` cria CPFs válidos aleatórios para seeds e testes, com
  `SecureRandom`: o `rand` segue a semente fixa dos testes e chegou a repetir
  o CPF de uma fixture. **Nunca versione CPFs**, nem de exemplo.

### Dados sensíveis num model

Todo campo pessoal ou de saúde leva `encrypts`, coluna de 510 caracteres (ou
`text`) e validação de tamanho. Use `deterministic: true` só quando precisar
buscar por igualdade.

## Testes

- `test/models`, `test/policies` e `test/lib` testam regras isoladas, inclusive
  a definição do seguimento de TB (`test/models/formulario_test.rb`).
- `test/controllers` e `test/integration` passam pela pilha completa: rotas,
  login, permissões, telas e cabeçalhos. Dois arquivos merecem atenção:
  - `formularios_completos_test.rb` responde **todas** as perguntas de **todos**
    os formulários (as respostas são geradas da definição), confere a
    visualização e a edição e verifica IDs duplicados e campos sem rótulo. Um
    formulário novo é testado sem escrever nada.
  - `seguranca_test.rb`: login exigido em todas as rotas, cabeçalhos de
    proteção, XSS, atribuição em massa, CSRF, acesso por URL trocada e
    redirecionamento para fora do sistema.
- `test/system` roda num Chrome de verdade (Chromium no container) o que só
  existe no navegador, como a pergunta condicional que aparece e some com CSS.
- As fixtures usam dados fictícios. Os usuários de `test/fixtures/users.yml`
  têm CPFs gerados a cada carga e a senha `SENHA_DE_TESTE`.
- `respostas_de_abertura` e `respostas_de_encerramento` (em `test_helper.rb`)
  montam respostas válidas do seguimento de TB.
- O ambiente de teste tem chaves de criptografia próprias e públicas, e
  `encrypt_fixtures` cifra as fixtures ao carregar.
- O banco de teste vem de `TEST_DATABASE_URL` e nunca de `DATABASE_URL` (ver
  [config/database.yml](../config/database.yml)).

## Ambiente de desenvolvimento

- `docker-compose.yml` sobe o MariaDB (`db`), o Rails (`web`) e o build do
  Tailwind (`css`). As gems ficam no volume `bundle_data`.
- O `.env` (fora do git) guarda as chaves de criptografia de desenvolvimento.
  O modelo é o `.env.example`.
- Em desenvolvimento, `Formulario` relê um YAML quando o arquivo muda: dá para
  editar um formulário e recarregar a página, sem reiniciar o servidor.
- Em SELinux, os volumes usam `:z`. Um container criado com `:Z` reetiqueta os
  arquivos só para ele, e os outros perdem o acesso.
