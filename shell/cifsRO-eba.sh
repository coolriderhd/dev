#!/bin/bash

#------------------------------------ Aphorisme -----------------------------------#
#
#	"Le trop de confiance attire le danger"
#	 Pierre Corneille / Le Cid
#
#----------------------------------------------------------------------------------#

aide_en_ligne ()
{
clear
cat <<EOF

===========================================================================

Auteur  : EBA
Date de création    : 29/06/2017

Infos   :

Ce script permet de passer les partages CIFS en Read Only, en cas d'incident
RansomWare par exemple.

Ou de les repasser en lecture écriture le moment venu.

Ce script ne peut être lancé que sur les contrôleur 3250 SATA qui sont ceux 
qui hébergent les NAS.

Il est entièrement interactif et peut être quitter à n'importe quel moment
en tapant CTRL-C ou en choisissant l'option abandon.

Le premier menu vous demande quelle action vous souhaitez entreprendre.
Vous pouvez alors choisir de passer les partages en lecture seule ou de
faire le retour arrière et repasser les partages en lecture écriture.

Le menu suivant vous donnera à choisir le contrôleur (BECK, Les Touches ou 
les deux).

Celui d'après vous donnera le choix d'agir sur les partages (un, plusieurs
ou tous).

Le script doit être lancé avec les droits root en sudo :

sudo $0

Il génère 3 logs dans le répertoire /root/logs :

Une log avec l'état complet des partages avant traitement.
Une autre avec les commandes qui ont été passées.
Et une dernière avec l'état des partages après traitement.

Le nom des logs est suffixé avec le PID du lancement du script.

Les logs pour le passage en lecture seule sont préfixées RO...
Les logs pour le retour arrière sont préfixées RW...

===========================================================================

EOF
}

while getopts :XHh opts
do
        case $opts in
                X|H|h ) aide_en_ligne
                        exit
                ;;

                * ) $0 
                ;;
        esac
done

function erecho () {

        echo "========================================================================"
        echo "/!\/!\/!\/!\ $@ /!\/!\/!\/!\ "
        echo "========================================================================"
}

function eecho ()
{
        #echo
        echo "________________________________________________________________________"
        echo
}

function execho ()
{
	echo
        echo $@
        echo "------------------------------------------------------------------------"
        echo

}

function Aband ()
{
	clear
	eecho
	echo -e "Abandon de la procédure. Bonne journée!"
	eecho
	exit
}

function DoIt ()
{
	case $2 in
		Read) LogTemoin=/root/logs/RO.before.$$
		      LogReslt=/root/logs/RO.after.$$
		      LogDid=/root/logs/RO.did.$$
		;;
		*) LogTemoin=/root/logs/RW.before.$$
		   LogReslt=/root/logs/RW.after.$$
		   LogDid=/root/logs/RW.did.$$
		;;
	esac
	
	#echo "$Connect vfiler run $1 cifs shares|egrep "/vol"|awk '{ print $1 }'"
	$Connect vfiler run $1 cifs shares >> $LogTemoin

	ListPart=$($Connect vfiler run $1 cifs shares|egrep "/vol"|awk '{ print $1 }')

	for part in $ListPart
	do
		echo "$Connect vfiler run $1 cifs access $part $2" >> $LogDid
		echo "$Connect vfiler run $1 cifs access $part $2"
	done

	$Connect vfiler run $1 cifs shares >> $LogReslt
}

function Ouille ()
{
	echo;echo "Oups !!! Mauvais choix recommencez... ou pas."
	echo 
	read -p "tapez \"ENTER\" pour recommencer ou \"CTRL-C\" pour quitter";
}
clear 

function Suite () 
{
	clear

	eecho
cat << EOF

	
	Veuillez faire un choix dans la liste ci-dessous

	1) Controleur1
	2) Controleur2
	3) Tous
	4) Abandon de la procédure
