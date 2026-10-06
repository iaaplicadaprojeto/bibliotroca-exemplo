#!/usr/bin/env bash
set -e
cd "$(dirname "$0")"
source ./config.sh

CONFIANCA='{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Principal": {"Service": "lambda.amazonaws.com"},
    "Action": "sts:AssumeRole"
  }]
}'

if $AWS iam get-role --role-name "$PAPEL" >/dev/null 2>&1; then
  echo "papel ja existe: $PAPEL"
else
  $AWS iam create-role \
    --role-name "$PAPEL" \
    --assume-role-policy-document "$CONFIANCA" >/dev/null
  echo "papel criado: $PAPEL"
fi

# O roteiro usa "Resource": "*" nos tres blocos da politica, e diz por
# que: e uma simplificacao, e o desafio opcional 1 pede a correcao. Aqui
# ela ja esta feita, porque o RNF-02 do documento de arquitetura promete
# que a funcao so grava na tabela e no bucket deste projeto. Com "*", a
# promessa nao se sustentaria na hora de preencher a matriz.
CONTA=$($AWS sts get-caller-identity --query Account --output text | tr -d '\r')
ARN_TABELA="arn:aws:dynamodb:${REGIAO}:${CONTA}:table/${TABELA}"

# O grupo de registros de uma funcao se chama sempre /aws/lambda/ mais o
# nome dela, e os nomes estao no config.sh antes de qualquer funcao
# existir. O asterisco no fim cobre as funcoes com o prefixo deste
# projeto, e os fluxos de registro dentro de cada grupo — nao a conta.
ARN_LOGS="arn:aws:logs:${REGIAO}:${CONTA}:log-group:/aws/lambda/${PREFIXO}-*"

PERMISSOES='{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "dynamodb:PutItem",
        "dynamodb:Query",
        "dynamodb:GetItem"
      ],
      "Resource": "ARN_TABELA"
    },
    {
      "Effect": "Allow",
      "Action": ["s3:PutObject", "s3:GetObject"],
      "Resource": "arn:aws:s3:::NOME_BUCKET/*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ],
      "Resource": "ARN_LOGS"
    }
  ]
}'
PERMISSOES="${PERMISSOES//ARN_TABELA/$ARN_TABELA}"
PERMISSOES="${PERMISSOES//NOME_BUCKET/$BUCKET}"
PERMISSOES="${PERMISSOES//ARN_LOGS/$ARN_LOGS}"

$AWS iam put-role-policy \
  --role-name "$PAPEL" \
  --policy-name "${PREFIXO}-politica" \
  --policy-document "$PERMISSOES"

echo "politica anexada ao papel $PAPEL"
