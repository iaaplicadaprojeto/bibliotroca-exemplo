> **Você está na branch `sprint-3`.** Ela está congelada no estado em
> que o projeto deveria estar ao final daquela sprint: aqui existe só o
> que já tinha sido feito até ali. O estado final do projeto está na
> branch `main`.
>
> Nesta branch ainda não há API, site nem testes. O `./infra/deploy.sh`
> cria o bucket, a tabela, o papel e a função `gravar`, e termina em
> `ambiente criado`. Para ver a função gravando, invoque com os eventos
> da pasta `eventos/`:
>
> ```
> lstk aws lambda invoke --function-name bibliotroca-gravar \
>   --payload fileb://eventos/gravar-ok.json saida.json
> cat saida.json
> ```

# BiblioTroca

Catálogo de livros que moradores de um bairro disponibilizam para troca
entre si.

Este é o **projeto-exemplo** de *Projeto em Ciência de Dados IV*
(IBM8942). Ele existe para que vocês possam ver, rodando, tudo que o
roteiro pede — a documentação de cada sprint, os scripts, o código das
funções, os testes e as medições. O cenário, BiblioTroca, está entre os seis
oficiais — mas aqui ele está resolvido. Use este repositório para ver a
forma, não para copiar o conteúdo. Se o projeto da sua equipe sair
parecido com este, alguma coisa deu errado; e quem escolher o
BiblioTroca precisa de um recorte diferente deste, com outra chave de
partição e outra consulta.

## O que tem em cada branch

Cada branch está congelada no estado em que o projeto deveria estar ao
final daquela sprint. Troque de branch para ver o projeto crescendo.

| Branch | O que existe nela |
|---|---|
| `sprint-1` | `docs/01-requisitos.md` e a estrutura de pastas. Nenhuma linha de código. |
| `sprint-2` | `+ docs/02-arquitetura.md` e `docs/diagrama.md`. Ainda nenhuma linha de código. |
| `sprint-3` | `+ infra/` até a função `gravar`, e `app/gravar/`. O ambiente sobe por script. |
| `sprint-4` | `+ app/consultar/`, `app/marcar/`, a API, o site. A aplicação no ar. |
| `sprint-5` | `+ testes/` e `docs/03-validacao.md`. O que foi prometido, medido. |
| `main` | O estado final, igual à `sprint-5`. |

```
git switch sprint-3        # ver o projeto como ele estava ali
git switch main            # voltar ao estado final
```

## Antes de rodar

**1. O emulador precisa estar de pé.** Esta é a primeira linha porque
foi o primeiro erro de quem tentou rodar sem saber:

```
lstk status
```

Se não disser que está rodando, suba com `lstk start` e espere. A
primeira vez é lenta, porque baixa a imagem — pode passar de um minuto
sem imprimir nada. Não interrompa: interromper na metade deixa recursos
pela metade, e aí é preciso rodar `./infra/destroy.sh` antes de tentar
de novo.

**2. O AWS CLI precisa estar no PATH.** O `lstk aws` não tem cliente
próprio: ele chama o AWS CLI da sua máquina.

```
aws --version
```

**3. No Windows, use o Git Bash a partir daqui.** Os scripts são bash.
O PowerShell da Sprint 0 serviu para instalar; para rodar o projeto,
é o Git Bash.

## Rodar

```
./infra/deploy.sh
```

Um comando, do zero. Ao final ele imprime o endereço da API e o
endereço do site. Abra o site no navegador: o formulário cadastra e a
lista consulta.

Para conferir que tudo faz o que foi prometido:

```
./testes/executar.sh      # os seis criterios de aceite da Sprint 1
./testes/medir.sh         # o p95 da consulta, que o RNF-01 exige
```

Para derrubar tudo:

```
./infra/destroy.sh
```

O par `deploy.sh` → `destroy.sh` → `deploy.sh` tem que funcionar sempre.
É isso que o RNF-03 exige, e é o que prova que nenhum recurso foi criado
por clique.

## Como as pastas estão organizadas

```
docs/        os três documentos entregues, um por template
  01-requisitos.md       Sprint 1, Template 1
  02-arquitetura.md      Sprint 2, Template 2
  diagrama.md            Sprint 2, o diagrama em Mermaid
  03-validacao.md        Sprint 5, Template 3

infra/       tudo que cria recurso na nuvem
  config.sh              os nomes dos recursos, em um lugar só
  01-bucket.sh  ...  08-funcao-marcar.sh
  deploy.sh              chama os anteriores na ordem
  destroy.sh             desfaz
  openapi.yaml           a descrição da API

app/         o código que roda na nuvem
  gravar/handler.py      RF-01, RF-02, RF-05
  consultar/handler.py   RF-03
  marcar/handler.py      RF-04
  site/index.html        a camada de apresentação

eventos/     chamadas de exemplo, para invocar a função sem a API
  gravar-ok.json         o cadastro completo, com a foto (C1)
  gravar-sem-bairro.json o cadastro sem bairro, que é recusado (C2)

testes/      o que prova que funciona
  executar.sh            traduz os seis critérios BDD
  medir.sh               mede o p95 da consulta
```

## O que ler primeiro, se o seu objetivo é entender

1. `docs/01-requisitos.md` — o que foi prometido.
2. `docs/02-arquitetura.md` §6.2 — por que o bairro é a chave de
   partição. É a decisão que mais aparece na arguição.
3. `app/gravar/handler.py` — o comentário do topo explica o que mudou
   em relação ao código genérico do roteiro, e por quê.
4. `docs/03-validacao.md` §4 — a matriz de rastreabilidade, que é onde
   a promessa encontra a evidência.
5. `docs/03-validacao.md` §3.2 — como se verifica um requisito que
   não tem número para medir.

## Uma coisa que este repositório deixa à vista

O código genérico do roteiro da Sprint 3 guarda no S3 a ficha do
registro em JSON, e não imagem nenhuma. Só que este projeto prometeu,
no RF-02 da Sprint 1, que a foto da capa seria guardada no S3.

Copiado como estava, aquele código rodaria, os testes passariam, e
mesmo assim a promessa não estaria cumprida. Nada avisaria: nenhum
erro, nenhum teste vermelho. A diferença só aparece para quem lê o
código com o documento aberto ao lado.

Por isso a função `gravar` deste repositório guarda as duas coisas, a
ficha e a imagem, desde a branch `sprint-3`. O comentário no topo do
`app/gravar/handler.py` explica a troca. Na Sprint 5, a matriz de
rastreabilidade liga o RF-02 a uma evidência que existe — a
verificação C1b do `testes/executar.sh` — em vez de encontrar o buraco
tarde demais.

É o melhor argumento para adaptar o código do roteiro lendo o
documento, e não só trocando os nomes.
