# Como criar um formulário clínico

Os formulários são montados no **gerador de formulários**, sem escrever código:
**Configurações > Gerador de formulários**, só para o admin. O Prisma gera a
tela de registro, a lista, os detalhes e a validação a partir do que o admin
monta, e o formulário aparece no menu de quem foi liberado.

O Prisma não traz formulário nem modelo nenhum: uma instalação nova começa
limpa, e cada formulário é montado do zero no gerador.

## Passo a passo

1. **Novo formulário.** Dê um título (como aparece no menu) e diga **de qual
   instituição** ele é e **em quais setores dela** vai valer (pelo menos um). O formulário começa como
   **rascunho da versão 1**: ninguém além do admin o vê, e os setores só passam
   a valer quando ele for publicado.
2. **Cabeçalho.** No rascunho, preencha:
   - **finalidade**: completa a frase "Dados coletados para ..." (LGPD, art. 6º, I);
   - **base legal**: por exemplo, "cumprimento de obrigação legal (LGPD, art.
     11, II, "a")". **Valide as duas com o encarregado de dados (DPO)**;
   - **numeração**: automática (1, 2, 3...) ou a do formulário em papel, em que
     cada pergunta tem o seu número;
   - **pergunta de encerramento** (opcional): uma data que "fecha" o registro;
   - **colunas da lista** (até 3): o que aparece na lista de registros, além
     dos prontuários e das iniciais.
3. **Seções e perguntas.** Crie as seções e, em cada uma, as perguntas. Cada
   pergunta tem enunciado, tipo, se é obrigatória e um texto de ajuda opcional,
   além dos campos do tipo (abaixo). **Nova pergunta**, **Editar** e **Remover**
   abrem num modal por cima do rascunho, e os campos mudam conforme o tipo
   escolhido. Os botões **Subir** e **Descer** mudam a ordem; uma pergunta sem
   condição passa de uma seção para outra.
4. **"Se escolher isso, aparece aquilo".** Numa pergunta de escolha, use
   **Nova pergunta que aparece conforme esta resposta** e marque as opções que
   a mostram. Ela fica logo abaixo, recuada, e pode ter as próprias
   dependentes (até 3 níveis).
5. **Prévia.** Mostra o formulário como quem preenche vai ver, com as
   condições funcionando. Nada é gravado.
6. **Revisar e publicar.** A revisão mostra o que muda em relação à versão
   publicada, o que ainda impede a publicação e os avisos de minimização. Para
   publicar, confirme que a finalidade e a base legal foram validadas com o
   DPO e que cada pergunta é necessária.
7. **Liberar.** Publicado, o formulário vale nos setores escolhidos e é
   liberado para cada pessoa (Usuários > Liberações), registrando ou só
   consultando.
8. **Excluir** (se precisar). Um formulário que **nunca recebeu notificação**
   pode ser excluído, publicado ou não, pelo **Excluir** da lista ou da tela
   dele. A confirmação mostra o que sai junto (as versões, a habilitação nos
   setores e as liberações das pessoas); num formulário já publicado, é preciso
   marcar que ele não poderá ser recuperado. Com notificações, não: o registro
   clínico é preservado. Para só tirar mudanças ainda não publicadas, use
   **Descartar rascunho**, no rascunho.

## Instituição, setores e acompanhamento

Cada formulário **pertence a uma instituição** e só vale em setores dela. Os
setores são escolhidos na criação e mudam depois na tela do formulário
(Gerador de formulários > o formulário > Setores) ou na tela de cada setor
(Instituições e setores). Tirar o formulário de um setor tira também as
liberações dele ali; um setor com notificações do formulário não sai. A
instituição só pode ser trocada enquanto o formulário não estiver em nenhum
setor. Para usar o mesmo formulário em outra instituição, monte outro nela.

A tela do formulário mostra, em cada setor, o **movimento** (quantas
notificações e a data do último registro) e avisa o setor **parado**: com o
formulário publicado e sem registro há mais de 30 dias. Embaixo, o
**histórico** diz quem incluiu ou tirou o formulário de cada setor, e quando,
como guardado na auditoria.

Os formulários criados antes dessa regra (2026-10-09) ficaram com a
instituição em que tinham mais notificações. Um setor de outra instituição
que já tinha o formulário continua com ele, porque as notificações estão lá,
e aparece marcado como anterior à regra.

Todo formulário pede, antes das perguntas dele, a **identificação do
paciente** (prontuários SAH e AGHUSE e as iniciais). Ela não é montada no
gerador: é ela que liga as notificações ao paciente certo.

## Tipos de pergunta

| Tipo | Na tela | Campos do tipo |
|------|---------|----------------|
| Texto curto | uma linha | limite de caracteres (até 200; padrão 100) |
| Texto longo | várias linhas | limite de caracteres (até 5000; padrão 1000) |
| Número | número | mínimo, máximo, casas decimais (0 a 3) e "não pode ser maior que" outra pergunta de número |
| Data | calendário | aceita data futura?, e "não pode ser antes de" outra pergunta de data |
| Escolha única | botões, uma opção | opções |
| Lista suspensa | lista, uma opção | opções |
| Múltipla escolha | caixas, várias opções | opções e opções exclusivas |

**Opções** são escritas uma por linha, no formato `código, rótulo`:

```
1, Positiva
2, Negativa
9, Ignorado
```

