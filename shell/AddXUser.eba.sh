#!/bin/bash

#----- Aphorisme directeur -----#
echo
echo "Le moyen d'être sauf, c'est de ne pas se croire en sécurité."
echo "Thomas Fuller"

List=$1

aide_en_ligne ()
{
cat <<EOF

===========================================================================

Auteur  : E.BARREIRA
Date    : 27/03/2015

Infos   :

Ce script permet de créer les utilisateurs et de positionner les paramètres
Par défaut pour le bureau des utilisateurs.

A noter que certains droits doivent être modifier pour que ça fonctionne.
Il y a également des paramètres à modifier dans certains fichiers.

lors de la création des utilisateurs, un mot de passe aléatoire est créé
pour chacun d'eux et placé dans un fichier afin de le transmettre aux
intéressés.

NB : le script prend en entrée un fichier contenant la liste des
utilisateurs à traiter.

===========================================================================

EOF
}

if [[ $1 = "" ]]
then
        aide_en_ligne
        exit
fi

while getopts :XHh opts
do
        case $opts in
                X|H|h ) aide_en_ligne
                        exit
                ;;

                * ) $0 $1
                ;;
        esac
done

> pass.list
chmod 600 pass.list

for i in `cat $List`
do
        echo "création $i"
        useradd -g scc -d /home/$i $i

        echo "mise en place mot de passe provisoire"
        #PASS=` </dev/urandom tr -dc '12345!@#$%qwertQWERTasdfgASDFGzxcvbZXCVB' | head -c10; echo ""`
        echo $PASS |passwd --stdin $i

        echo "sauvegarde du mot de passe dans un fichier afin de le transmettre à l'utilisateur"
        echo "ne pas oublier de supprimer le fichier une fois les mots de passe transmis"
        echo "$i == $PASS" >> pass.list

        echo "copie de .config et correction des droits"
        cp -r /home/template/.config /home/$i
        chown -R $i:scc /home/$i/.config

        echo "copie de .Xclients et correction des droits"
        cp /home/template/.Xclients /home/$i
        chmod +x /home/$i/.Xclients

        echo "modif $i"

        echo ":%s/template/$i/" > $i.txt
        echo ":x!" >> $i.txt

        vi -s $i.txt /home/$i/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-panel.xml
        vi -s $i.txt /home/$i/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-desktop.xml

        grep $i /home/$i/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-panel.xml
        grep $i /home/$i/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-desktop.xml

        rm $i.txt

        echo
        echo "###############################"
done

