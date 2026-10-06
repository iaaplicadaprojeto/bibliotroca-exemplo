#!/usr/bin/env bash
cd "$(dirname "$0")"
source ./config.sh

if [ -f .id-api ]; then
  $AWS apigateway delete-rest-api \
    --rest-api-id "$(cat .id-api)" >/dev/null 2>&1 || true
fi

$AWS lambda delete-function \
  --function-name "$FUNCAO_MARCAR" >/dev/null 2>&1 || true
$AWS lambda delete-function \
  --function-name "$FUNCAO_CONSULTAR" >/dev/null 2>&1 || true
$AWS lambda delete-function \
  --function-name "$FUNCAO_GRAVAR" >/dev/null 2>&1 || true
$AWS iam delete-role-policy --role-name "$PAPEL" \
  --policy-name "${PREFIXO}-politica" >/dev/null 2>&1 || true
$AWS iam delete-role \
  --role-name "$PAPEL" >/dev/null 2>&1 || true
$AWS dynamodb delete-table \
  --table-name "$TABELA" >/dev/null 2>&1 || true
$AWS s3 rb "s3://$BUCKET" --force >/dev/null 2>&1 || true
$AWS s3 rb "s3://$BUCKET_SITE" --force >/dev/null 2>&1 || true

rm -f .id-api .url-api openapi-pronto.yaml
rm -f ../app/site/config.js

echo "recursos removidos"
