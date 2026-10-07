# Segurança do Prisma

Este documento descreve como o Prisma protege os dados, o que cada instalação
precisa configurar e o que ainda falta. Ele vale para quem contribui com código
e para quem implanta o sistema.

## Dados tratados

| Dado | Onde | Como fica no banco |
|------|------|--------------------|
| Prontuários SAH e AGHUSE do paciente | `pacientes` | Cifrado, determinístico (permite busca exata) |
| Iniciais do nome do paciente | `pacientes` | Cifrado |
| Respostas do formulário: número SINAN, município, benefício, exames, desfecho, contatos etc. | `avaliacoes_clinicas.dados_formulario` | Cifrado (o JSON inteiro) |
| Nome do usuário do sistema | `users` | Texto puro (aparece nas listas de Configurações) |
| CPF do usuário do sistema | `users` | Cifrado, determinístico (usado no login) |
| Senha do usuário | `users` | Hash bcrypt (nunca reversível) |
| Histórico de alterações | `versions` (PaperTrail) | Campos cifrados continuam cifrados |
| Quem visualizou o quê: usuário, registro, IP e navegador | `audit_logs` | Texto puro, sem dado do paciente (só o id do registro visto) |

O Prisma **não guarda nome completo nem CPF de paciente**: como no formulário
em papel, a identificação é feita por prontuário e iniciais (minimização,
LGPD art. 6º, III).

Dados de saúde são dados pessoais sensíveis (LGPD, art. 5º, II). Cada
instituição que implanta o Prisma é a controladora desses dados e precisa
definir a base legal (art. 11) com o seu encarregado (DPO).

## Permissões

Há dois papéis globais (`users.role`):

- **admin**: uma conta só no sistema inteiro. Administra (usuários,
  instituições, setores, formulários habilitados e liberações) e vê e registra
  tudo. A tela nunca cria nem promove um admin.
- **usuario**: faz só o que o admin liberar, por instituição, setor e
  formulário.

Um usuário usa um formulário num setor só com as **três liberações**, sem
herança entre níveis:

1. da instituição do setor (`liberacoes_instituicao`);
2. do setor (`liberacoes_setor`);
3. do formulário naquele setor, com o papel: **registra** (registra, atualiza
   e consulta) ou **consulta** (só consulta) (`liberacoes_formulario`);

e com o formulário **habilitado** no setor pelo admin
(`formularios_habilitados`). Tirar qualquer nível corta o acesso aos de baixo.

| Ação | admin | usuário que registra | usuário que só consulta | usuário sem liberação |
|------|:-----:|:--------------------:|:-----------------------:|:---------------------:|
| Ver a visão geral | ✅ | ✅ | ✅ | ✅ |
| Ver o formulário no menu e a lista dele | ✅ (todos os setores) | ✅ (setores liberados) | ✅ (setores liberados) | ❌ |
| Ver uma notificação | ✅ | ✅ (do setor liberado) | ✅ (do setor liberado) | ❌ |
| Registrar e editar notificação | ✅ (onde o formulário está habilitado) | ✅ (no setor liberado) | ❌ | ❌ |
| Excluir notificação | ❌ | ❌ | ❌ | ❌ |
| Configurações: usuários, liberações, instituições, setores | ✅ | ❌ | ❌ | ❌ |

Como isso é garantido:

- **Login obrigatório em tudo.** O `before_action :authenticate_user!` fica no
  `ApplicationController`. Uma página pública precisa de um
  `skip_before_action` explícito. O health check `/up` não passa por esse
  controller e não expõe dados.
- **Pundit fechado por padrão.** O `ApplicationPolicy` nega tudo e rejeita
  usuário nulo. Cada policy libera só o que precisa.
- **Uma fonte só para o RBAC.** `Permissoes` (em `app/models`) lê as
  liberações uma vez por requisição e responde se a pessoa consulta ou registra
  um formulário num setor. As policies usam essa classe; nenhuma tela decide
  acesso sozinha.
- **Dados filtrados na consulta.** A lista, a busca por prontuário, os números
  da visão geral e a página de Formulários usam o escopo do Pundit, que só traz
  as notificações dos pares (setor, formulário) liberados. A notificação de
  outro setor, aberta pela URL, dá **404**, como se não existisse.
- **O setor decide antes de qualquer leitura.** Ao registrar, o setor escolhido
  é autorizado antes de procurar ou gravar paciente; um setor trocado no
  formulário (ou sem setor) é recusado. O paciente é procurado só dentro do
  setor, e o setor de uma notificação não muda depois do registro.
