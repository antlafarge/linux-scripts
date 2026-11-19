Monter les partages SMB d'un Synology dans /nas/
Configuration validée
1. Installer les paquets nécessaires
sudo apt update
sudo apt install cifs-utils smbclient


- cifs-utils : permet de monter les partages SMB.
- smbclient : permet de tester les connexions SMB.
2. Créer les points de montage
On utilise trois partages Synology :
Partage Synology	Montage Debian
Shared	/nas/shared
home	/nas/home
docker	/nas/docker

Créer les dossiers :
sudo mkdir -p /nas/shared
sudo mkdir -p /nas/home
sudo mkdir -p /nas/docker


3. Créer le fichier d'identifiants
Créer le fichier :
sudo nano /etc/samba/credentials-nas


Contenu :
username=erqsor
password=TON_MOT_DE_PASSE


Attention aux points suivants :
- Aucun espace avant ou après les valeurs.
- Aucun guillemet.
- Une ligne par paramètre.
- Utiliser des fins de ligne Unix (LF), pas Windows (CRLF).
- Ne pas laisser d'espaces superflus.
Protéger le fichier :
sudo chmod 600 /etc/samba/credentials-nas


4. Configurer /etc/fstab
Ouvrir :
sudo nano /etc/fstab


Ajouter à la fin :
# NAS Synology
//192.168.1.4/Shared    /nas/shared    cifs    credentials=/etc/samba/credentials-nas,uid=1000,gid=10,vers=3.0,iocharset=utf8,_netdev,nofail    0    0
//192.168.1.4/home      /nas/home      cifs    credentials=/etc/samba/credentials-nas,uid=1000,gid=10,vers=3.0,iocharset=utf8,_netdev,nofail    0    0
//192.168.1.4/docker    /nas/docker    cifs    credentials=/etc/samba/credentials-nas,uid=1000,gid=10,vers=3.0,iocharset=utf8,_netdev,nofail    0    0


Explication des options :
Option	Fonction
credentials	Fichier contenant les identifiants SMB
uid=1000	Propriétaire local : utilisateur UID 1000
gid=10	Groupe local GID 10 (uucp sur ta machine)
vers=3.0	Protocole SMB 3.0
iocharset=utf8	Encodage UTF-8
_netdev	Indique que le montage nécessite le réseau
nofail	Ne bloque pas le démarrage si le NAS est indisponible
0 0	Pas de dump ni de vérification fsck

5. Vérifier la configuration
Vérifier la syntaxe de fstab :
sudo findmnt --verify


Recharger la configuration systemd :
sudo systemctl daemon-reload


6. Monter les partages
Exécuter :
sudo mount -a


Pour afficher les montages :
findmnt -t cifs


Pour vérifier le contenu :
ls -la /nas/shared
ls -la /nas/home
ls -la /nas/docker


7. Démonter et remonter les partages
Démonter individuellement :
sudo umount /nas/shared
sudo umount /nas/home
sudo umount /nas/docker


Tout remonter :
sudo mount -a



8. Dépannage
En cas de mount error(13): Permission denied :

Étape 1 : tester les identifiants et les permissions SMB
smbclient //192.168.1.4/Shared -U erqsor -c 'ls'


Étape 2 : vérifier le fichier d'identifiants
sudo sed -n 'l' /etc/samba/credentials-nas


Cette commande affiche les caractères invisibles, notamment :
- $ en fin de ligne : fin de ligne normale.
- \r$ : fin de ligne Windows.
- Des espaces avant $ : espaces superflus.
Étape 3 : recréer proprement le fichier si nécessaire.
sudo nano /etc/samba/credentials-nas
sudo chmod 600 /etc/samba/credentials-nas


Étape 4 : consulter les logs
sudo dmesg | tail -40



Les commandes à retenir pour le quotidien

MONTER TOUS LES PARTAGES
sudo mount -a



VOIR LES PARTAGES MONTÉS
findmnt -t cifs



TOUT DÉMONTER
sudo umount /nas/shared /nas/home /nas/docker



VÉRIFIER LES ERREURS
sudo dmesg | tail -40



À retenir : le problème rencontré venait du fichier credentials-nas, et non des permissions Linux (chmod) des dossiers de montage. Recréer proprement ce fichier a permis de résoudre le problème.
