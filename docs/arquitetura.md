# Arquitetura do Prisma

Visão geral do código para quem vai contribuir. As regras de segurança estão em
[seguranca.md](seguranca.md).

## Visão geral

Monolito Rails 8.1 com MariaDB. As páginas são renderizadas no servidor (ERB e
Tailwind); ainda não há JavaScript. O código usa nomes em português para o
domínio (paciente, avaliação, papel) e nomes em inglês para o que vem do Rails
e das gems.

```
app/
  controllers/
    application_controller.rb   login obrigatório, Pundit, trava do consultor, no-store
    dashboard_controller.rb     painel inicial
    avaliacoes_clinicas_controller.rb  registro de avaliações
    users/sessions_controller.rb       login com limite por IP
  models/
    user.rb                     usuários do sistema e papéis
    paciente.rb                 cadastro do paciente e identificação
    avaliacao_clinica.rb        respostas de um formulário clínico
  policies/                     regras de permissão (Pundit)
  validators/cpf_validator.rb   validates :cpf, cpf: true
lib/cpf.rb                      normalização, validação e geração de CPF
docs/                           esta documentação
```

## Modelos

```
User 1 ── * AvaliacaoClinica * ── 1 Paciente
```

- **User**: conta de quem usa o sistema. O `role` é `operador`, `consultor` ou
  `admin`, gravado como texto. O login aceita `username` ou CPF.
- **Paciente**: identificado pelo CPF ou pelo prontuário SAH.
  `Paciente.identificar` localiza o cadastro sem alterá-lo.
- **AvaliacaoClinica**: um formulário preenchido. As respostas ficam em
  `dados_formulario`, um JSON cifrado; `user` é quem registrou.
- **PaperTrail::Version** (tabela `versions`): histórico de criação e alteração
  dos três modelos acima.

## Fluxo de registro de uma avaliação

`POST /avaliacoes_clinicas` (`AvaliacoesClinicasController#create`):

1. `authorize AvaliacaoClinica`: só operador e admin passam. Isso acontece antes
   de qualquer leitura ou escrita.
2. `Paciente.identificar` procura o paciente pelo CPF ou pelo prontuário SAH.
   Se os dois apontarem para pacientes diferentes, o registro é recusado.
3. Paciente encontrado é só vinculado e o cadastro não muda. Se não existir,
   ele é criado com os dados enviados.
4. Paciente novo e avaliação são gravados numa única transação. O PaperTrail
   registra as duas criações com o autor.
5. Em caso de erro, o formulário volta com o que foi digitado, nunca com dados
   do cadastro existente.

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
criar a migration. Os helpers de rota seguem o plural: `new_avaliacao_clinica_path`
e `avaliacoes_clinicas_path`.

### CPF

- `Cpf.normalizar` remove a pontuação. Letras continuam no valor, para a
  validação recusar a entrada em vez de ela virar vazia sem aviso.
- `Cpf.valido?` confere os dígitos verificadores.
- `Cpf.gerar` cria CPFs válidos aleatórios para seeds e testes. **Nunca
  versione CPFs**, nem de exemplo.
- Nos models: `normalizes :cpf, with: ->(cpf) { Cpf.normalizar(cpf) }` e
  `validates :cpf, cpf: true`.

### Dados sensíveis num model

Todo campo pessoal ou de saúde leva `encrypts`, coluna de 510 caracteres (ou
`text`) e validação de tamanho. Use `deterministic: true` só quando precisar
buscar por igualdade. A lista completa está no checklist de
[novo-formulario.md](novo-formulario.md).

## Testes

- `test/models`, `test/policies` e `test/lib` testam regras isoladas.
  `test/controllers` e `test/integration` passam pela pilha completa: rotas,
  login, permissões e cabeçalhos.
- As fixtures usam dados fictícios e CPFs gerados a cada carga. Todos os
  usuários de `test/fixtures/users.yml` têm a senha `SENHA_DE_TESTE`.
- O ambiente de teste tem chaves de criptografia próprias e públicas, e
  `encrypt_fixtures` cifra as fixtures ao carregar.
- O banco de teste vem de `TEST_DATABASE_URL` e nunca de `DATABASE_URL` (ver
  [config/database.yml](../config/database.yml)).
- Toda regra de permissão nova precisa de teste para cada papel, inclusive
  para mostrar que o consultor não grava.

## Ambiente de desenvolvimento

- `docker-compose.yml` sobe o MariaDB (`db`), o Rails (`web`) e o build do
  Tailwind (`css`). As gems ficam no volume `bundle_data`.
- O `.env` (fora do git) guarda as chaves de criptografia de desenvolvimento.
  O modelo é o `.env.example`.
- Em SELinux, os volumes usam `:z`. Um container criado com `:Z` reetiqueta os
  arquivos só para ele, e os outros perdem o acesso.