- **`authorize` antes de gravar.** O `verify_pundit_authorization` (um
  `after_action`) quebra a requisição se a action esquecer o `authorize`, mas
  ele roda *depois* da action. A proteção real é chamar `authorize` antes de
  ler ou gravar.
- **Admin único garantido pelo banco.** A coluna gerada `users.admin_unico`
  vale 1 só para o admin e tem índice único: uma segunda conta admin é
  recusada mesmo com acesso direto ao banco. O papel nunca vem de formulário,
  e a conta admin não pode ser desativada.
- **Liberações coerentes.** A tela de liberações manda o estado inteiro, e
  `LiberacoesDoUsuario` só grava o que respeita a hierarquia: setor sem a
  instituição marcada, formulário sem o setor marcado ou não habilitado, e
  papel fora de "registra"/"consulta" são ignorados. Desmarcar um nível apaga
  os de baixo.
- **Configurações só para o admin.** A `ConfiguracaoPolicy` (base de
  `InstituicaoPolicy`, `SetorPolicy` e `UserPolicy`) libera só o admin. O menu
  nem aparece para os outros, mas a proteção é no servidor: a URL digitada à
  mão também é barrada.
- **Rotas mínimas.** Cada recurso declara `only:` ou `except:` com as actions
  que existem. Usuário e notificação não têm rota de exclusão.

## Controles implementados

### Autenticação (Devise)

- Login por nome de usuário ou CPF, com ou sem pontuação.
- Senha com no mínimo 12 caracteres.
- A conta é bloqueada por 15 minutos após 5 senhas erradas seguidas.
- Cada IP pode fazer no máximo 20 tentativas de login a cada 3 minutos.
- A sessão expira após 30 minutos sem uso.
- Não existe "lembrar de mim": ele desativaria a expiração da sessão, o que é
  ruim em computador compartilhado.
- Modo `paranoid`: login inexistente, senha errada e conta bloqueada recebem a
  mesma resposta, no mesmo tempo. Ninguém descobre quem tem conta.
- Não há cadastro público nem recuperação de senha por e-mail. As contas são
  criadas pelo admin em Configurações > Usuários, sempre como usuário comum.
- **Senha temporária**: a conta nova (e a senha redefinida pelo admin) vem com
  uma senha temporária, e nenhuma tela abre antes de a pessoa trocá-la por uma
  só dela (o admin nunca sabe a senha final). A troca exige a senha atual e
  recusa a nova em branco ou igual à atual. Redefinir a senha derruba as
  sessões abertas da pessoa e desbloqueia a conta.
- **Conta desativada** não entra, e a sessão já aberta cai na próxima
  requisição. Ninguém é excluído: a auditoria guarda o que a pessoa fez.

### Criptografia (Active Record Encryption)

- Campos sensíveis são cifrados antes de ir para o banco (tabela acima).
- O modo determinístico só é usado onde é preciso buscar por igualdade
  (prontuários do paciente, CPF do usuário). Os demais campos usam o modo
  padrão, mais forte.
- Colunas cifradas têm 510 caracteres, porque o texto cifrado ocupa bem mais
  que o original. Os models limitam o tamanho do valor original para caber.

### Logs

[config/initializers/filter_parameter_logging.rb](../config/initializers/filter_parameter_logging.rb)
esconde os objetos `paciente` e `avaliacao_clinica` inteiros, além de CPF,
login, senha, iniciais, prontuário e município. Todos os formulários de
`config/formularios` enviam as respostas dentro de `avaliacao_clinica`, então
um formulário novo já nasce coberto. Os testes conferem isso com
`request.filtered_parameters`.

### Auditoria

- **Alterações (PaperTrail):** criação, alteração e exclusão de pacientes,
  avaliações, usuários, instituições, setores, formulários habilitados e
  liberações ficam na tabela `versions`, com o autor em `whodunnit`: dá para
  saber quem liberou o quê e quando. Campos cifrados continuam cifrados na
  auditoria, e o hash da senha não é gravado.
- **Leituras (LGPD, art. 37 e 46):** a lista, os detalhes e a tela de edição de
  uma notificação (inclusive a que volta sem salvar, por resposta inválida ou
  conflito) gravam em `audit_logs` uma linha por notificação exibida:
  quem viu, quando, qual registro, de qual IP e com qual navegador
  (`ApplicationController#log_read_access`). Na lista, cada linha exibida conta,
  porque mostra iniciais e prontuários; uma busca sem resultado não grava nada.
  Acesso negado (404, sem liberação) não vira leitura.
- **Falha fechada:** a leitura é gravada antes de a página ser montada. Se a
  gravação falhar, os dados não são mostrados.
