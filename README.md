# Prisma

Sistema web de código aberto para formulários de análises clínicas. Cada
formulário é descrito num arquivo YAML; o sistema gera a tela, valida as
respostas, cifra os dados e registra quem alterou o quê.

O primeiro formulário é o **seguimento de tuberculose (TB)**: 47 perguntas com
os códigos do SINAN. A notificação é aberta no início do tratamento e
atualizada mês a mês até o encerramento. Os formulários ficam na aba
**Formulários** do painel.

> **Estado:** desenvolvimento inicial. Ainda **não está pronto para produção**;
> veja as [pendências conhecidas](docs/seguranca.md#pendências-conhecidas).

O Prisma trata dados pessoais sensíveis de saúde (LGPD, art. 5º, II). Segurança
faz parte de cada mudança: antes de contribuir, leia
[docs/seguranca.md](docs/seguranca.md).

## Stack

- Ruby 3.3, Rails 8.1, MariaDB 10.11
- [Devise](https://github.com/heartcombo/devise) para login,
  [Pundit](https://github.com/varvet/pundit) para permissões e
  [PaperTrail](https://github.com/paper-trail-gem/paper_trail) para auditoria
- Active Record Encryption para os dados sensíveis no banco
- Tailwind CSS; ainda sem JavaScript

## Papéis

| Papel       | Visualiza registros | Registra e atualiza | Grava qualquer coisa |
|-------------|:-------------------:|:-------------------:|:--------------------:|
| `operador`  | sim                 | sim                 | conforme as policies |
| `consultor` | sim                 | não                 | **nunca**            |
| `admin`     | sim                 | sim                 | conforme as policies |

Toda alteração fica na auditoria, e ninguém apaga um registro clínico. Detalhes
em [docs/seguranca.md](docs/seguranca.md#permissões).

## Rodando em desenvolvimento

Você precisa de Docker com Docker Compose. Tudo roda em containers, sem Ruby na
sua máquina.

```bash
cp .env.example .env
docker compose build
docker compose run --rm web bundle install

# Gera as chaves de criptografia desta instalação
docker compose run --rm web bin/rails db:encryption:init
```

O último comando imprime `primary_key`, `deterministic_key` e
`key_derivation_salt`. Copie cada valor para a variável correspondente no `.env`
(`ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY` etc.). Depois:

```bash
docker compose run --rm web bin/rails db:prepare db:seed
docker compose up
```

Abra <http://localhost:3000> e entre como `admin`, `operador` ou `consultor`,
com a senha `prisma-dev-senha`. Essas contas só existem em desenvolvimento
(ver [db/seeds.rb](db/seeds.rb)); o seed se recusa a rodar em produção.

O banco e o servidor ficam acessíveis só na sua máquina (`127.0.0.1`). Em
sistemas com SELinux (Fedora, RHEL), os volumes usam `:z`; não troque por `:Z`,
porque isso tira o acesso dos outros containers aos arquivos.

### Testes e verificações

```bash
docker compose exec web bin/rails db:test:prepare test
docker compose exec web bin/rails test:system   # navegador de verdade (Chromium)
docker compose exec web bin/brakeman
docker compose exec web bin/bundler-audit
docker compose exec web bin/rubocop
```

Os testes usam um banco separado (`prisma_test`) e chaves de criptografia
próprias, públicas e fictícias. Eles nunca tocam no banco de desenvolvimento.
Os testes de navegador precisam do Chromium que vem na imagem de
desenvolvimento: depois de atualizar o `Dockerfile`, rode `docker compose build`.
O CI ([.github/workflows/ci.yml](.github/workflows/ci.yml)) roda tudo isso a
cada pull request.

## Documentação

- [docs/arquitetura.md](docs/arquitetura.md): organização do código, motor de
  formulários, modelos e convenções
- [docs/seguranca.md](docs/seguranca.md): controles, permissões, chaves,
  checklist de produção e pendências
- [docs/novo-formulario.md](docs/novo-formulario.md): como criar um formulário
  clínico novo em YAML
- [SECURITY.md](SECURITY.md): como relatar uma vulnerabilidade

## Contribuindo

- **Nunca use dados reais de pacientes** em código, testes, seeds, issues,
  pull requests, logs ou capturas de tela. Para CPF, use `Cpf.gerar`.
- Rode os testes e as verificações acima antes de abrir o pull request.
- Mudanças que tocam dados de pacientes seguem o checklist de
  [docs/novo-formulario.md](docs/novo-formulario.md).
- Vulnerabilidades vão pelo canal privado descrito em [SECURITY.md](SECURITY.md),
  nunca por issue pública.

## Licença

Ainda não definida. Até que exista um arquivo `LICENSE`, o código não pode ser
reutilizado livremente.
