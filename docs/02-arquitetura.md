# Documento de Arquitetura

Projeto: BiblioTroca\
Cenário oficial escolhido: BiblioTroca\
Data: 14/10/2026\
Versão: 1.0

Entregável da Sprint 2, no formato do Template 2. As seções têm os mesmos números do template.

## 1. Requisitos não funcionais

Fórmula obrigatória: `[Categoria] + [Métrica Numérica Mensurável] + [Condição de Execução]`.

### RNF-01

```
requisito
  [Performance] A consulta dos livros de um bairro deve
  responder em no máximo 800 ms no percentil 95, com até
  500 livros na partição consultada e 30 requisições
  seguidas.

serviço AWS
  Amazon DynamoDB

pilar do Well-Architected
  4, Eficiência de Performance

razão
  A chave de partição por bairro mantém a consulta dentro
  de uma única partição, o que sustenta o tempo declarado.
  Um scan passaria no teste com 10 livros e falharia com
  10 mil, porque o tempo dele cresce com a tabela inteira.
  O query cresce só com a partição.
```

### RNF-02

```
requisito
  [Segurança] A função de gravação deve ter zero
  permissões de exclusão, e só pode gravar dados na tabela
  e no bucket deste projeto — o que se confere na política
  anexada ao papel.

serviço AWS
  AWS IAM

pilar do Well-Architected
  2, Segurança

razão
  O menor privilégio aqui não é teoria: a função recebe
  conteúdo vindo da internet. Se ela pudesse apagar, uma
  falha dela viraria perda de dado, e não só dado errado.
```

### RNF-03

```
requisito
  [Reliability] O ambiente inteiro deve ser reconstruído
  em no máximo 3 minutos, com um único comando, partindo
  de um emulador sem nenhum recurso.

serviço AWS
  Amazon S3, Amazon DynamoDB, AWS Lambda, Amazon API
  Gateway e o papel no AWS IAM, todos criados pelo
  deploy.sh

pilar do Well-Architected
  3, Confiabilidade

razão
  É o requisito que torna o deploy.sh obrigatório. Enquanto
  existir um recurso criado por clique, a reconstrução
  depende de alguém lembrar do clique — e ninguém lembra.
```

### RNF-04

```
requisito
  [Observabilidade] Toda execução das funções deve deixar
  no CloudWatch Logs uma linha com o bairro e o resultado
  da operação, visível em no máximo 10 segundos após a
  chamada.

serviço AWS
  Amazon CloudWatch Logs

pilar do Well-Architected
  1, Excelência Operacional

razão
  Sem o registro, uma gravação que falhou e uma que nunca
  chegou parecem iguais. O print dentro da função é o que
  torna o CloudWatch útil, e por isso o registro é
  requisito, e não hábito. Ele serve para operar o sistema
  no dia a dia, e não para recuperá-lo — por isso o pilar
  1, e não o 3.
```

### 1.1 Resumo

| ID | Categoria | Métrica | Serviço AWS | Pilar |
|---|---|---|---|---|
| RNF-01 | Performance | p95 ≤ 800 ms, até 500 livros na partição | Amazon DynamoDB | 4 |
| RNF-02 | Segurança | zero permissões de exclusão | AWS IAM | 2 |
| RNF-03 | Reliability | reconstrução ≤ 3 min, um comando | S3, DynamoDB, Lambda, API Gateway, IAM | 3 |
| RNF-04 | Observabilidade | registro visível ≤ 10 s | Amazon CloudWatch Logs | 1 |

Pilares: 1 Excelência Operacional, 2 Segurança, 3 Confiabilidade, 4 Eficiência de Performance, 5 Otimização de Custos, 6 Sustentabilidade.

### 1.2 O pilar não contemplado

O pilar 5, Otimização de Custos, não virou requisito. Em ambiente emulado não existe fatura, então qualquer número de custo seria inventado — e requisito inventado é pior do que requisito ausente, porque parece verificado sem ter sido.

Mesmo sem o requisito, o desenho escolhe serviços cobrados por uso: parado, o Lambda não custa nada, e o DynamoDB em modo sob demanda cobra só o espaço ocupado. Um servidor ligado o mês inteiro para atender a um catálogo de bairro seria a decisão cara.

O pilar 6, Sustentabilidade, fica de fora pela mesma razão: sem medir o consumo de máquina, qualquer número seria inventado.

## 2. A arquitetura em três camadas

