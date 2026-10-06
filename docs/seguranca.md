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
| CPF do usuário do sistema | `users` | Cifrado, determinístico (usado no login) |
| Senha do usuário | `users` | Hash bcrypt (nunca reversível) |
| Histórico de alterações | `versions` (PaperTrail) | Campos cifrados continuam cifrados |

O Prisma **não guarda nome completo nem CPF de paciente**: como no formulário
em papel, a identificação é feita por prontuário e iniciais (minimização,
LGPD art. 6º, III).

Dados de saúde são dados pessoais sensíveis (LGPD, art. 5º, II). Cada
instituição que implanta o Prisma é a controladora desses dados e precisa
definir a base legal (art. 11) com o seu encarregado (DPO).

## Permissões

| Ação | operador | consultor | admin |
|------|:--------:|:---------:|:-----:|
| Ver a visão geral e os formulários | ✅ | ✅ | ✅ |
| Listar e visualizar registros (todos) | ✅ | ✅ | ✅ |
| Registrar notificação | ✅ | ❌ | ✅ |
| Editar notificação (seguimento mês a mês) | ✅ | ❌ | ✅ |
| Excluir notificação | ❌ | ❌ | ❌ |
| Configurações: cadastrar, editar e excluir instituições e setores | ❌ | ❌ | ✅ |
| Qualquer escrita (POST, PATCH, PUT, DELETE) | conforme a policy | ❌ sempre | conforme a policy |

Como isso é garantido:

- **Login obrigatório em tudo.** O `before_action :authenticate_user!` fica no
  `ApplicationController`. Uma página pública precisa de um
  `skip_before_action` explícito. O health check `/up` não passa por esse
  controller e não expõe dados.
- **Pundit fechado por padrão.** O `ApplicationPolicy` nega tudo e rejeita
  usuário nulo. Cada policy libera ações com listas explícitas de papéis, então
  um papel novo começa sem acesso.
- **`authorize` antes de gravar.** O `verify_pundit_authorization` (um
  `after_action`) quebra a requisição se a action esquecer o `authorize`, mas
  ele roda *depois* da action. A proteção real é chamar `authorize` na primeira
  linha.
- **Consultor somente leitura no sistema inteiro.** O
  `deny_writes_for_consultor` barra qualquer requisição que não seja GET ou HEAD
  vinda de um consultor, independente das policies. A exceção é o logout, que é
  do Devise.
- **Configurações só para o admin.** A `ConfiguracaoPolicy` (base de
  `InstituicaoPolicy` e `SetorPolicy`) libera só o papel `admin`. O menu nem
  aparece para os outros papéis, mas a proteção é no servidor: a URL digitada
  à mão também é barrada.
- **Rotas mínimas.** Cada recurso declara `only:` ou `except:` com as actions
  que existem. Sem rota, o Rails não renderiza uma view órfã.

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
  criadas pela administração.

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

### Auditoria (PaperTrail)

- Criação e alteração de pacientes, avaliações e usuários ficam na tabela
  `versions`, com o autor em `whodunnit`.
- Campos cifrados continuam cifrados na auditoria. O hash da senha não é
  gravado.
- Leituras (quem visualizou o quê) ainda **não** são registradas; ver
  pendências.

### Integridade dos registros clínicos

- Registrar uma notificação **nunca altera a identificação** de um paciente que
  já existe; ela só é vinculada a ele. O paciente é localizado pelo prontuário
  SAH ou AGHUSE. Para um prontuário digitado errado não pôr a notificação no
  paciente errado, o registro é recusado quando:
  - os dois prontuários apontam para pacientes diferentes;
  - um dos prontuários não confere com o cadastro;
  - as iniciais não conferem com as do cadastro.
- Um índice único impede dois pacientes com o mesmo prontuário.
- As respostas seguem a definição do formulário (`config/formularios/*.yml`):
  só perguntas declaradas, só códigos de opção existentes, textos e números
  dentro dos limites, datas válidas e não futuras. Qualquer outra chave é
  recusada, no controller (strong params) e no model.
- Toda edição fica na auditoria com autor e horário. Se duas pessoas editam a
  mesma notificação ao mesmo tempo, a segunda é avisada do conflito em vez de
  apagar a alteração da primeira (bloqueio otimista, `lock_version`).
- Paciente com notificações não pode ser apagado, notificação não tem exclusão,
  e nada é apagado em cascata. A Lei 13.787/2018 prevê guarda mínima de 20 anos
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
  só os domínios de `APP_HOSTS` são aceitos.
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
2. **Auditoria de leitura.** A auditoria registra criação e edição, mas não
   quem visualizou qual notificação. Agora que existem lista e visualização,
   esse é o próximo passo para a LGPD.
3. **Correção da identificação do paciente.** A edição de uma notificação não
   altera prontuários nem iniciais (por segurança). Corrigir um prontuário
   digitado errado ainda exige o console.
4. **Gestão de usuários pela interface.** Hoje as contas são criadas pelo
   console.
5. **Segundo fator de autenticação** para admin.
6. **Rotação de chaves.** O Active Record Encryption aceita várias chaves
   primárias (a última cifra, as anteriores ainda decifram), mas o Prisma lê só
   uma por variável. O modo determinístico não suporta rotação.
7. **Mensagens em português.** As telas e as mensagens de login e de validação
   já estão em português (`config/locales/pt-BR.yml`); o que não tem tradução
   ainda aparece em inglês.
8. **Licença** do projeto.
