# Como adicionar um formulário clínico

Um formulário novo é um arquivo YAML em `config/formularios/`. O Prisma gera a
tela, a lista, a visualização e a validação a partir dele, e o formulário
aparece sozinho em **Formulários**, no menu lateral. O exemplo completo é o
[seguimento de TB](../config/formularios/seguimento_tb.yml).

## 1. Crie o arquivo

`config/formularios/<chave>.yml`, em que `<chave>` vira a URL
(`/formularios/<chave>/avaliacoes`). Use só letras minúsculas, números e `_`.

```yaml
titulo: Nome curto do formulário
descricao: Uma frase sobre quando ele é usado.
encerramento: data_encerramento   # opcional: pergunta de data que "fecha" o registro
lista: [numero_sinan]             # opcional: perguntas que viram colunas na lista

secoes:
  - titulo: Identificação
    perguntas:
      - { numero: 1, chave: prontuario_sah, texto: Prontuário SAH, tipo: texto, maximo: 30, paciente: true }
      - { numero: 2, chave: iniciais, texto: Iniciais do nome, tipo: texto, maximo: 10, obrigatoria: abertura, paciente: true }
  - titulo: Exames
    perguntas:
      - numero: 3
        chave: resultado
        texto: Resultado do exame
        tipo: unica
        obrigatoria: abertura
        opcoes:
          "1": Positivo
          "2": Negativo
```

## 2. Campos de cada pergunta

| Campo | Para quê |
|-------|----------|
| `numero` | Número mostrado na tela (use o do formulário em papel) |
| `chave` | Nome da resposta no banco: minúsculas, números e `_` |
| `texto` | Enunciado |
| `tipo` | `texto`, `numero` (inteiro), `data`, `unica` (uma opção) ou `multipla` (várias) |
| `opcoes` | Para `unica`/`multipla`: `"código": rótulo`. Use os códigos oficiais (ex.: SINAN) |
| `obrigatoria` | `abertura` (sempre) ou `encerramento` (quando a pergunta de `encerramento:` estiver preenchida) |
| `exclusivas` | Códigos que não podem ser marcados junto com outros (ex.: `["0"]` para "Não") |
| `condicao` | `{ pergunta: chave, valores: ["2", "3"] }`: só vale para esses valores |
| `paciente` | `true` para `prontuario_sah`, `prontuario_aghuse` e `iniciais`, que ficam no cadastro do paciente |
| `ajuda` | Texto curto embaixo do campo |
| `minimo` / `maximo` | Limites do número, ou tamanho máximo do texto (padrão: 200) |
| `nao_maior_que` | Número não pode passar o de outra pergunta (ex.: contatos avaliados) |
| `nao_antes_de` | Data não pode ser anterior à de outra pergunta (ex.: revisão do encerramento) |

Listas de opções repetidas podem usar âncoras YAML (`&nome` e `*nome`), como
em `_opcoes` no arquivo do TB.

## 3. Regras que o Prisma confere ao carregar

O arquivo é conferido ao carregar e nos testes, então um erro de definição
nunca chega a quem preenche:

- chaves únicas e válidas, tipos conhecidos, `unica`/`multipla` com opções;
- `condicao` aponta para a pergunta **imediatamente anterior**, de escolha
  única, com códigos que existem. Isso permite mostrar e esconder a pergunta só
  com CSS, sem JavaScript;
- `nao_maior_que`, `nao_antes_de`, `encerramento` e `lista` apontam para
  perguntas existentes do tipo certo;
- `paciente: true` só nas três perguntas de identificação.

## 4. O que você ganha sem escrever código

- **Criptografia:** todas as respostas ficam no JSON cifrado.
- **Logs:** as respostas viajam dentro de `avaliacao_clinica`, que já é filtrado.
- **Auditoria:** criação e cada edição ficam na tabela `versions`, com autor.
- **Validação:** só perguntas declaradas e códigos existentes são aceitos.
- **Permissões:** as mesmas do TB (`AvaliacaoClinicaPolicy`). Operador e admin
  registram e editam, consultor só lê e ninguém exclui.

## 5. Cuidados

- **Colete o mínimo.** Não acrescente nome completo, CPF ou endereço se o
  formulário original não pede.
- **Depois que houver respostas gravadas, não renomeie nem remova perguntas ou
  códigos.** As notificações antigas passariam a ter respostas "desconhecidas"
  e não conseguiriam mais ser salvas. Para mudar, acrescente uma pergunta ou
  opção nova, ou escreva uma migration que converta as respostas existentes.
- Conferir rótulos, códigos e obrigatórias com a equipe que usa o formulário
  em papel antes de publicar.

## 6. Testes

Acrescente em `test/models/formulario_test.rb` pelo menos:

- a numeração e as perguntas obrigatórias batem com o formulário original;
- respostas mínimas válidas passam;
- cada condição e cada regra entre perguntas funciona.

O resto já vem pronto para qualquer formulário: o
`test/integration/formularios_completos_test.rb` responde todas as perguntas
do arquivo novo, registra, confere a visualização e a edição e procura campos
sem rótulo; os testes de permissão e de segurança valem para todos. Antes do
pull request:

```bash
docker compose exec web bin/rails test
docker compose exec web bin/brakeman
docker compose exec web bin/rubocop
```

## Quando é preciso código

- Um tipo de pergunta novo (ex.: lista de pessoas, anexo): `Formulario` e
  `_pergunta.html.erb`.
- Uma regra entre perguntas diferente das de comparação: `Formulario#validar`.
- Permissões diferentes por formulário: `AvaliacaoClinicaPolicy`, olhando
  `record.formulario`, com testes para cada papel.
- Identificação do paciente com outros campos: `Paciente` e
  `Formulario::CAMPOS_DO_PACIENTE`, com migration e criptografia.