| Camada | O que fica nela, neste projeto | Serviço AWS |
|---|---|---|
| Apresentação | A página `index.html`, com o formulário de cadastro e a lista do bairro | Amazon S3, em modo site estático |
| Negócio | As três funções, `gravar`, `consultar` e `marcar`, e a porta de entrada que as chama | AWS Lambda e Amazon API Gateway |
| Dados | A tabela de livros e os arquivos: as capas e as fichas | Amazon DynamoDB e Amazon S3 |

### 2.1 Como a separação é garantida

A página é um arquivo estático servido pelo S3, e não tem credencial nenhuma: o `config.js` carrega apenas o endereço público da API. Mesmo que alguém leia todo o código-fonte da página no navegador — e qualquer pessoa pode —, não há nada ali que permita falar com o DynamoDB.

O único caminho até os dados é o API Gateway, e o API Gateway só sabe invocar as três funções. Quem decide o que pode ser gravado é a função, não o navegador. É por isso que a validação dos campos obrigatórios vai ficar na função `gravar`, e não no JavaScript da página: a validação da página, se houver, é conveniência para quem usa; a da função é a que vale.

A permissão de falar com o DynamoDB fica no papel do IAM anexado às funções, do lado da AWS, e nunca chega ao navegador.

## 3. Estilo arquitetural

| Item | Resposta |
|---|---|
| Estilo adotado | Distributed: três funções independentes atrás de um ponto único de entrada |
| Por que ele serve a este projeto | Cadastro, consulta e marcação têm cargas muito diferentes: a consulta é o que mais acontece, o cadastro e a marcação são raros. Funções separadas crescem cada uma no seu ritmo, e uma falha no cadastro não derruba a consulta. |
| Estilo descartado | Call and Return |
| Por que foi descartado | Seria um programa único, num servidor, com uma rotina para cada operação. O servidor ficaria ligado o mês inteiro para atender a um catálogo de bairro, e qualquer falha nele derrubaria as três operações de uma vez. |

Estilos: Data Flow, Call and Return, Implicit Invocation, Repository, Distributed, Virtual Machines.

## 4. Padrões arquiteturais identificados

| Padrão | Onde ele aparece no meu desenho | O que ele resolve aqui |
|---|---|---|
| API Gateway | O Amazon API Gateway, como porta única das três rotas | A página conhece um endereço só, e as funções não precisam cuidar de roteamento |
| MVC | A página é a visão; as três funções são o controle; o livro, na tabela e no bucket, é o modelo | A página pode ser refeita inteira sem tocar na regra que recusa cadastro incompleto, e a regra pode mudar sem mexer na página |

### 4.1 O padrão que faria falta

**Circuit Breaker.** Hoje, se o DynamoDB ficasse lento, a função de consulta ficaria esperando até o tempo-limite e devolveria erro — uma vez para cada requisição. Com um Circuit Breaker, depois de algumas falhas seguidas a função pararia de tentar por alguns segundos e devolveria uma resposta de indisponibilidade imediata.

Ele entraria dentro da função `consultar`, em volta da chamada ao `query`. Não entra no desenho porque, no recorte atual, há um só consumidor e nenhuma dependência externa ao projeto — o padrão resolveria um problema que ainda não existe aqui, e código que resolve problema inexistente também custa manutenção.

## 5. Diagrama de arquitetura de ponta a ponta

O diagrama está em `docs/diagrama.md`, em Mermaid, e é desenhado pelo próprio GitHub ao abrir o arquivo.

### 5.1 Legenda das caixas

| Caixa | Serviço AWS | O que ela faz | Requisito que a justifica |
|---|---|---|---|
| Navegador | — | Exibe o formulário e a lista, envia a foto em base64 e o aviso de troca | US-01, US-02, US-03 |
| Site estático | Amazon S3 | Serve `index.html` e `config.js` | US-01, US-02, US-03 |
| Entrada da API | Amazon API Gateway | Recebe as três rotas e invoca a função certa | US-01, US-02, US-03: é por ela que passam as três rotas |
| Função gravar | AWS Lambda | Valida, salva a capa e a ficha, grava o livro | RF-01, RF-02, RF-05 |
| Função consultar | AWS Lambda | Faz o `query` na partição do bairro e ordena | RF-03, RNF-01 |
| Função marcar | AWS Lambda | Regrava o livro como indisponível | RF-04, US-03 |
| Tabela de livros | Amazon DynamoDB | Guarda o livro, com `bairro` como chave de partição | RF-01, RNF-01 |
| Bucket de arquivos | Amazon S3 | Guarda a capa em `capas/` e a ficha em `fichas/` | RF-02 |
| Papel da função | AWS IAM | Concede às funções só o que elas usam | RNF-02 |
| Registros | Amazon CloudWatch Logs | Guarda o que cada execução imprimiu | RNF-04 |

