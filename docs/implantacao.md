# Implantação em produção

O Prisma vai para produção como containers num servidor Linux, implantados com
o [Kamal](https://kamal-deploy.org) a partir da máquina de quem implanta. Este
arquivo é o passo a passo e o que conferir depois. Os controles, as permissões e
o checklist de dados reais estão em [seguranca.md](seguranca.md).

O repositório não tem endereço, usuário nem segredo de nenhuma instituição: isso
fica em `~/.config/prisma/producao.env`, na máquina de quem implanta.

## Como fica no servidor

| Container | Imagem | Portas no servidor | O que faz |
|-----------|--------|--------------------|-----------|
| `kamal-proxy` | `basecamp/kamal-proxy` | 80 e 443 | Termina o HTTPS (a 80 só redireciona) e repassa para o Prisma, sem derrubar o sistema a cada deploy |
| `prisma-web-<versão>` | `Dockerfile.production` | nenhuma | O Prisma, como usuário comum (uid 1000), sem as gems de desenvolvimento nem o Kamal |
| `prisma-db` | `mariadb:10.11` | nenhuma | O banco. Só a rede Docker `kamal` o alcança |

- A rede Docker `kamal` tem a faixa `172.30.20.0/24`. É por ela que o
  `kamal-proxy` fala com o Prisma, e é essa faixa que `PROXIES_CONFIAVEIS`
  (`config/deploy.yml`) manda o Rails confiar para o IP de quem acessa.
- Os dados do banco ficam em `~/prisma-db/data` do usuário do SSH, no servidor.
  O Prisma não guarda arquivos enviados (não usa Active Storage): o banco é a
  única coisa que precisa de backup. O cache do limite de tentativas de login
  fica no volume `prisma_cache`.
- O Prisma usa o usuário `prisma_app` do banco, com privilégios tabela a tabela
  (ver [Banco](#banco)). A senha do dono (`root`) nunca entra no container do
  Prisma.

## Ordem na primeira vez

1. [Preparar o servidor](#servidor) (uma vez).
2. [Gerar os segredos](#segredos) e o [certificado](#https) na sua máquina.
3. [Autorizar a chave SSH de deploy](#acesso-ao-servidor).
4. Fazer o commit do que vai para o ar. O Kamal constrói a imagem a partir do
   último commit (um clone do repositório) e **ignora o que não foi commitado**.
5. `bin/implantar setup`
6. `bin/implantar app exec -i --reuse "bin/rails prisma:criar_admin"`
7. [Conferir](#conferir-depois-de-implantar).

## Na máquina de quem implanta

- Docker e acesso ao socket dele. O Kamal roda dentro da imagem oficial dele,
  na mesma versão da gem do `Gemfile.lock`, por `bin/implantar`: não precisa de
  Ruby aqui. Os argumentos são os do `kamal` (`bin/implantar deploy`,
  `bin/implantar logs`, `bin/implantar console`).
- `~/.config/prisma/producao.env` (permissão 600): os [segredos](#segredos).
- `~/.config/prisma/tls/prisma.crt` e `prisma.key`: o [certificado](#https).
- A [chave SSH de deploy](#acesso-ao-servidor).

Para dentro do container do Kamal vão só o repositório, o socket do Docker, a
pasta `tls`, a chave de deploy e o `known_hosts`. O resto do seu `~/.ssh` e do
`~/.config` fica de fora. Em máquinas com SELinux o script desliga o rótulo só
desse container (`--security-opt label=disable`).

## Segredos

`.kamal/secrets` só diz de onde cada segredo vem; nenhum valor vai para o git.
Os valores ficam em `~/.config/prisma/producao.env`, que o `bin/implantar`
carrega:

```bash
SECRET_KEY_BASE=...
DATABASE_URL=mysql2://prisma_app:SENHA_DO_APP@prisma-db/prisma_production
ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY=...
ACTIVE_RECORD_ENCRYPTION_DETERMINISTIC_KEY=...
ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT=...
MARIADB_ROOT_PASSWORD=...

PRISMA_SERVIDOR=10.0.0.10        # onde o SSH e o deploy conectam
PRISMA_SSH_USER=deploy           # usuário do SSH no servidor
# PRISMA_ENDERECO=prisma.hospital.gov.br   # o que as pessoas digitam no navegador (padrão: PRISMA_SERVIDOR)
# PRISMA_ENCARREGADO="Maria Souza · dpo@hospital.gov.br"
```

| Variável | O que é | Como gerar |
|----------|---------|------------|
| `SECRET_KEY_BASE` | Assina cookies e sessões | `openssl rand -hex 64` |
| `ACTIVE_RECORD_ENCRYPTION_*` (3) | Chaves que cifram CPF, prontuário e iniciais | `docker compose run --rm web bin/rails db:encryption:init` |
| `DATABASE_URL` | Usuário e senha que o Prisma usa no banco (`prisma_app`) | a senha, com `openssl rand -hex 32` (sem caracteres que precisem de escape na URL) |
| `MARIADB_ROOT_PASSWORD` | Dono do banco: só o MariaDB, a migração e o backup usam | `openssl rand -hex 32` |

- **Quem perde as chaves de criptografia perde os dados cifrados**, backup
  inclusive ([seguranca.md](seguranca.md#chaves-de-criptografia)). Guarde uma
  cópia do `producao.env` num cofre de senhas, separada dos backups do banco.
- Trocar a senha do `prisma_app`: mude o `DATABASE_URL` e rode
  `bin/implantar deploy`; a migração roda `ALTER USER` com a senha nova.
- Trocar a do `root`: `MARIADB_ROOT_PASSWORD` só vale na primeira vez que o
  MariaDB inicia. Depois, mude a senha dentro do banco (`ALTER USER`) e só então
  o `producao.env`.

## Servidor

Feito uma vez, em Ubuntu Server 24.04 (outro Linux serve, com as mesmas peças):

```bash
# Docker CE e o plugin do compose, do repositório oficial:
# https://docs.docker.com/engine/install/ubuntu/
sudo usermod -aG docker USUARIO        # sair e entrar de novo no SSH

# Rotação dos logs dos containers (sem isso, crescem até encher o disco)
sudo tee /etc/docker/daemon.json >/dev/null <<'JSON'
{ "log-driver": "local", "log-opts": { "max-size": "10m", "max-file": "5" } }
JSON
sudo systemctl restart docker

# A rede dos containers, com a faixa que o config/deploy.yml espera
docker network create --subnet 172.30.20.0/24 kamal

# Firewall: só SSH, HTTP e HTTPS
sudo ufw default deny incoming
sudo ufw allow 22/tcp && sudo ufw allow 80/tcp && sudo ufw allow 443/tcp
sudo ufw enable
```

- **Não publique outras portas de containers.** O Docker publica direto no
  iptables e passa por cima do `ufw`: uma porta publicada fica aberta mesmo
  sem `ufw allow`. Hoje só o `kamal-proxy` publica (80 e 443); o banco e o
  Prisma ficam só na rede `kamal`.
- Quem está no grupo `docker` equivale a `root` no servidor. Use uma conta só
  para a implantação, e não a de uma pessoa.
- Deixe ligadas as atualizações automáticas de segurança do sistema
  (`unattended-upgrades`, no Ubuntu).

## Acesso ao servidor

O Kamal só entra por chave SSH, nunca por senha. Crie uma chave só para isso e
autorize-a no servidor (a senha é pedida uma vez, pelo `ssh-copy-id`):

```bash
ssh-keygen -t ed25519 -f ~/.ssh/prisma_deploy_ed25519 -C "deploy prisma"
ssh-copy-id -i ~/.ssh/prisma_deploy_ed25519.pub USUARIO@SERVIDOR
ssh -i ~/.ssh/prisma_deploy_ed25519 USUARIO@SERVIDOR true     # confirma o fingerprint e testa a chave
```

- A chave de deploy não pode ter senha: o Kamal roda dentro de um container,
  sem o agente SSH. Proteja o arquivo (permissão 600, disco cifrado).
- Para usar outra chave, defina `PRISMA_SSH_KEY=/caminho/da/chave`.
- Depois de testar a chave **em outra sessão**, desligue a senha no servidor
  (`PasswordAuthentication no` em `/etc/ssh/sshd_config.d/`), e troque qualquer
  senha que tenha circulado em conversa ou anotação.
- Se a máquina de implantação tem IP fixo, o `authorized_keys` pode restringir a
  chave a ele: `from="IP" ssh-ed25519 AAAA...`.

## HTTPS

O Prisma assume HTTPS (`assume_ssl`, `force_ssl` e HSTS), então o proxy precisa
de certificado. O Kamal usa os arquivos `~/.config/prisma/tls/prisma.crt` e
`prisma.key`.

**Sem nome de DNS** (acesso por IP), gere um certificado próprio com o IP:

```bash
mkdir -p ~/.config/prisma/tls && chmod 700 ~/.config/prisma/tls
openssl req -x509 -newkey rsa:3072 -nodes -sha256 -days 825 \
  -keyout ~/.config/prisma/tls/prisma.key -out ~/.config/prisma/tls/prisma.crt \
  -subj "/O=Prisma/CN=10.0.0.10" -addext "subjectAltName=IP:10.0.0.10"
chmod 600 ~/.config/prisma/tls/prisma.key
```

- O navegador mostra "Not secure" (ou "Não seguro") até confiar no certificado.
  A conexão já está cifrada; o aviso é só sobre quem assinou. Para tirá-lo,
  instale o `prisma.crt` como confiável em cada computador (a TI faz isso em
  todos de uma vez, por política de grupo no Windows). Sem isso o sistema
  funciona, mas as pessoas se acostumam a clicar em "continuar mesmo assim".
  Como confiar no `prisma.crt`:

  ```bash
  # Windows (prompt de comando como administrador). Em vários computadores, use a
  # política de grupo: Configuração do Computador > Configurações do Windows >
  # Configurações de Segurança > Políticas de Chave Pública > Autoridades de
  # Certificação Raiz Confiáveis
  certutil -addstore -f ROOT prisma.crt

  # Linux, Chrome e Chromium (precisa do nss-tools, ou libnss3-tools no Debian)
  certutil -d sql:$HOME/.pki/nssdb -A -t "C,," -n prisma -i prisma.crt

  # Linux, o resto do sistema (curl etc.)
  sudo cp prisma.crt /etc/pki/ca-trust/source/anchors/ && sudo update-ca-trust          # Fedora, RHEL
  sudo cp prisma.crt /usr/local/share/ca-certificates/ && sudo update-ca-certificates   # Debian, Ubuntu
  ```

  O Firefox tem o repositório próprio: Configurações > Privacidade e Segurança >
  Certificados > Ver certificados > Autoridades > Importar, marcando "Confiar
  nesta CA para identificar sites". Reinicie o navegador depois.
- O certificado vence (825 dias, no comando acima). Anote a data e gere outro
  antes, com `bin/implantar deploy` depois. Cada renovação pede instalar o novo
  `prisma.crt` de novo nos computadores.
- O HSTS não vale para endereços IP (RFC 6797), então com IP ainda dá para
  aceitar a exceção do certificado; com nome de DNS, não. Por isso, antes de
  trocar para um nome, tenha um certificado válido.

**Com nome de DNS**, peça à TI um certificado da CA da instituição (os mesmos
dois arquivos), ou, se o servidor for alcançável pela internet nas portas 80 e
443, deixe o Kamal obter o do Let's Encrypt: troque o bloco `proxy.ssl` de
`config/deploy.yml` por `ssl: true` e defina `PRISMA_ENDERECO` com o nome.

## Primeira implantação

Com tudo acima pronto e as mudanças commitadas:

```bash
bin/implantar setup
```

O que acontece, em ordem:

1. O Kamal confere o Docker no servidor e sobe o MariaDB (`prisma-db`).
2. Constrói a imagem a partir do último commit, com `Dockerfile.production`
   (compila os assets e instala só as gems de produção), e a envia ao servidor
   por um registry local e um túnel SSH.
3. O hook `.kamal/hooks/pre-app-boot` roda, num container que some depois e com
   a senha do dono, `db:prepare` (cria e migra o banco) e
   `prisma:conceder_privilegios` (cria o `prisma_app` e dá os privilégios).
   Se falhar, o deploy para e a versão anterior continua no ar.
4. Sobe o Prisma. O `kamal-proxy` só passa o tráfego para ele quando `/up`
   responde.

Depois, crie a conta admin (o seed se recusa a rodar em produção, e o admin é a
única conta que o sistema permite ter):

```bash
bin/implantar app exec -i --reuse "bin/rails prisma:criar_admin"
```

A tarefa pergunta o login, o nome, o CPF e a senha temporária (que não aparece e
é pedida duas vezes). No primeiro acesso, a pessoa é obrigada a trocá-la. Os
dados não passam por argumento de comando, para não ficarem no histórico do
shell. Em seguida, entre pelo navegador e cadastre as instituições e os setores
(Configurações), os usuários e os formulários
([novo-formulario.md](novo-formulario.md)).

## No dia a dia

| Comando | O que faz |
|---------|-----------|
| `bin/implantar deploy` | Implanta o último commit. As migrações novas rodam no hook, antes de a versão nova subir |
| `bin/implantar app details` | Versões e containers no ar |
| `bin/implantar logs` | Log do Prisma, ao vivo |
| `bin/implantar console` | Console do Rails (entra com o usuário `prisma_app`) |
| `bin/implantar dbc` | Console do banco com o usuário `prisma_app` |
| `bin/implantar rollback VERSÃO` | Volta para uma versão anterior da imagem. **Não desfaz migrações** |
| `bin/implantar como-dono TAREFA` | Roda uma tarefa do Rails como dono do banco, o que o `prisma_app` não pode (ver [Banco](#banco)) |
| `bin/tunel-banco` | Abre o banco de produção em `127.0.0.1:3307` por túnel SSH, para um cliente como o HeidiSQL |
| `bin/implantar accessory logs db` | Log do MariaDB |
| `bin/implantar lock release` | Libera o bloqueio de um deploy que foi interrompido |

Mudanças de código chegam ao servidor por commit e `bin/implantar deploy`;
nunca edite arquivos dentro do container.

## Banco

São dois usuários: o dono (`root`), que só o hook de migração e o backup usam,
e o `prisma_app`, do Prisma. O dono altera tabelas; o `prisma_app` faz só o que
o sistema faz, tabela a tabela (`app/models/privilegios_do_banco.rb`):

| Tabelas | Privilégios do `prisma_app` |
|---------|-----------------------------|
| `audit_logs`, `versions` (as auditorias) | `SELECT`, `INSERT`: ninguém, nem um erro no código, altera ou apaga a auditoria |
| `pacientes`, `avaliacoes_clinicas`, `users` | `SELECT`, `INSERT`, `UPDATE`: o registro clínico e as contas não se apagam pelo sistema |
| `schema_migrations`, `ar_internal_metadata` | `SELECT` |
| as demais, inclusive as que uma migração futura criar | `SELECT`, `INSERT`, `UPDATE`, `DELETE` |

O `prisma_app` não tem `ALTER`, `CREATE`, `DROP` nem `GRANT`. A cada deploy o
hook compara o que o `prisma_app` tem (`SHOW GRANTS`) com o que ele deveria ter,
a partir das tabelas que existem, e só refaz os privilégios se algo diverge:
uma tabela nova ganha os dela sem passo manual, e um privilégio dado por fora
(um `UPDATE` em `audit_logs`, por exemplo) é retirado no deploy seguinte. Quando
está tudo em dia, nada é revogado, para o Prisma que ainda está no ar durante o
deploy não ficar um instante sem acesso. O banco não tem porta publicada.

O que o `prisma_app` não pode, o dono faz: `bin/implantar como-dono TAREFA`
roda a tarefa do Rails num container que some depois, com a imagem que está no
ar e a senha do dono, passada pelo SSH sem aparecer na lista de processos do
servidor. É assim que o hook de deploy migra o banco, e é assim que se faz o
descarte da auditoria pela política de retenção (que o `prisma_app` não consegue
fazer, por não ter `DELETE` em `audit_logs`):

```bash
bin/implantar como-dono prisma:descartar_leituras DIAS=730                   # só conta
bin/implantar como-dono prisma:descartar_leituras DIAS=730 CONFIRMAR=sim     # apaga
```

Para ver o que o `prisma_app` tem:

```bash
ssh USUARIO@SERVIDOR "docker exec -i prisma-db sh -c 'MYSQL_PWD=\"\$MARIADB_ROOT_PASSWORD\" mariadb -uroot'" <<< "SHOW GRANTS FOR 'prisma_app'@'%';"
```

### Abrir o banco num cliente e carregar outros dados

O banco não tem porta publicada, então o HeidiSQL, o DBeaver ou o `mariadb` da
sua máquina entram por um túnel SSH, que escuta só no seu `127.0.0.1`:

```bash
bin/tunel-banco        # deixe rodando; Ctrl+C fecha. Escuta em 127.0.0.1:3307
```

No cliente, use rede TCP/IP, host `127.0.0.1`, porta `3307`. O script pergunta
ao servidor o IP do container do banco a cada vez (ele muda se o container for
recriado), e a porta nunca fica aberta para a rede.

Entre com um usuário **só do banco que for mexer**, nunca com o `prisma_app` nem
com o `root`. Para carregar dados num banco à parte do mesmo MariaDB, crie o
banco e o usuário dele com o dono (a senha viaja pelo stdin do SSH, não pela
linha de comando):

```bash
ssh USUARIO@SERVIDOR "docker exec -i prisma-db sh -c 'MYSQL_PWD=\"\$MARIADB_ROOT_PASSWORD\" mariadb -uroot'" <<'SQL'
CREATE DATABASE `meu-banco` CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;
CREATE USER 'meu_usuario'@'%' IDENTIFIED BY 'SENHA_LONGA_E_ALEATORIA';
GRANT ALL PRIVILEGES ON `meu-banco`.* TO 'meu_usuario'@'%';
SQL
```

- O `prisma_app` não enxerga o banco novo, e o usuário novo não enxerga o
  `prisma_production`. Nome de banco com hífen pede crases no SQL.
- Dado inserido direto no banco não passa pela cifra de colunas do Prisma nem
  pela auditoria. Se forem dados de pacientes, o banco é tão sensível quanto o
  `prisma_production`: acesso restrito, e o disco do servidor cifrado.
- O [backup](#backups) só cobre o `prisma_production`, a menos que você liste os
  outros bancos em `PRISMA_BANCOS`.
- `bin/implantar remove` apaga a pasta de dados do MariaDB, e com ela todos os
  bancos.

## Backups

```bash
PRISMA_BACKUP_SENHA='uma senha longa' bin/backup-banco [pasta]
PRISMA_BANCOS="prisma_production p-sah" PRISMA_BACKUP_SENHA='...' bin/backup-banco   # mais de um banco
```

O dump sai do container pelo SSH e é cifrado (AES-256, PBKDF2) **na sua
máquina**, antes de tocar o disco: o servidor nunca guarda um backup em texto
puro, e a senha do dono não sai do container. Sai um arquivo por banco
(`BANCO-AAAAMMDD-HHMMSS.sql.enc`). Antes de dizer que deu certo, o script abre
cada arquivo e confere que é um dump do MariaDB. `PRISMA_BANCOS` também pode ficar
no `producao.env`.

- O backup tem as contas (hashes de senha) e os dados dos pacientes, ainda
  cifrados nas colunas protegidas. Trate o arquivo como dado sensível: guarde
  fora da máquina de implantação, com acesso restrito. A senha do backup e as
  chaves de criptografia ficam em outro lugar que não seja o arquivo.
- Sem as chaves de criptografia, o backup não recupera CPF, prontuário nem
  iniciais ([Segredos](#segredos)).
- **Nada agenda o backup.** Rode à mão ou agende numa máquina que não seja o
  servidor (cron ou timer de systemd), para o servidor nunca guardar a senha do
  backup. A retenção (quantos backups e por quanto tempo) é decisão da
  instituição com o encarregado de dados.
- **Teste a restauração** de tempos em tempos, num banco descartável:

```bash
docker run -d --name prisma-restauracao -e MARIADB_ROOT_PASSWORD=teste \
  -e MARIADB_DATABASE=prisma_restauracao mariadb:10.11
openssl enc -d -aes-256-cbc -pbkdf2 -iter 600000 -pass env:PRISMA_BACKUP_SENHA \
  -in prisma_production-AAAAMMDD-HHMMSS.sql.enc \
  | docker exec -i -e MYSQL_PWD=teste prisma-restauracao mariadb -uroot prisma_restauracao
docker exec -e MYSQL_PWD=teste prisma-restauracao mariadb -uroot prisma_restauracao -e 'SELECT COUNT(*) FROM users'
docker rm -f prisma-restauracao
```

## Conferir depois de implantar

Da sua máquina (troque `SERVIDOR`; `-k` aceita o certificado próprio):

```bash
curl -sk -o /dev/null -w '%{http_code}\n' https://SERVIDOR/up          # 200
curl -sI http://SERVIDOR/ | head -1                                     # redireciona para https
curl -skI https://SERVIDOR/ | grep -iE 'strict-transport|content-security|permissions-policy|x-frame|cache-control'
nc -zv -w3 SERVIDOR 3306; nc -zv -w3 SERVIDOR 3000                      # as duas devem falhar
```

- Entre com o admin, troque a senha e confira que o sistema mostra as telas.
- O `prisma_app` tem os privilégios da tabela acima (`SHOW GRANTS`), e uma
  tentativa de `UPDATE audit_logs` com ele é negada.
- `bin/implantar logs` não mostra CPF, prontuário, senha nem o texto de uma
  busca (o Rails filtra esses parâmetros).
- Percorra o checklist de [seguranca.md](seguranca.md#checklist-de-produção)
  antes de cadastrar dados reais.

## Se algo der errado

- **O deploy parou no hook (`pre-app-boot`):** a migração falhou ou o banco não
  respondeu. A saída mostra o erro; o Prisma anterior continua no ar. Corrija e
  rode `bin/implantar deploy` de novo.
- **`deploy` diz que está bloqueado:** um deploy anterior foi interrompido.
  Confira com `bin/implantar lock status` e libere com `lock release`.
- **O `kamal-proxy` não dá o Prisma como saudável:** veja
  `bin/implantar logs`. Causas comuns: variável de ambiente faltando (o Rails
  se recusa a subir sem `APP_HOSTS`, `PROXIES_CONFIAVEIS` e as chaves de
  criptografia) ou banco inacessível.
- **"Blocked host" no navegador:** o endereço digitado não é o de
  `PRISMA_ENDERECO` (que vira `APP_HOSTS`).
- **Recomeçar do zero:** `bin/implantar remove` tira o proxy, o Prisma e o
  MariaDB, **inclusive a pasta com os dados do banco**. Faça `bin/backup-banco`
  antes.
