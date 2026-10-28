# Arquitetura do Prisma

Visão geral do código para quem vai contribuir. As regras de segurança estão em
[seguranca.md](seguranca.md).

## Visão geral

Monolito Rails 8.1 com MariaDB. As páginas são renderizadas no servidor (ERB e
Tailwind), sem JavaScript. Cores, fonte e layout estão em
[identidade-visual.md](identidade-visual.md). Em Configurações, cadastrar e
editar abrem num modal por cima da lista, também desenhado pelo servidor
(ver "Modais" em identidade-visual.md). O código usa nomes em português para o domínio
(paciente, formulário, papel) e nomes em inglês para o que vem do Rails e das
gems. A interface é em português (`config/locales/pt-BR.yml`) e usa o horário
de Brasília (`PRISMA_FUSO_HORARIO` muda o fuso).

```
app/
  controllers/
    application_controller.rb          login obrigatório, Pundit, trava do consultor, no-store
    dashboard_controller.rb            "Visão geral"
    avaliacoes_clinicas_controller.rb  registros de um formulário (lista, ver, criar, editar)
    identificacoes_controller.rb       correção da identificação do paciente (prontuários e iniciais)
    configuracoes/                     "Configurações", só admin: instituições, setores, usuários,
                                       liberações e o gerador de formulários (formularios, rascunhos,
                                       secoes, perguntas, publicacoes, versoes; base em gerador_controller.rb)
    senhas_controller.rb               troca da própria senha (obrigatória com senha temporária)
    privacidades_controller.rb         "Privacidade e proteção de dados", ligada no rodapé
    users/sessions_controller.rb       login com limite por IP
  models/
    formulario.rb                      um formulário (a chave) e as versões dele
    versao_formulario.rb               uma versão: rascunho (editável) ou publicada (imutável)
    definicao_de_formulario.rb         o motor: confere uma definição e normaliza e valida as respostas
    edicao_do_rascunho.rb              as mudanças do gerador num rascunho, uma por clique
    pergunta_do_gerador.rb             a tela de uma pergunta no gerador (inclusive as opções digitadas)
    comparacao_de_versoes.rb           o que muda entre duas versões (revisão antes de publicar)
    avisos_de_minimizacao.rb           perguntas que parecem pedir dado que identifica a pessoa
    texto_seguro.rb                    limpeza de todo texto digitado (invisíveis, direção do texto)
    avaliacao_clinica.rb               um formulário preenchido (respostas cifradas), ligado a uma versão
    paciente.rb                        identificação mínima do paciente
    user.rb                            usuários do sistema e papéis
    instituicao.rb, setor.rb           organização: instituições e os seus setores
    formulario_habilitado.rb           formulários habilitados em cada setor (da instituição do formulário)
    acompanhamento_do_formulario.rb    movimento por setor e histórico de inclusões e retiradas de um formulário
    liberacao_*.rb                     liberações por instituição, setor e formulário
    permissoes.rb                      o RBAC: o que cada pessoa pode em cada setor e formulário
    liberacoes_do_usuario.rb           grava as liberações de uma pessoa mantendo a hierarquia
    audit_log.rb                       auditoria de leitura: quem viu qual registro (imutável)
    paginacao.rb                       página, intervalo e números do rodapé das listas de notificações
  policies/                            regras de permissão (Pundit)
  views/avaliacoes_clinicas/           telas geradas a partir da definição do formulário
  views/configuracoes/                 Configurações, inclusive as telas do gerador
  views/shared/                        barra lateral, menu, topo, logo, avisos e paginação
lib/cpf.rb                             CPF dos usuários: normalização, validação e geração
docs/                                  esta documentação
```

## Formulários

Os formulários clínicos ficam no banco e são montados pelo admin no **gerador
de formulários** (Configurações > Gerador de formulários), sem escrever
código. O Prisma não traz formulário nem modelo nenhum: uma instalação nova
começa limpa, e o admin monta cada formulário do zero, numa instituição e nos
setores dela. Como usar está em [novo-formulario.md](novo-formulario.md).

### Versões