### 5.2 O fluxo de uma requisição

O morador preenche título, autor, bairro e estado de conservação, escolhe a foto da capa e clica em "Disponibilizar". O navegador lê o arquivo, converte para base64 e envia tudo em um único POST para a rota `/livros` do API Gateway.

O API Gateway invoca a função `gravar`. Ela lê o corpo da requisição, confere os campos obrigatórios e recusa com 400 se faltar algum, dizendo qual. Confere se o estado é um dos três aceitos. Gera o identificador do livro.

A foto vai primeiro: a função decodifica o base64, recusa acima de 2 MB e grava a imagem no S3 em `capas/<bairro>/<id>.jpg`. Só depois disso o livro é gravado na tabela. A ordem é a preocupação de Reliability levantada no FURPS da Sprint 1 — não pode existir livro listado apontando para uma imagem que nunca subiu.

Com o livro na tabela, a função grava também a ficha em JSON em `fichas/<bairro>/<id>.json`, imprime uma linha de registro e devolve 201 com o identificador e os dois endereços.

A página então consulta sozinha: um GET em `/livros?bairro=<bairro>`, que chega à função `consultar`. Ela faz um `query` na partição do bairro, descarta os já trocados, ordena do mais recente para o mais antigo e devolve a lista. A tabela aparece preenchida na tela.

### 5.3 O que acontece se uma caixa cair

| Caixa | Efeito da queda | O que o sistema ainda consegue fazer |
|---|---|---|
| Site estático | Ninguém chega pela tela | A API continua respondendo: outro cliente, ou o `curl`, continua cadastrando e consultando |
| Função gravar | Nenhum livro novo entra | A consulta continua devolvendo todo o acervo já cadastrado |
| Função consultar | A tela fica vazia | Os cadastros continuam sendo aceitos e nada se perde; a lista volta quando a função voltar |
| Tabela de livros | Nada funciona | Nada. As fichas em JSON no S3 permitem reconstruir o acervo, mas não as marcações de trocado — e isso é recuperação, não operação |
| Bucket de arquivos | O cadastro com foto falha antes de gravar o livro | A consulta continua. Um cadastro sem foto gravaria o livro, mas falharia ao gravar a ficha, que fica no mesmo bucket |

## 6. Modelo de dados

### 6.1 Entidades

| Entidade | Campo | Tipo | Obrigatório |
|---|---|---|---|
| Livro | `bairro` | texto, chave de partição | sim |
| Livro | `id_livro` | texto, chave de ordenação | sim, gerado |
| Livro | `titulo` | texto | sim |
| Livro | `autor` | texto | sim |
| Livro | `estado` | texto: novo, bom ou gasto | sim |
| Livro | `disponivel` | texto: sim ou nao | sim, começa em "sim" |
| Livro | `criado_em` | texto, data e hora em ISO 8601 | sim, gerado |
| Livro | `capa` | texto, caminho do objeto no S3 | não |

### 6.2 A chave de partição

| Item | Resposta |
|---|---|
| Campo escolhido como chave de partição | `bairro` |
| Campo escolhido como chave de ordenação | `id_livro` |
| Qual consulta esta escolha torna barata | "Todos os livros da Tijuca": um `query` que vai direto a uma partição |
| Qual consulta esta escolha torna cara | "Todos os livros em estado gasto, de qualquer bairro": exige um `scan` na tabela inteira |
| Alternativa descartada | `id_livro` como chave de partição: é único, mas nenhuma tela busca por ele |

A regra para escolher não é qual campo identifica o item, e sim **qual campo aparece em toda consulta**. A pergunta que a tela responde é "o que tem disponível perto de mim", e perto de mim é o bairro. Toda consulta do sistema filtra por bairro; nenhuma pede "todos os livros de todos os bairros".

O identificador do livro **não** serve como chave de partição, embora seja único. Se ele fosse a partição, cada livro ficaria em uma partição só dele, e listar um bairro exigiria varrer a tabela inteira — exatamente o scan que o RNF-01 não permite.

O `id_livro` entra como chave de ordenação, o que dá à chave a unicidade de que ela precisa e permite que um mesmo bairro tenha muitos livros.