- **Imutável:** o model `AuditLog` só cria; alterar ou apagar levanta erro. Em
  produção, o usuário do banco da aplicação também não deve ter `UPDATE` nem
  `DELETE` em `audit_logs` e `versions` (ver o checklist).
- **Consulta:** quem viu uma notificação, `AuditLog.do_registro(avaliacao)`;
  quem viu qualquer notificação de um paciente (pedido de um titular),
  `AuditLog.do_paciente(paciente)`. Por enquanto, pelo console.
- **IP confiável:** o IP sai do `X-Forwarded-For` pulando só os proxies de
  `PROXIES_CONFIAVEIS`. Com o padrão do Rails (toda a rede privada), qualquer
  computador da rede interna forjaria o próprio IP, na auditoria e no limite de
  tentativas de login.

### Integridade dos registros clínicos

- Registrar uma notificação **nunca altera a identificação** de um paciente que
  já existe; ela só é vinculada a ele. O paciente é localizado pelo prontuário
  SAH ou AGHUSE. Para um prontuário digitado errado não pôr a notificação no
  paciente errado, o registro é recusado quando:
  - os dois prontuários apontam para pacientes diferentes;
  - um dos prontuários não confere com o cadastro;
  - as iniciais não conferem com as do cadastro.
- Cada setor tem os seus pacientes: um índice único impede dois pacientes com
  o mesmo prontuário no mesmo setor (o mesmo número em outro setor é outro
  cadastro). A notificação é sempre do setor do paciente.
- As respostas seguem a definição do formulário (`config/formularios/*.yml`):
  só perguntas declaradas, só códigos de opção existentes, textos e números
  dentro dos limites, datas válidas e não futuras. Qualquer outra chave é
  recusada, no controller (strong params) e no model.
- Toda edição fica na auditoria com autor e horário. Se duas pessoas editam a
  mesma notificação ao mesmo tempo, a segunda é avisada do conflito em vez de
  apagar a alteração da primeira (bloqueio otimista, `lock_version`).
- Paciente com notificações não pode ser apagado, notificação não tem exclusão,
  setor com pacientes não é excluído, um formulário com notificações num setor
  não é desabilitado nele, e nada clínico é apagado em cascata. A Lei 13.787/2018 prevê guarda mínima de 20 anos
  do prontuário.

### Navegador

- CSP restritiva: só recursos do próprio Prisma, sem script inline nem
  atributo `style`, e a página não pode ser embutida em outro site.
- `Cache-Control: no-store` em todas as páginas: depois do logout, o botão
  "voltar" não mostra dados num computador compartilhado.
- `robots.txt` bloqueia indexação.
- Views nunca usam `html_safe` nem `raw`; o ERB escapa tudo.

### Infraestrutura e processo

- Em produção, HTTPS é obrigatório (`force_ssl`, com HSTS e cookies seguros) e
  só os domínios de `APP_HOSTS` são aceitos. Sem `PROXIES_CONFIAVEIS` (o IP do
  proxy reverso), a aplicação nem sobe.
- No `docker-compose.yml`, o banco e o servidor de desenvolvimento só escutam
  em `127.0.0.1`.
- O CI roda Brakeman, bundler-audit, RuboCop, os testes e os testes de
  navegador, contra MariaDB, com token do GitHub somente leitura. Os controles
  desta página têm testes próprios (`test/integration/seguranca_test.rb`,
  `autenticacao_test.rb` e os de permissão), e um deles ficar quebrado
  derruba o CI.
- O Dependabot atualiza gems e actions.

## Valores configuráveis

| Item | Valor atual | Onde mudar |
|------|-------------|------------|
| Tamanho mínimo da senha | 12 | `config/initializers/devise.rb` (`password_length`) |
| Tentativas até bloquear / tempo de bloqueio | 5 / 15 min | `devise.rb` (`maximum_attempts`, `unlock_in`) |
| Tentativas de login por IP | 20 a cada 3 min | `app/controllers/users/sessions_controller.rb` |
| Sessão ociosa | 30 min | `devise.rb` (`timeout_in`) |
| Perguntas, opções, obrigatoriedade e limites de cada formulário | por pergunta | `config/formularios/*.yml` |
| Fuso horário | America/Sao_Paulo | variável `PRISMA_FUSO_HORARIO` |

Ao mexer nesses valores, considere os efeitos colaterais:

- **Bloqueio por conta:** quem sabe o login de alguém consegue bloqueá-lo por
  15 minutos. Um admin desbloqueia antes pelo console com
  `User.find_by(username: "...").unlock_access!`.
