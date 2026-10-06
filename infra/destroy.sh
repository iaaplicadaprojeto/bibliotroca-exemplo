#!/usr/bin/env bash
cd "$(dirname "$0")"
source ./config.sh

$AWS lambda delete-function \
  --function-name "$FUNCAO_GRAVAR" >/dev/null 2>&1 || true
$AWS iam delete-role-policy --role-name "$PAPEL" \
  --policy-name "${PREFIXO}-politica" >/dev/null 2>&1 || true
$AWS iam delete-role \
  --role-name "$PAPEL" >/dev/null 2>&1 || true
$AWS dynamodb delete-table \
  --table-name "$TABELA" >/dev/null 2>&1 || true
$AWS s3 rb "s3://$BUCKET" --force >/dev/null 2>&1 || true

echo "recursos removidos"