### 6.3 O que fica no S3 e o que fica no DynamoDB

| Dado | Onde fica | Por quê |
|---|---|---|
| Os campos do livro: título, autor, bairro, estado, disponibilidade e data | Amazon DynamoDB, tabela `bibliotroca-livros` | São pequenos e são o que a consulta filtra e a lista mostra |
| A foto da capa | Amazon S3, bucket `bibliotroca-capas`, em `capas/<bairro>/<id>.jpg` | Uma foto chega a 2 MB, e um item do DynamoDB aceita no máximo 400 KB. A tabela guarda só o caminho |
| A ficha do cadastro, em JSON | Amazon S3, bucket `bibliotroca-capas`, em `fichas/<bairro>/<id>.json` | Registro imutável do que foi recebido. Nunca é filtrada: é buscada pelo endereço exato |

A ficha em JSON parece redundante com a tabela, e em parte é. Ela existe como registro do que o sistema aceitou naquele dia: se um dia o formato da tabela mudar, as fichas continuam contando o que foi recebido.

## 7. Backlog priorizado

| ID | Item | Tipo | Prioridade |
|---|---|---|---|
| RF-01 | Registrar o livro com título, autor, bairro e estado, gerando o identificador | RF | Alta |
| RF-02 | Armazenar a foto da capa no Amazon S3 | RF | Alta |
| RF-03 | Listar os livros disponíveis do bairro, do mais recente ao mais antigo | RF | Alta |
| RF-05 | Recusar cadastro sem título ou sem bairro, dizendo o campo | RF | Alta |
| US-01 | O morador disponibiliza um livro com a foto da capa | US | Alta |
| US-02 | O morador vê os livros disponíveis no bairro | US | Alta |
| RNF-01 | Consulta do bairro em até 800 ms no p95 | RNF | Alta |
| RF-04 | Alterar o livro para indisponível depois da troca | RF | Média |
| US-03 | O morador marca que o livro já foi trocado | US | Média |
| RNF-02 | Zero permissões de exclusão na função de gravação | RNF | Média |
| RNF-03 | Reconstrução do ambiente em até 3 minutos, com um comando | RNF | Baixa |
| RNF-04 | Registro de cada execução em até 10 segundos | RNF | Baixa |

### 7.1 Distribuição

| Prioridade | Quantidade |
|---|---|
| Alta | 7 |
| Média | 3 |
| Baixa | 2 |

Um pouco mais da metade ficou em alta. A prioridade dos requisitos funcionais é a mesma da Sprint 1: o que lá era essencial aqui é alta, e o que era importante aqui é média. A US-03 e o RF-04 falam da mesma coisa, marcar o livro como trocado, e por isso estão na mesma prioridade.

O RNF-02 ficou em média, e não em alta, pela definição: o sistema funciona sem ele, só não funciona do jeito seguro que foi prometido. Ele entra no recorte porque restringir a política custa poucas linhas a mais do que não restringir.

O RNF-03 e o RNF-04 ficaram em baixa porque servem a quem opera o sistema, e não a quem usa: o morador não sente falta deles no primeiro dia.

## 8. Recorte de implementação

| Item | Resposta |
|---|---|
| O que será implementado nas Sprints 3 e 4 | Os doze itens do backlog. Na Sprint 3, o caminho da gravação: RF-01, RF-02, RF-05, RNF-02, RNF-03 e o registro do RNF-04. Na Sprint 4, o que depende de haver o que listar e de existir a página: RF-03, RF-04, US-01, US-02, US-03 e RNF-01. |
| O que fica especificado e não implementado | Nenhum item do backlog. Do escopo da Sprint 1, fica de fora a consulta de um livro específico pelo identificador: ela não virou requisito, nenhuma tela precisa dela, e com `bairro` como chave de partição ela só seria barata com o bairro junto. Continuam fora do escopo, como declarado na Sprint 1: combinar data e local da troca, cadastro e autenticação de usuário, avaliação ou reputação de quem troca, e entrega, frete ou pagamento. Por força do RD-01, nenhuma localização além do bairro é coletada. |
| Por que este corte | Toda a prioridade alta cabe nas duas sprints. Os itens de média e de baixa entraram por decisão. A US-03 tem custo: obriga a escrever uma terceira função, `marcar`, que o roteiro das Sprints 3 e 4 não ensina, e a razão está escrita logo abaixo desta tabela. O RNF-02, o RNF-03 e o RNF-04 custam pouco: a política de permissões é escrita uma vez, o `deploy.sh` já é o percurso do roteiro, e o registro é uma linha por função. |

