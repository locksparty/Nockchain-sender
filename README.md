# Nockchain-sender
Send from nockchain CLI with easy
Utilisation :
# Rendre les scripts exécutables
chmod +x nockchain_send.sh check_balance.sh

# Vérifier le solde (node public)
./check_balance.sh

# Vérifier le solde (node privé)
./check_balance.sh --private

# Envoyer avec cumul automatique de notes (node public)
./nockchain_send.sh <adresse> 100

# Envoyer avec cumul automatique de notes (node privé)
./nockchain_send.sh <adresse> 100 --private

Nouvelles fonctionnalités :
✅ Cumul automatique de plusieurs notes pour gros montants
✅ Tri des notes par balance (utilise d'abord les plus grosses)
✅ Calcul précis du change retourné
✅ Support --client private pour node personnel
✅ Affichage détaillé des notes utilisées
✅ Script bonus pour vérifier rapidement le solde
✅ Mode debug pour le troubleshooting  
Le script sélectionne intelligemment les notes nécessaires et les cumule pour atteindre le montant voulu!
