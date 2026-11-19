Debian - Unlock LUKS2 on startup
================================

Procédure : déverrouillage automatique LUKS2 avec TPM 2.0 sous Debian 13
Cette procédure reprend la configuration qui fonctionne sur ton Dell Latitude E7470 : Debian 13, LUKS2, TPM 2.0, Dracut et Secure Boot.

Le principe : le TPM conserve une clé permettant de déverrouiller le volume LUKS automatiquement au démarrage. La passphrase reste disponible en secours.

## 1. Vérifier les prérequis

Vérifier que le TPM 2.0 est présent et accessible.
```bash
ls -l /dev/tpm0 /dev/tpmrm0
```

Vérifier que Secure Boot est activé :
```bash
mokutil --sb-state
```

Résultat attendu :
```text
SecureBoot enabled
```

Installer les outils nécessaires :
```bash
sudo apt update
sudo apt install tpm2-tools cryptsetup-initramfs dracut
```

Attention : sur Debian 13, l'installation de Dracut peut supprimer initramfs-tools. C'est normal dans cette configuration. Ne pas lancer apt autoremove sans vérifier les paquets concernés.

Vérifier que Dracut est disponible :
```bash
dracut --version
```

## 2. Sauvegarder l'en-tête LUKS

Cette sauvegarde permet de récupérer le volume en cas de problème avec ses métadonnées.
```bash
sudo cryptsetup luksHeaderBackup /dev/sda3 \
  --header-backup-file /media/erqsor/USB_4GB/luks-header.img
```

Vérifier que le fichier a bien été créé sur le support externe :
```bash
ls -lh /media/erqsor/USB_4GB/luks-header.img
```

Conserver cette sauvegarde en lieu sûr, séparément de l'ordinateur.

## 3. Configurer crypttab

Éditer le fichier :
```bash
sudo nano /etc/crypttab
```

Remplacer les options de la ligne correspondant au volume chiffré par :
```text
sda3_crypt UUID=ad073bec-54be-4b9b-b8af-d1a184431c70 none luks,discard,x-initrd.attach,tpm2-device=auto,headless=0,tries=3
```

À adapter à chaque machine :
- sda3_crypt : nom du volume déverrouillé.
- UUID : UUID du volume LUKS, récupérable avec sudo blkid.
- tpm2-device=auto : détecte automatiquement le TPM.
- headless=0 : permet notamment de conserver une possibilité de saisie de la passphrase.
- tries=3 : nombre de tentatives.
Important : cette option tpm2-device=auto nécessite Dracut. L'ancien initramfs-tools ne la prend pas en charge.

## 4. Configurer GRUB

Éditer la configuration :
```bash
sudo nano /etc/default/grub
```

Ajouter ou modifier cette ligne :
```text
GRUB_CMDLINE_LINUX="rd.luks=1 rd.auto"
```

Ces paramètres indiquent à Dracut de rechercher et d'activer les volumes LUKS automatiquement.

## 5. Enregistrer une clé dans le TPM

Cette commande associe une clé de déverrouillage LUKS au TPM.
```bash
sudo systemd-cryptenroll \
  --tpm2-device=auto \
  --tpm2-pcrs=0+7 \
  /dev/sda3
```

Saisir la passphrase LUKS actuelle lorsqu'elle est demandée.

Vérifier que l'enregistrement a réussi :
```bash
sudo systemd-cryptenroll /dev/sda3
```

Résultat attendu :
```text
SLOT TYPE
   0 password
   1 tpm2
```

Le slot password doit rester présent : il constitue le moyen de secours.

Les PCR 0 et 7 lient le déverrouillage à certains éléments de l'état du firmware et de Secure Boot.

Important : Secure Boot doit être activé avant cet enrôlement. Si son état change ultérieurement, il faudra réexaminer l'enrôlement TPM.

## 6. Reconstruire l'initramfs avec Dracut

Cette commande reconstruit l'image de démarrage du noyau actuellement utilisé.
```bash
sudo dracut --force --hostonly --kver "$(uname -r)"
```

Vérifier que les informations de crypttab ont bien été intégrées :
```bash
sudo lsinitrd -f etc/crypttab /boot/initrd.img-$(uname -r)
```

Résultat attendu : une ligne contenant notamment :
```text
tpm2-device=auto,headless=0,tries=3
```

Vérifier également que les composants TPM sont présents :
```bash
sudo lsinitrd /boot/initrd.img-$(uname -r) | grep -E 'tpm2|cryptsetup'
```

## 7. Mettre à jour GRUB

Cette commande régénère la configuration de démarrage avec les nouveaux paramètres.
sudo update-grub

Vérifier que les paramètres sont présents dans la configuration générée :
```bash
sudo grep -m 2 'rd.luks=1 rd.auto' /boot/grub/grub.cfg
```

Résultat attendu : les entrées de démarrage contiennent :
```text
rd.luks=1 rd.auto
```

## 8. Redémarrer et tester

```bash
sudo reboot
```

Le volume doit maintenant se déverrouiller automatiquement sans demander la passphrase LUKS.

Vérifier ensuite les slots :
```bash
sudo systemd-cryptenroll /dev/sda3
```

Le slot TPM2 doit toujours être présent.

## 9. Clean

Le clean des paquets risque de modifier la configuration et réactiver la demande de passphrase LUKS2 au démarrage de l'ordinateur.  
Donc après avoir supprimé les paquets inutilisés ou toute mise à jour du noyau, il faudra probablement reconstruire l'initramfs avec Dracut :

```bash
sudo apt autoremove
sudo dracut --force --hostonly --kver "$(uname -r)"
```

Vérifier que la configuration crypttab est bien intégrée :
```bash
sudo lsinitrd -f etc/crypttab /boot/initrd.img-$(uname -r)
```

Le résultat doit contenir les options suivantes :
```text
tpm2-device=auto,headless=0,tries=3
```

## 10. Procédure de secours

Si le TPM ne parvient plus à déverrouiller le disque, il reste possible de démarrer avec la passphrase.

Au menu GRUB :
1. Sélectionner l'entrée Debian.
2. Appuyer sur e pour modifier temporairement les paramètres.
3. Ajouter à la ligne de commande du noyau : `rd.luks.options=tpm2-device=no`
4. Démarrer avec Ctrl + X ou F10.
5. Saisir la passphrase LUKS lorsqu'elle est demandée.
Cette modification est temporaire et ne change pas la configuration enregistrée.
10. Sécuriser le BIOS/UEFI
Sur le Dell Latitude E7470, définir un mot de passe administrateur BIOS/UEFI.

Cela évite qu'une personne puisse simplement désactiver Secure Boot pour contourner les protections associées au TPM.

À retenir : les trois points les plus importants sont de conserver une sauvegarde de l'en-tête LUKS, de ne jamais supprimer le slot password et de vérifier que Dracut intègre bien /etc/crypttab dans l'initramfs.

Cette procédure reproduit la configuration qui vient de fonctionner sur ta machine. Elle est inspirée de [l'article de référence sur Debian, LUKS, TPM2 et Secure Boot](https://www.zem.org.uk/post/2026/debian-luks-tpm2-secureboot/).
