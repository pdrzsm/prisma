# Como adicionar um formulário clínico

Checklist para incluir um formulário novo sem abrir brecha. Cada item vem de
um controle descrito em [seguranca.md](seguranca.md); o código existente de
`AvaliacaoClinica` serve de exemplo.

## 1. Model e migration

- [ ] Se o nome tiver plural irregular em português, adicione a regra em
      `config/initializers/inflections.rb` **antes** de gerar a migration.
- [ ] Todo campo pessoal ou de saúde leva `encrypts`. Use
      `deterministic: true` só se precisar buscar por igualdade.
- [ ] Colunas cifradas com `limit: 510` (ou `text`), mais uma validação de
      tamanho no model. Sem isso, um valor longo estoura a coluna ao ser
      cifrado.
- [ ] `has_paper_trail` para registrar criação e alteração.
- [ ] Identificadores (CPF, prontuário) usam `normalizes`, e o CPF usa
      `validates :cpf, cpf: true`.
- [ ] Nada de `dependent: :destroy` em registro clínico; use
      `:restrict_with_error`.

```ruby
class Exemplo < ApplicationRecord
  belongs_to :paciente
  belongs_to :user
  has_paper_trail

  encrypts :observacoes
  validates :observacoes, length: { maximum: 2_000 }
end
```

## 2. Respostas do formulário

- [ ] Liste os campos no strong params. Se as respostas forem um JSON livre,
      use `permit(campo: {})`, **nunca `permit!`**, e valide formato e tamanho
      no model, como em `AvaliacaoClinica#formato_dos_dados_formulario`.
- [ ] O ideal é que cada formulário declare os campos e as respostas válidas
      (um schema), em vez de aceitar qualquer chave.

## 3. Permissão (Pundit)

- [ ] Crie `app/policies/<model>_policy.rb` herdando de `ApplicationPolicy`.
      Libere cada ação com uma lista explícita de papéis, nunca com `true`.
- [ ] Defina `Scope#resolve` se houver listagem.
- [ ] Teste cada papel em `test/policies/`.

```ruby
class ExemploPolicy < ApplicationPolicy
  LEITURA = %w[operador consultor admin].freeze
  ESCRITA = %w[operador admin].freeze

  def show? = LEITURA.include?(user.role)
  def create? = ESCRITA.include?(user.role)
end
```

## 4. Rotas e controller

- [ ] `resources :exemplos, only: [ ... ]` só com as actions que existem.
- [ ] `authorize` na **primeira linha** de cada action, antes de ler ou gravar.
      Na listagem, use `policy_scope(Exemplo)`.
- [ ] Busque registros por `policy_scope(...).find(params[:id])`, nunca por
      `Exemplo.find` direto. Assim ninguém acessa um registro só trocando o ID
      na URL.
- [ ] Em erro, devolva o que a pessoa digitou, nunca dados de outro cadastro.

## 5. Logs

- [ ] Adicione a chave raiz dos parâmetros (o `param_key` do model, como
      `:exemplo`) em `config/initializers/filter_parameter_logging.rb`.
- [ ] Teste com `request.filtered_parameters` (exemplo em
      `test/controllers/avaliacoes_clinicas_controller_test.rb`).

## 6. Views

- [ ] Sem `html_safe`, `raw` ou `<%==`.
- [ ] Sem `<script>` inline nem atributo `style`: a CSP bloqueia os dois. Use
      classes do Tailwind.
- [ ] Botões e links de ações aparecem só para quem pode executá-las:
      `<% if policy(Exemplo).create? %>`.

## 7. Testes mínimos

- [ ] Cada papel faz só o que pode, e o consultor não grava nada.
- [ ] Os dados ficam cifrados no banco (`ciphertext_for`) e na auditoria.
- [ ] Os parâmetros não aparecem no log.
- [ ] Os valores no limite de tamanho cabem nas colunas.
- [ ] Fixtures e seeds só com dados fictícios. Para CPF, use `Cpf.gerar`.

## 8. Antes do pull request

```bash
docker compose exec web bin/rails test
docker compose exec web bin/brakeman
docker compose exec web bin/rubocop
```
