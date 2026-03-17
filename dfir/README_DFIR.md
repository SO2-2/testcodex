# Script d'extraction DFIR (Windows)

Ce livrable fournit un script PowerShell d'acquisition DFIR orienté **post-compromission** et **audit forensic**.

## Fichiers livrés

- `dfir/Invoke-DFIRCollection.ps1` : script principal.
- `dfir/tools/` : dossier pour déposer les outils Sysinternals/DFIR (non inclus).
- `dfir/sample_output_tree.txt` : exemple d'arborescence de sortie.

## Prérequis

- Windows 10/11/Server
- PowerShell 5.1+
- Exécution en administrateur recommandée
- Outils optionnels à placer dans `dfir/tools/` :
  - `Autoruns64.exe`
  - `sigcheck.exe`
  - `procdump64.exe`

## Usage CLI

```powershell
# Mode standard (recommandé)
powershell -ExecutionPolicy Bypass -File .\dfir\Invoke-DFIRCollection.ps1 -OutputPath D:\Collecte

# Mode rapide
powershell -ExecutionPolicy Bypass -File .\dfir\Invoke-DFIRCollection.ps1 -Quick -OutputPath D:\Collecte

# Mode complet + dump mémoire (si outil disponible)
powershell -ExecutionPolicy Bypass -File .\dfir\Invoke-DFIRCollection.ps1 -Full -MemoryDump -OutputPath D:\Collecte
```

## Paramètres

- `-Full` : collecte étendue (inclut timeline).
- `-Quick` : limite certaines étapes coûteuses (timeline ignorée).
- `-OutputPath` : chemin racine des résultats.
- `-MemoryDump` : active la collecte mémoire (modules + dump LSASS via procdump si présent).
- `-VerboseMode` : affiche les logs en temps réel en console.
- `-ToolsPath` : chemin des outils externes.

## Artefacts collectés

- **Système** : OS, BIOS, variables d'environnement, uptime.
- **Processus** : liste complète, arbre parent/enfant, lignes de commande.
- **Réseau** : netstat, interfaces, ARP, DNS cache, routes.
- **Persistance** : tâches planifiées, services, clés Run/RunOnce, WMI subscriptions, Autoruns (si disponible).
- **Utilisateurs** : comptes, groupes, sessions et contexte de sécurité.
- **Logs** : export EVTX + événements récents (Security/System/Application/PowerShell).
- **Système de fichiers** : Recent, Temp, Prefetch, LNK, Recycle Bin.
- **Sécurité** : statut Defender, règles firewall, produits AV.
- **Timeline** : CSV de métadonnées fichiers.
- **Intégrité** : SHA256 de la collecte + hash du script.

## Chaîne de preuve & intégrité

- Journalisation horodatée UTC dans `execution.log`.
- Trace des commandes exécutées dans `commands.log`.
- Manifest SHA256 global : `integrity/sha256_manifest.csv`.
- Hash SHA256 du script : `integrity/script_hash.txt`.

## Remarques DFIR

- Le script privilégie la lecture seule mais certaines commandes système peuvent laisser des traces d'exécution natives (inhérent à Windows).
- Toujours exécuter depuis un support maîtrisé (clé IR) et exporter les résultats vers un emplacement sécurisé.
