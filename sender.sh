#!/bin/bash

# Script d'automatisation pour Nockchain Wallet avec support multi-notes
# Usage: ./nockchain_send.sh <adresse_destinataire> <montant_en_nock> [--private]

set -e  # Arrêt en cas d'erreur

# Couleurs pour l'affichage
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
WALLET_CLI="./nockchain-wallet"
TXS_DIR="./txs"
FEE_NICK=10

# Fonction d'affichage
print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_debug() {
    echo -e "${BLUE}[DEBUG]${NC} $1"
}

# Vérification des arguments
if [ $# -lt 2 ]; then
    print_error "Usage: $0 <adresse_destinataire> <montant_en_nock> [--private]"
    echo "Exemple: $0 3DtF5M4Sr9aCPXbctVJGAd1ND5JLLMFQXrfTF68ToiTxTXkSYQ6gd34Wy4nS18MEaTEnD45At6wt6JLXCd18hKGgnaAKvlz9gDzQBAfszQZZo6MudPwrEYWVAydY3xWdWP9g 10"
    echo "Exemple (node privé): $0 <adresse> 10 --private"
    exit 1
fi

RECIPIENT="$1"
AMOUNT_NOCK="$2"
CLIENT_ARG=""

# Détection du mode client
if [ "$3" == "--private" ]; then
    CLIENT_ARG="--client private"
    print_info "Mode: Node privé"
else
    print_info "Mode: Node public"
fi

# Vérification de l'existence du wallet CLI
if [ ! -f "$WALLET_CLI" ]; then
    print_error "Wallet CLI non trouvé: $WALLET_CLI"
    exit 1
fi

# Conversion NOCK -> NICK
AMOUNT_NICK=$((AMOUNT_NOCK * 65536))
print_info "Montant à envoyer: $AMOUNT_NOCK NOCK = $AMOUNT_NICK NICK"

# Récupération des notes
print_info "Récupération des notes disponibles..."
NOTES_OUTPUT=$($WALLET_CLI list-notes $CLIENT_ARG 2>/dev/null)

# Calcul du total disponible
TOTAL_BALANCE=$($WALLET_CLI list-notes $CLIENT_ARG 2>/dev/null | strings | grep "Assets:" | awk '{sum += $3} END {printf "%d", sum}')
TOTAL_NOCK=$(echo "scale=2; $TOTAL_BALANCE / 65536" | bc)

print_info "Balance totale: $TOTAL_NOCK NOCK ($TOTAL_BALANCE NICK)"

# Parsing des notes
declare -a NOTE_NAMES
declare -a NOTE_BALANCES
NOTE_COUNT=0

while IFS= read -r line; do
    if [[ $line =~ ^-\ Name:\ \[(.+)\] ]]; then
        CURRENT_NOTE="${BASH_REMATCH[1]}"
        NOTE_NAMES[$NOTE_COUNT]="$CURRENT_NOTE"
    elif [[ $line =~ ^-\ Assets:\ ([0-9]+) ]]; then
        CURRENT_BALANCE="${BASH_REMATCH[1]}"
        NOTE_BALANCES[$NOTE_COUNT]="$CURRENT_BALANCE"
        print_debug "Note #$NOTE_COUNT: $(echo "scale=2; $CURRENT_BALANCE / 65536" | bc) NOCK ($CURRENT_BALANCE NICK)"
        NOTE_COUNT=$((NOTE_COUNT + 1))
    fi
done <<< "$NOTES_OUTPUT"

if [ $NOTE_COUNT -eq 0 ]; then
    print_error "Aucune note trouvée dans le wallet"
    exit 1
fi

print_info "Nombre de notes trouvées: $NOTE_COUNT"

# Vérification du solde total suffisant
TOTAL_NEEDED=$((AMOUNT_NICK + FEE_NICK))
if [ "$TOTAL_BALANCE" -lt "$TOTAL_NEEDED" ]; then
    print_error "Solde total insuffisant!"
    print_error "Requis: $TOTAL_NEEDED NICK ($(echo "scale=2; $TOTAL_NEEDED / 65536" | bc) NOCK)"
    print_error "Disponible: $TOTAL_BALANCE NICK ($TOTAL_NOCK NOCK)"
    exit 1
fi

# Sélection des notes nécessaires (tri décroissant)
declare -a SELECTED_NOTES
declare -a SELECTED_BALANCES
CUMULATIVE_BALANCE=0
SELECTED_COUNT=0

# Tri des notes par balance décroissante (bubble sort simple)
for ((i=0; i<NOTE_COUNT; i++)); do
    for ((j=i+1; j<NOTE_COUNT; j++)); do
        if [ ${NOTE_BALANCES[$i]} -lt ${NOTE_BALANCES[$j]} ]; then
            # Swap balances
            temp=${NOTE_BALANCES[$i]}
            NOTE_BALANCES[$i]=${NOTE_BALANCES[$j]}
            NOTE_BALANCES[$j]=$temp
            # Swap names
            temp="${NOTE_NAMES[$i]}"
            NOTE_NAMES[$i]="${NOTE_NAMES[$j]}"
            NOTE_NAMES[$j]="$temp"
        fi
    done
done

# Sélection des notes jusqu'à atteindre le montant nécessaire
for ((i=0; i<NOTE_COUNT; i++)); do
    SELECTED_NOTES[$SELECTED_COUNT]="${NOTE_NAMES[$i]}"
    SELECTED_BALANCES[$SELECTED_COUNT]=${NOTE_BALANCES[$i]}
    CUMULATIVE_BALANCE=$((CUMULATIVE_BALANCE + NOTE_BALANCES[$i]))
    SELECTED_COUNT=$((SELECTED_COUNT + 1))
    
    print_debug "Ajout note #$SELECTED_COUNT: $(echo "scale=2; ${NOTE_BALANCES[$i]} / 65536" | bc) NOCK"
    
    if [ $CUMULATIVE_BALANCE -ge $TOTAL_NEEDED ]; then
        break
    fi
done

print_info "Notes sélectionnées: $SELECTED_COUNT/$NOTE_COUNT"
print_info "Balance cumulée: $(echo "scale=2; $CUMULATIVE_BALANCE / 65536" | bc) NOCK ($CUMULATIVE_BALANCE NICK)"

# Construction de la chaîne de notes pour la commande
NOTES_STRING=""
for ((i=0; i<SELECTED_COUNT; i++)); do
    if [ $i -eq 0 ]; then
        NOTES_STRING="[${SELECTED_NOTES[$i]}]"
    else
        NOTES_STRING="$NOTES_STRING [${SELECTED_NOTES[$i]}]"
    fi
done

# Calcul du change (monnaie rendue)
CHANGE=$((CUMULATIVE_BALANCE - TOTAL_NEEDED))
CHANGE_NOCK=$(echo "scale=2; $CHANGE / 65536" | bc)

# Confirmation
print_warn "=== CONFIRMATION ==="
echo "Destinataire: $RECIPIENT"
echo "Montant: $AMOUNT_NOCK NOCK ($AMOUNT_NICK NICK)"
echo "Frais: $(echo "scale=4; $FEE_NICK / 65536" | bc) NOCK ($FEE_NICK NICK)"
echo "Notes utilisées: $SELECTED_COUNT"
echo "Total débité: $(echo "scale=2; $CUMULATIVE_BALANCE / 65536" | bc) NOCK"
echo "Change retourné: $CHANGE_NOCK NOCK ($CHANGE NICK)"
echo ""
echo "Détail des notes:"
for ((i=0; i<SELECTED_COUNT; i++)); do
    echo "  - Note #$((i+1)): $(echo "scale=2; ${SELECTED_BALANCES[$i]} / 65536" | bc) NOCK"
done
echo ""
echo -n "Continuer? (y/N): "
read -r CONFIRM

if [[ ! "$CONFIRM" =~ ^[yY]$ ]]; then
    print_info "Transaction annulée"
    exit 0
fi

# Création de la transaction
print_info "Création de la transaction..."
print_debug "Commande: create-tx --names \"$NOTES_STRING\" --recipients \"[1 $RECIPIENT]\" --gifts \"$AMOUNT_NICK\" --fee \"$FEE_NICK\""

$WALLET_CLI create-tx $CLIENT_ARG \
    --names "$NOTES_STRING" \
    --recipients "[1 $RECIPIENT]" \
    --gifts "$AMOUNT_NICK" \
    --fee "$FEE_NICK"

if [ $? -ne 0 ]; then
    print_error "Échec de la création de la transaction"
    exit 1
fi

# Recherche du fichier .tx le plus récent
print_info "Recherche du fichier de transaction..."
if [ ! -d "$TXS_DIR" ]; then
    print_error "Dossier $TXS_DIR non trouvé"
    exit 1
fi

TX_FILE=$(ls -t "$TXS_DIR"/*.tx 2>/dev/null | head -n1)

if [ -z "$TX_FILE" ]; then
    print_error "Aucun fichier .tx trouvé dans $TXS_DIR"
    exit 1
fi

print_info "Transaction trouvée: $(basename $TX_FILE)"

# Signature de la transaction
print_info "Signature de la transaction..."
$WALLET_CLI sign-tx $CLIENT_ARG "$TX_FILE"

if [ $? -ne 0 ]; then
    print_error "Échec de la signature"
    exit 1
fi

# Envoi de la transaction
print_info "Envoi de la transaction..."
$WALLET_CLI send-tx $CLIENT_ARG "$TX_FILE"

if [ $? -ne 0 ]; then
    print_error "Échec de l'envoi"
    exit 1
fi

echo ""
print_info "${GREEN}✓ Transaction envoyée avec succès!${NC}"
print_warn "Note: La confirmation peut prendre du temps sur la blockchain"
echo ""
echo "Résumé:"
echo "  - Montant envoyé: $AMOUNT_NOCK NOCK"
echo "  - Frais: $(echo "scale=4; $FEE_NICK / 65536" | bc) NOCK"
echo "  - Notes utilisées: $SELECTED_COUNT"
echo "  - Change retourné: $CHANGE_NOCK NOCK"
echo "  - Fichier TX: $(basename $TX_FILE)"

# Nettoyage optionnel
echo ""
echo -n "Supprimer le fichier de transaction? (y/N): "
read -r CLEANUP

if [[ "$CLEANUP" =~ ^[yY]$ ]]; then
    rm "$TX_FILE"
    print_info "Fichier de transaction supprimé"
fi