Um formulário (`Formulario`, a chave) tem **versões** (`VersaoFormulario`).
O admin edita o **rascunho** e o **publica**; a versão publicada nunca mais
muda (o model recusa alterar e apagar) e passa a ser a que se preenche. A
mudança seguinte vira o rascunho da versão seguinte, e só um rascunho existe
por formulário (o banco garante). Cada notificação fica ligada à versão em que
foi registrada (`AvaliacaoClinica#versao_formulario`) e continua sendo lida e
editada com ela: mudar o formulário não invalida nem reinterpreta o que já
foi coletado.

### O motor: DefinicaoDeFormulario

A estrutura de cada versão é um JSON (`VersaoFormulario#estrutura`). A classe
[`DefinicaoDeFormulario`](../app/models/definicao_de_formulario.rb) é a única
porta de entrada dela e a única fonte de verdade para:

- **o que é uma definição válida**: só campos conhecidos, cada um com o tipo
  certo, textos limpos (`TextoSeguro`) e com tamanho máximo, quantidades
  limitadas (seções, perguntas, opções, dependentes, níveis) e referências que
  existem. O rascunho aceita o que ainda falta para publicar (finalidade, base
  legal, perguntas); a publicação exige tudo. O que é gravado é sempre a
  estrutura que ela devolve (canônica), nunca a que chegou;
- **o que é permitido nas respostas** (strong params só com as perguntas declaradas);
- **como normalizar** o que chega do navegador (textos, números, datas, listas);
- **o que é válido** (tipos, opções, obrigatórias, comparações, condições);
- **como mostrar** (as views percorrem seções e perguntas; não há HTML por formulário);
- **para que e com qual base legal** os dados são coletados (`finalidade` e
  `base_legal`, obrigatórias para publicar, mostradas no registro e gravadas
  em cada notificação).

Os tipos de pergunta são texto curto, texto longo, número (inteiro ou com até
3 casas decimais, gravado como texto exato), data, escolha única, lista
suspensa e múltipla escolha (com opções exclusivas). A identificação do
paciente (prontuários e iniciais, `Paciente::IDENTIFICACAO`) não é pergunta
do gerador: todo formulário a pede antes das perguntas dele, porque é ela que
liga as notificações ao paciente certo.

**Ao apertar uma regra do motor** (um limite menor, um campo a menos), lembre
que as versões publicadas são relidas com as regras novas: uma que deixar de
passar deixa o formulário inacessível. Aperte só com uma migration que
converta as versões gravadas.

### O gerador

As telas do gerador (`app/controllers/configuracoes/`) são só do admin
(`Configuracoes::FormularioPolicy`, conferida antes de procurar o formulário).
Cada mudança é uma requisição: `PerguntaDoGerador` lê a tela de uma pergunta
(inclusive as opções digitadas como `código, rótulo`), e `EdicaoDoRascunho`
aplica a mudança na estrutura e grava, com o `lock_version` que veio da tela
(uma aba antiga não sobrescreve o rascunho). A chave de cada pergunta é gerada
do enunciado e nunca repete uma chave usada em qualquer versão do formulário.
A revisão antes de publicar mostra o que mudou (`ComparacaoDeVersoes`), o que
ainda impede a publicação e os avisos de minimização (`AvisosDeMinimizacao`),
e pede duas confirmações (DPO e minimização).

### Abertura e encerramento

Um formulário pode ser preenchido ao longo do tempo, como um acompanhamento
aberto no início do tratamento e atualizado a cada mês:

- obrigatória "sempre" (`obrigatoria: abertura`): precisa estar respondida para salvar;
- "só para encerrar" (`obrigatoria: encerramento`): passa a ser exigida quando
  a pergunta de encerramento do formulário (uma data, `encerramento`) é preenchida.

### Pergunta condicional sem JavaScript

Uma pergunta com `condicao` só vale quando a pergunta de escolha de que ela
depende (única, lista suspensa ou múltipla) tem uma das opções da condição.
Ela fica logo abaixo dessa pergunta, junto com as outras que dependem dela, e
pode ter as próprias dependentes, até 3 níveis: as perguntas de uma seção estão
em pré-ordem, e o motor confere isso. Na tela, cada pergunta é um `.bloco` com
as dependentes dentro, e cada opção diz em `data-revela` quais dependentes ela
mostra; o CSS de [application.css](../app/assets/stylesheets/application.css)
usa `:has()` e uma regra por posição (até 10 dependentes por pergunta). Uma
dependente escondida esconde as que estão dentro dela. No servidor, a resposta
de uma pergunta fora da condição é descartada, em cascata.