O código é obrigatório: use os oficiais quando houver (ex.: SINAN). Um rótulo
pode ter vírgula (`1, Sim, com restrições`): o que vem depois da primeira
vírgula é o rótulo. **Opções exclusivas** (múltipla escolha) são as que não
podem ser marcadas junto com outras, como "Não" ou "Nenhum".

**Obrigatória**: "sempre" precisa estar respondida para salvar; "só para
encerrar" passa a ser exigida quando a pergunta de encerramento é preenchida
(como num acompanhamento aberto no início do tratamento e completado mês a
mês). Uma pergunta que depende de outra só é exigida quando aparece.

## Versões

- O rascunho é editado à vontade. **Publicado, a versão nunca mais muda**, e
  passa a ser a que se preenche.
- Para mudar um formulário publicado, crie o **rascunho da próxima versão**
  (ele começa igual à publicada), mude e publique. Até lá, a versão publicada
  continua valendo; o rascunho pode ser descartado sem efeito nenhum.
- **Cada notificação continua com a versão em que foi registrada**: as
  perguntas, os códigos e os rótulos dela não mudam quando o formulário ganha
  uma versão nova, nem na edição. Uma pergunta removida continua nas
  notificações antigas.
- Se o formulário ganhar uma versão nova enquanto alguém preenche, o envio
  volta com a versão nova e o que foi digitado, para a pessoa conferir.
- Um formulário que **nunca foi publicado** pode ser excluído. O publicado
  fica guardado para sempre, com todas as versões: elas dizem para que e com
  qual base legal cada dado foi coletado.
- A chave de cada pergunta (mostrada no rascunho) é gerada do enunciado e
  nunca muda nem é reaproveitada: uma pergunta removida e outra criada depois
  não se confundem nas respostas.

## O que o gerador confere

Toda mudança é conferida antes de gravar; uma mudança inválida não grava nada
e mostra o motivo. Entre outras coisas:

- só campos conhecidos, cada um com o tipo certo, e textos com tamanho máximo
  (título 150, enunciado 500, ajuda 500, rótulo de opção 200, finalidade e
  base legal 1000 caracteres);
- até 30 seções, 300 perguntas, 100 opções por pergunta (3000 no formulário),
  10 perguntas dependentes de uma mesma pergunta e 3 níveis de condição;
- códigos de opção únicos (até 16 letras, números, ponto, traço ou
  sublinhado) e rótulos únicos em cada pergunta;
- uma condição depende de uma pergunta de escolha logo acima, na mesma seção,
  e usa opções que ela tem;
- comparações ("não maior que", "não antes de") apontam para outra pergunta do
  tipo certo; a pergunta de encerramento é uma data sem condição, que não
  aceita data futura e não é obrigatória;
- na numeração do papel, cada pergunta tem um número, sem repetir;
- caracteres invisíveis e de direção do texto são tirados de tudo o que é
  digitado.

Para publicar, também: finalidade, base legal, pelo menos uma pergunta e
nenhuma seção vazia. Uma pergunta usada como coluna da lista, como
encerramento ou numa comparação só é removida depois de tirar esse uso.

## Cuidados (LGPD)

- **Colete o mínimo** (art. 6º, III). A revisão avisa quando uma pergunta
  parece pedir CPF, nome, endereço, telefone, e-mail, documento, Cartão SUS ou
  data de nascimento: confirme com o DPO que é necessário.
- **Texto livre** pode receber o que não devia. Prefira opções; se precisar de
  texto, oriente a equipe a não escrever ali dados que identifiquem o paciente.
- **Depois de publicado, não troque o sentido de um código** numa versão nova
  (o "2" que era "Negativa" virar "Positiva"): as notificações antigas
  continuam com o rótulo antigo, e quem analisa os dados pode confundir.
  Crie um código novo.
- Confira rótulos, códigos e obrigatórias com a equipe que usa o formulário
  em papel antes de publicar.

## Testes (para quem mantém o código)

O motor de formulários é testado com formulários fictícios, definidos em
[test/formularios_de_teste.rb](../test/formularios_de_teste.rb) no formato que
o gerador grava (ver `DefinicaoDeFormulario`). O `acompanhamento` é o das
fixtures; `test/integration/formularios_completos_test.rb` publica cada um,
responde todas as perguntas, confere a visualização e a edição e procura
campos sem rótulo. Antes do pull request:

```bash
docker compose exec web bin/rails test
docker compose exec web bin/brakeman
docker compose exec web bin/rubocop
```

## Quando é preciso código

- Um tipo de pergunta novo (ex.: anexo, tabela de pessoas): `DefinicaoDeFormulario`
  (leitura, normalização, validação), `PerguntaDoGerador` e as telas
  (`avaliacoes_clinicas/_pergunta.html.erb` e `configuracoes/perguntas/_formulario.html.erb`).
- Uma regra entre perguntas diferente das comparações: `DefinicaoDeFormulario#validar`.
- Permissões diferentes por formulário: `AvaliacaoClinicaPolicy`, olhando
  `record.formulario`, com testes para cada papel.
- Identificação do paciente com outros campos: `Paciente` e
  `Paciente::IDENTIFICACAO`, com migration e criptografia.
- Apertar uma regra do motor (um limite menor, por exemplo): as versões já
  publicadas são relidas com a regra nova. Converta as que não passariam
  numa migration antes.
