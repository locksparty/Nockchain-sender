#!/bin/bash
# check_balance.sh - Vérification rapide du solde

WALLET_CLI="./nockchain-wallet"
CLIENT_ARG=""

if [ "$1" == "--private" ]; then
    CLIENT_ARG="--client private"
fi

echo "=== SOLDE NOCKCHAIN WALLET ==="
echo ""

# Total
$WALLET_CLI list-notes $CLIENT_ARG 2>/dev/null | strings | grep "Assets:" | awk '{sum += $3} END {printf "Total: %.4f NOCK (%d NICK)\n\n", sum/65536, sum}'

# Détail par note
echo "Détail des notes:"
$WALLET_CLI list-notes $CLIENT_ARG 2>/dev/null | grep -A 1 "Name:" | grep -E "Name:|Assets:" | paste - - | awk -F'Assets:' '{
    name = $1
    gsub(/^- Name: \[/, "", name)
    gsub(/\].*$/, "", name)
    assets = $2
    gsub(/^[[:space:]]+/, "", assets)
    printf "  • %.4f NOCK (%s NICK) - %s...\n", assets/65536, assets, substr(name, 1, 40)
}'

echo ""
