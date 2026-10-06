# Política de segurança

O Prisma trata dados pessoais sensíveis de saúde. Relatos de vulnerabilidade
são muito bem-vindos e tratados com prioridade.

## Como relatar

**Não abra issue pública.** Use o relato privado do GitHub: na página do
repositório, aba **Security** → **Report a vulnerability**.

Descreva:

- o problema e o impacto (que dado fica exposto ou alterável, e por quem);
- os passos para reproduzir;
- o commit ou a versão testada.

**Nunca inclua dados reais de pacientes** no relato, nem em capturas de tela ou
logs. Use dados fictícios; para CPF, `Cpf.gerar` gera um número válido.

## O que acontece depois

O projeto é mantido por voluntários. Vamos confirmar o recebimento assim que
possível, investigar e combinar com você a correção e a divulgação. Pedimos que
o problema não seja divulgado antes de haver correção.

## Versões cobertas

Ainda não há versão estável. Só a branch `main` recebe correções.

## Escopo

Entram, por exemplo: acesso a dados sem login ou sem permissão, escalada de
papel, dados sensíveis em texto puro (banco, logs, auditoria, cache do
navegador), XSS, CSRF, injeção de SQL e falhas de configuração no código deste
repositório.

Não entram: falhas na infraestrutura de quem implantou o sistema (servidor,
proxy, rede, backups) que não venham do código ou da documentação do Prisma.

Os controles de segurança existentes estão descritos em
[docs/seguranca.md](docs/seguranca.md).