EOF
	eecho

	read -p "Votre choix puis \"ENTER\" : " choix1

	case $choix1 in 
		1) Menu1 Controleur1 $1
		;;
		2) Menu1 Controleur2 $1
		;;
		3) Glob Controleur1 Controleur2 $1
		;;
		4) Aband
		;;
		*) Ouille
	   	   Suite
		;;
	esac
}

function Glob () 
{
	eecho 
	echo '/!\/!\ Attention la procédure va se lancer deux fois; une fois pour chaque contrôleur. /!\/!\'
	eecho
	
	for i in $1 $2
	do
		echo
		read -p "Lancement de la procédure pour $i \"ENTER\" pour continuer (CTRL-C pour abandonner) " 
		execho Lancement de la procédure pour $i
		Menu1 $i $3
	done

}

function Menu1 () 
{
	case $2 in
		RO) Action="Read"
		;;
		RW) Action="Full Control"
		;;
	esac

		OS=$(uname)
	if [[ $OS = Linux ]]
	then
		egrep='/bin/egrep'
		uniq='/bin/uniq'
		Connect="/bin/ssh root@$1"
	else
		egrep='/bin/grep.exe --colour -E'
		uniq='/bin/busybox.exe uniq'
		Connect="ssh -oKexAlgorithms=+diffie-hellman-group1-sha1 root@$1"
	fi

	clear

	eecho
	
	echo "Veuillez patienter pendant la génération de la liste des vfiler"
	echo

	VFL=$($Connect vfiler status |egrep -v vfiler0|awk '{print $1}')
	
	i=1

	Menu2 () 
	{
		until [[ $# -eq 0 ]]
		do
			echo "$i) $1" 
			cx[$i]="$1"
			((i=$i+1))
			shift
		done

		echo "$i) Tous"
	}

	Menu2 $VFL

	echo
	read -p "vous pouvez faire plusieurs choix séparés par des espaces ou taper \"CTRL-C\" pour quitter : " chx
	echo

	eecho

	echo $chx |grep "$i"
	Ret=$?
	
	
	for nb in $chx
	do
		if [[ $nb -gt $i ]] || [[ "$(echo $nb | egrep -v "^[ [:digit:] ]*$")" ]]
		then
			erecho "Oups!!! choix invalide : $nb "
			erecho "Abandon de la procédure"
			exit
		fi

		if [[ $Ret -eq 0 ]] 
		then
			echo '	 /!\/!\/!\ Attention Attention /!\/!\/!\'
			echo "Vous allez agir sur tous les partages du vfiler"
			echo
	
			read -p "Tapez \"CTRL-C\" ou \"ENTER\" pour abandonner ou \"o\" Pour continuer " ben

			if [[ ${ben:-n} != "o" ]] || [[ ${ben:-n} = "n" ]]
			then
				read -p "Je n'ai pas compris votre réponse. Veuillez recommencer : " ben
				continuer
			else
				exit
			fi
		
			for vfl in ${cx[@]}
			do
				execho "Lancement de la procédure pour $vfl"
				DoIt $vfl \""$Action\""
			done

			exit
		else
			execho "Lancement de la procédure pour ${cx[$nb]}"
			DoIt ${cx[$nb]} \""$Action\""
		fi

		eecho
	done
}

#Suite
#exit

######################
eecho
cat << EOF

	/!\/!\ ATTENTION Vous êtes sur le point de modifier les partages CIFS /!\/!\\
	
	L'écran suivant vous permettra de choisir le contrôleur sur lequel vous souhaitez agir.
	L'écran d'après de choisir les NAS à modifier (un, plusieurs ou tous).

	NB : Vous pouvez abandonner la procédure à tout moment en tapant "CTRL-C"

	1) Passage en lecture seule des partages CIFS
	2) Retour arrière (passage en lecture écriture)
	3) Abandon de la procédure.
EOF
eecho

read -p "Votre choix puis \"ENTER\" : " resp1
echo

case $resp1 in 
	
	1) Suite RO
	;;
	2) Suite RW
	;;
	3) Aband
	;;
	*) Ouille
	   $0
	;;
esac