## Modelos

```
Instituicao 1 ── * Setor 1 ── * Paciente 1 ── * AvaliacaoClinica * ── 1 User
                     │                             (setor da notificação = setor do paciente)
                     └── * FormularioHabilitado              │
                                                             * (a versão em que foi registrada)
Formulario 1 ── * VersaoFormulario 1 ────────────────────────┘
  (chave)         (rascunho ou publicada)
  * ── 1 Instituicao (o formulário vale só em setores dela)

User ── * LiberacaoInstituicao, LiberacaoSetor, LiberacaoFormulario (com o papel)
```

`formulario` nas notificações, nos formulários habilitados e nas liberações é
a chave do formulário, com chave estrangeira para `formularios.chave` e o
formato conferido pelo banco.

- **User**: conta de quem usa o sistema. O `role` é `admin` (uma conta só,
  garantida por índice único na coluna gerada `admin_unico`) ou `usuario`,
  gravado como texto. Tem nome, `ativo` (desativada não entra) e
  `deve_trocar_senha` (senha temporária). O login aceita `username` ou CPF.
  `User#permissoes` devolve o `Permissoes` da pessoa.
- **Paciente**: só prontuário SAH, prontuário AGHUSE e iniciais, como no
  formulário em papel, dentro de um setor (prontuário único por setor). Não há
  nome completo nem CPF de paciente. `Paciente.identificar(setor:, ...)`
  localiza o cadastro no setor sem alterá-lo. A identificação só muda em
  `IdentificacoesController` (Corrigir identificação), por quem registra todos
  os formulários em que o paciente tem notificação (`PacientePolicy`).