- **Limite por IP:** todos os computadores de um hospital podem sair pelo mesmo
  IP. Um limite baixo demais bloqueia a equipe inteira na troca de turno.
- **Sessão de 30 minutos:** um formulário longo preenchido sem enviar por mais
  de 30 minutos se perde ao enviar.

## Chaves de criptografia

- **Gere chaves próprias para cada instalação** com
  `bin/rails db:encryption:init`. Elas entram pelas variáveis
  `ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY`, `ACTIVE_RECORD_ENCRYPTION_DETERMINISTIC_KEY`
  e `ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT`.
- Guarde-as num gerenciador de senhas ou cofre de segredos. Nunca no git, na
  imagem Docker ou em logs.
- **Quem perde as chaves perde os dados.** O backup do banco não serve sem
  elas, então guarde as chaves com o mesmo cuidado, mas separadas do backup.
- Em produção, a aplicação não sobe sem as três variáveis
  ([config/initializers/active_record_encryption.rb](../config/initializers/active_record_encryption.rb)).
- Os testes usam chaves fixas, públicas e fictícias, definidas em
  `config/environments/test.rb`. Elas não protegem nada e não devem ser usadas
  fora dos testes.

## Checklist de produção

Antes de colocar dados reais:

- [ ] TLS terminado no proxy (kamal-proxy, nginx ou o proxy da instituição). A
      aplicação assume HTTPS (`assume_ssl`); sem TLS no proxy, o tráfego ficaria
      aberto sem nenhum aviso. Em rede interna sem DNS público, use um
      certificado da instituição em vez de Let's Encrypt.
- [ ] `APP_HOSTS` com o domínio do sistema.
- [ ] `PROXIES_CONFIAVEIS` com o IP (ou a faixa) do proxy reverso, e a porta da
      aplicação **inacessível** sem passar por ele (o Rails confia no
      `X-Forwarded-For` de quem chegar direto). Com o Kamal, a faixa da rede
      Docker `kamal` (ver `config/deploy.yml`).
- [ ] Usuário do banco da aplicação **sem `UPDATE` nem `DELETE`** em
      `audit_logs` e `versions`, para as duas auditorias serem imutáveis de
      verdade. No MariaDB, um `GRANT` no banco inteiro não pode ser retirado de
      uma tabela só: dê os privilégios tabela a tabela, por exemplo
      `GRANT SELECT, INSERT ON prisma.audit_logs TO 'prisma_app'@'%'` e
      `GRANT SELECT, INSERT, UPDATE, DELETE ON prisma.pacientes TO 'prisma_app'@'%'`,
      e rode as migrações com outro usuário, que tem permissão de alterar tabelas.
- [ ] Política de retenção para `audit_logs` (contém IP e navegador de quem
      acessou), definida com o encarregado (DPO).
- [ ] Chaves de criptografia próprias, com cópia segura.
- [ ] `secret_key_base` próprio: crie as suas credenciais com
      `bin/rails credentials:edit` ou defina `SECRET_KEY_BASE`. Não reaproveite
      o `config/credentials.yml.enc` de outra instalação.
- [ ] `DATABASE_URL` com usuário próprio (não root). Se o banco estiver em outro
      servidor, use conexão com TLS.
- [ ] Backup do banco testado e cifrado, com política de retenção.
- [ ] `RAILS_LOG_LEVEL` em `info` ou acima. `debug` grava SQL.
- [ ] Contas criadas só para quem precisa, com o papel mínimo necessário.

## Pendências conhecidas

Em ordem aproximada de prioridade:

1. **Dockerfile de produção.** O `Dockerfile` atual é só de desenvolvimento:
   roda como root e não instala gems nem compila assets na imagem. O deploy com
   Kamal (`config/deploy.yml`) ainda não funciona.
2. **Tela de consulta da auditoria de leitura.** As leituras já são gravadas,
   mas consultar (ex.: responder a um titular quem viu os dados dele) ainda é
   pelo console. Falta também o descarte automático pela política de retenção.
3. **Correção da identificação do paciente.** A edição de uma notificação não
   altera prontuários nem iniciais (por segurança). Corrigir um prontuário
   digitado errado ainda exige o console.
4. **Segundo fator de autenticação** para admin.
5. **Rotação de chaves.** O Active Record Encryption aceita várias chaves
   primárias (a última cifra, as anteriores ainda decifram), mas o Prisma lê só
   uma por variável. O modo determinístico não suporta rotação.
6. **Mensagens em português.** As telas e as mensagens de login e de validação
   já estão em português (`config/locales/pt-BR.yml`); o que não tem tradução
   ainda aparece em inglês.
7. **Licença** do projeto.