A ordem dentro de cada sprint segue a dependência real. O RF-02 não pode vir antes do RF-01 porque o caminho da capa inclui o identificador do livro, e o identificador nasce no RF-01.

A alternativa mais barata seria declarar a US-03 fora do recorte e registrar isso na matriz de rastreabilidade da Sprint 5 — o que é uma resposta legítima. Optamos por implementar porque a US-03 é o que tira da lista os livros que já saíram. Sem ela, quem procura vê o livro, chama o dono e descobre que ele já foi trocado — exatamente a preocupação de Functionality do FURPS da Sprint 1.

## 9. Decisões e alternativas descartadas

| Decisão | Alternativa considerada | Por que não foi escolhida |
|---|---|---|
| Estilo arquitetural: Distributed | Call and Return: um programa único, num servidor, com uma rotina por operação | O servidor ficaria ligado o mês inteiro para atender a um catálogo de bairro, e uma falha em qualquer operação derrubaria as três juntas. |
| Chave de partição: `bairro` | `id_livro` como chave de partição | O identificador é único, mas nenhuma tela busca por ele. Cada livro ficaria sozinho em uma partição, e listar um bairro viraria um scan na tabela inteira, que o RNF-01 não permite. |
| Recorte de implementação: os doze itens | Só a prioridade alta, deixando a marcação de trocado especificada e não implementada | Seria mais barato e é legítimo, mas a lista continuaria mostrando livros que já saíram, e quem procura perderia tempo com contato inútil. |
| Filtrar os disponíveis e ordenar dentro da função | Índice secundário global com `bairro` como partição e `criado_em` como ordenação | A partição de um bairro é pequena por construção: são os livros de um bairro. Filtrar alguns itens em memória custa menos que manter um índice. Acima de alguns milhares de livros por bairro, a decisão certa passa a ser o índice — e esse é o ponto exato em que esta decisão deve ser revista. |
| A foto viaja em base64 dentro do POST | Envio direto ao S3 com URL pré-assinada | A URL pré-assinada é a prática recomendada para arquivos grandes e evita passar a imagem pela função. Com limite de 2 MB e um cadastro raro, o ganho não paga o segundo passo de rede e o código extra nesta disciplina. |
| Regravar o item inteiro ao marcar como trocado | `update_item` com expressão de atualização | O `put_item` é o comando que a Sprint 3 ensina. Regravar a mesma chave substitui o item, e assim a terceira função não introduz nenhum comando novo. Com muitos campos ou escrita concorrente, o `update_item` seria o certo. |
| Bairro como texto livre | Lista fechada de bairros | Texto livre aceita "Tijuca" e "tijuca" como partições diferentes, o que é um defeito conhecido, e fica declarado aqui. A lista fechada resolveria, ao custo de manter a lista. |

## 10. Revisão cruzada recebida

Revisado por: equipe 3\
Data: 15/10/2026

| Pergunta | Resposta da equipe revisora |
|---|---|
| Algum requisito não funcional está sem número? | Não. A revisão perguntou se "zero permissões de exclusão" conta como número, e conta: qualquer pessoa abre a política, conta as ações de exclusão e chega à mesma resposta. |
| O pilar escolhido faz sentido para aquele requisito? | Sim, nos quatro. A revisão questionou o RNF-04 no pilar 1 e não no 3; a razão escrita sustentou a escolha: o registro serve para operar o sistema, não para recuperá-lo. |
| Alguma caixa do diagrama não corresponde a requisito? | Não. A revisão perguntou pela caixa do CloudWatch, que parecia decorativa, e ela está ligada ao RNF-04. |
| O recorte cabe em duas sprints? | Cabe, mas a primeira versão da seção 8 só dizia o que entrava. Lendo só aquele texto, não dava para saber se algo da Sprint 1 havia sido abandonado ou esquecido. |

### 10.1 O que foi ajustado depois da revisão

A seção 8 originalmente listava apenas o que seria implementado. Depois da revisão, ela passou a declarar explicitamente o que fica fora e por quê — e foi aí que apareceu a consulta pelo identificador, que estava no escopo da Sprint 1 e tinha sumido sem ninguém notar.

A seção 9 ganhou a linha sobre o bairro como texto livre, quando a equipe releu o documento para responder à revisão. Ela não estava lá porque era um defeito conhecido que ninguém tinha escrito — e defeito conhecido e não escrito é indistinguível de defeito não percebido.