- **Formulario**: a chave (nome na URL e nas liberações, gerada do título e
  que nunca muda), a instituição a que pertence, a versão publicada
  (`versao_publicada`) e o rascunho. `habilitar_em` acerta os setores em que
  ele vale, só da instituição dele; a instituição só muda enquanto ele não
  estiver em nenhum setor.
  `Formulario.todos` são os publicados; os que nunca foram publicados não
  aparecem para ninguém além do admin, no gerador. Com notificações, nunca é
  excluído (`excluivel?`); sem nenhuma, sai inteiro, publicado ou não, com as
  versões, as habilitações e as liberações (ver seguranca.md, "Exclusão de
  formulário").
- **VersaoFormulario**: a estrutura (JSON) de uma versão, com o número, quem
  publicou e quando. A publicada é somente leitura; a definição dela é lida uma
  vez por processo.
- **AvaliacaoClinica**: um formulário preenchido. `formulario` e
  `versao_formulario` dizem qual definição ele segue (não mudam depois do
  registro), `dados_formulario` guarda as respostas (JSON cifrado),
  `user` é quem registrou, `setor` é o do paciente (não muda depois do
  registro) e `lock_version` impede que edições simultâneas se sobrescrevam.
  `finalidade` e `base_legal` são copiadas da versão no registro e também
  não mudam depois.
- **Instituicao** e **Setor**: a organização, cadastrada pelo admin em
  Configurações. Nome único (a sigla da instituição também), sem diferenciar
  maiúsculas; o nome de um setor só não repete dentro da mesma instituição.
  Instituição com setores ou formulários não é excluída; setor com pacientes
  também não.
- **FormularioHabilitado**: um formulário habilitado num setor da instituição
  dele, já desde o rascunho. Só nos setores em que está habilitado, e depois
  de publicado, ele pode ser liberado e receber notificações; com notificações
  no setor, não é desabilitado. Um setor de outra instituição que já o tinha
  antes da regra de uma instituição só (2026-10-09) continua com ele.
- **LiberacaoInstituicao**, **LiberacaoSetor** e **LiberacaoFormulario**: o
  que cada pessoa acessa. A de formulário tem o `papel` (`registra` ou
  `consulta`). Só valem juntas, sem herança: ver `Permissoes` e
  [seguranca.md](seguranca.md#permissões).
- **PaperTrail::Version** (tabela `versions`): histórico de criação e alteração
  dos modelos acima, com o autor.
- **AuditLog** (tabela `audit_logs`): auditoria de leitura. Uma linha por
  notificação exibida na lista, nos detalhes ou na edição (e do paciente, na
  tela de correção da identificação), com usuário, IP e navegador; gravada por `ApplicationController#log_read_access` antes de a
  página ser montada. Só se cria: alterar ou apagar levanta erro.

## Rotas

```
GET   /formularios/:formulario/avaliacoes           lista (busca por prontuário); cada formulário abre pelo menu
GET   /formularios/:formulario/avaliacoes/new       nova notificação
POST  /formularios/:formulario/avaliacoes           registrar
GET   /formularios/:formulario/avaliacoes/:id       ver
GET   /formularios/:formulario/avaliacoes/:id/edit  editar
PATCH /formularios/:formulario/avaliacoes/:id       salvar edição

GET   /pacientes/:paciente_id/identificacao/edit    corrigir a identificação (?avaliacao= diz para onde voltar)
PATCH /pacientes/:paciente_id/identificacao         salvar a correção

GET    /configuracoes/instituicoes                                 instituições e setores (só admin)
GET    /configuracoes/instituicoes/new                             nova instituição
GET    /configuracoes/instituicoes/:id/edit                        editar (e excluir) instituição
GET    /configuracoes/instituicoes/:instituicao_id/setores/new     novo setor
GET    /configuracoes/instituicoes/:instituicao_id/setores/:id/edit  editar (e excluir) setor
GET    /configuracoes/usuarios                                     usuários (só admin)
GET    /configuracoes/usuarios/new                                 novo usuário (senha temporária)
GET    /configuracoes/usuarios/:id/edit                            editar, ativar ou desativar
GET    /configuracoes/usuarios/:usuario_id/liberacoes/edit         liberações
GET    /configuracoes/usuarios/:usuario_id/senha/edit              senha temporária
GET    /configuracoes/formularios                                  gerador de formulários (só admin)
GET    /configuracoes/formularios/new                              novo formulário (instituição e setores)
GET    /configuracoes/formularios/:formulario                      situação, setores e versões
GET    /configuracoes/formularios/:formulario/rascunho             o rascunho: cabeçalho, seções e perguntas
GET    /configuracoes/formularios/:formulario/rascunho/previa      como fica para quem preenche
GET    /configuracoes/formularios/:formulario/rascunho/perguntas/new    nova pergunta (?secao= ou ?controladora=)
GET    /configuracoes/formularios/:formulario/rascunho/publicacao/new   revisar e publicar
GET    /configuracoes/formularios/:formulario/versoes/:numero      uma versão publicada (só consulta)
GET    /senha/edit                                                 trocar a própria senha
GET    /privacidade                                                privacidade e proteção de dados
```

O rascunho tem ainda `POST` (criar o rascunho da próxima versão), `PATCH`
(cabeçalho) e `DELETE` (descartar), e as seções e perguntas dele têm criar,
editar, `PATCH .../mover` e excluir (`/rascunho/secoes/:id`, com ids `s1`,
`s2`...; `/rascunho/perguntas/:chave`). Toda mudança leva o `lock_version` do
rascunho. Versão publicada não tem rota de alteração nem de exclusão; um
formulário só é excluído (`DELETE /configuracoes/formularios/:formulario`) se
nunca foi publicado.

Instituições, setores, usuários, liberações e senhas também têm `POST` ou
`PATCH` nas rotas correspondentes (e `DELETE` para instituição e setor). Um
setor é sempre buscado dentro da instituição da URL: o id de um setor de outra
instituição dá 404. Usuário não tem rota de exclusão.

A lista de um formulário aceita `?setor=` para filtrar, só entre os setores
que a pessoa vê. Uma notificação de outro setor dá 404, e um paciente que a
pessoa não vê, também. Paciente não tem lista nem tela própria: aparece pelas
notificações, e a correção volta para a notificação de onde a pessoa veio
(um `?avaliacao=` de outro paciente é ignorado).

`:formulario` é a chave do formulário (ex.: `avaliacao_nutricional`). Um formulário
inexistente ou que nunca foi publicado dá 404 em `/formularios`. Notificação
não tem rota de exclusão.

## Fluxo de registro

`AvaliacoesClinicasController#create`:

1. `authorize AvaliacaoClinica`: só operador e admin passam, antes de qualquer
   leitura ou escrita. Se o formulário ganhou uma versão nova enquanto a pessoa
   preenchia (`versao_formulario_id` da tela diferente da publicada), a tela
   volta com a versão nova e o que foi digitado, sem gravar.
2. `Paciente.identificar` procura o paciente pelos prontuários e confere as
   iniciais. Dados que não batem com o cadastro recusam o registro.
3. Paciente encontrado é só vinculado. Se não existir, é criado.
4. Paciente e respostas são validados juntos, para mostrar todos os erros de
   uma vez, cada um ao lado da sua pergunta.
5. Paciente novo e notificação são gravados numa transação, com a versão
   publicada do formulário; o PaperTrail registra o autor.
6. Em caso de erro, o formulário volta com o que foi digitado, nunca com dados
   do cadastro existente.

Na edição (`update`), as respostas são substituídas pelas enviadas, a
identificação do paciente não muda e o `lock_version` detecta se outra pessoa
salvou antes. Prontuário ou iniciais errados são corrigidos em
`IdentificacoesController`, que aceita só esses três campos.

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

- `test/models`, `test/policies` e `test/lib` testam regras isoladas. O motor
  tem uma regra por teste em `definicao_de_formulario_test.rb` (com o
  formulário de teste das fixtures) e testes com dados aleatórios: `definicao_de_formulario_fuzz_test.rb`
  (definições, respostas e lixo) e o último de `edicao_do_rascunho_test.rb`
  (sequências de mudanças do gerador). A semente sai na mensagem de falha;
  `SEMENTE_DO_MOTOR` e `SEMENTE_DO_GERADOR` repetem uma rodada.
- `test/controllers` e `test/integration` passam pela pilha completa: rotas,
  login, permissões, telas e cabeçalhos. Dois arquivos merecem atenção:
  - `formularios_completos_test.rb` publica cada formulário de
    `test/formularios_de_teste.rb`, responde **todas** as perguntas (as
    respostas são geradas da definição), confere a visualização, a edição e a
    lista e verifica IDs duplicados, campos sem rótulo e descrições sem
    destino. Um formulário de teste novo é testado sem escrever mais nada.
  - `gerador_de_formularios_test.rb` e `gerador_seguranca_test.rb`: o gerador
    pela tela, do zero até a notificação e a versão seguinte, e a segurança
    dele (só o admin, em toda rota; XSS em todos os campos e telas; atribuição
    em massa; CSRF; formulário não publicado inacessível; auditoria).
  - `seguranca_test.rb`: login exigido em todas as rotas, cabeçalhos de
    proteção, XSS, atribuição em massa, CSRF, acesso por URL trocada e
    redirecionamento para fora do sistema.
- `test/system` roda num Chrome de verdade (Chromium no container) o que só
  existe no navegador: as perguntas condicionais que aparecem e somem com CSS
  (em três níveis), os campos do gerador por tipo e o gerador de ponta a ponta.
- As fixtures usam dados fictícios. Os usuários de `test/fixtures/users.yml`
  têm CPFs gerados a cada carga e a senha `SENHA_DE_TESTE`.
- `respostas_de_abertura` e `respostas_de_encerramento` (em `test_helper.rb`)
  montam respostas válidas do acompanhamento de teste, publicado nas fixtures
  (`formularios.yml` e `versoes_formulario.yml`, a partir de
  `FormulariosDeTeste::ACOMPANHAMENTO`).
  `publicar_formulario` publica outro formulário num teste.
- O ambiente de teste tem chaves de criptografia próprias e públicas, e
  `encrypt_fixtures` cifra as fixtures ao carregar.
- O banco de teste vem de `TEST_DATABASE_URL` e nunca de `DATABASE_URL` (ver
  [config/database.yml](../config/database.yml)).

## Ambiente de desenvolvimento

- `docker-compose.yml` sobe o MariaDB (`db`), o Rails (`web`) e o build do
  Tailwind (`css`). As gems ficam no volume `bundle_data`.
- O `.env` (fora do git) guarda as chaves de criptografia de desenvolvimento.
  O modelo é o `.env.example`.
- O `db:seed` cria o admin, uma instituição e um setor de desenvolvimento e
  dois usuários liberados neles. Formulário nenhum, nem em desenvolvimento:
  monte no gerador.
- Em SELinux, os volumes usam `:z`. Um container criado com `:Z` reetiqueta os
  arquivos só para ele, e os outros perdem o acesso.
