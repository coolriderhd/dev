#!/bin/bash
#-------------------------------------------------------------------------------#
#               Aphorisme directeur (petite manie contractée avec JLT)
#-------------------------------------------------------------------------------#
#
#	Je déteste faire le ménage. Vous faites le lit, la vaisselle 
#	et six mois après, tout est à recommencer.
#
#	Joan Rivers 
#
#-------------------------------------------------------------------------------#
#                      DEFINITION DES VARIABLES GLOBALES
#-------------------------------------------------------------------------------#

#------ gestion des dates
MyDATE=`date +%Y%m%d`

#----- gestion des répertoires

RepLOGS="/GIEIS/Logs"
RepSARG="/var/www/sarg"

#----- gestion des fichiers en sortie

MOI=`basename $0 |awk -F. '{print$1}'`
InitLOG=/GIEIS/Logs/${MOI}.log
LOG=$RepLOGS/${MOI}.log.$MyDATE
TMP=/tmp/${MOI%%.*}.txt

#----- initialisation des variables globales


#-------------------------------------------------------------------------------#
#                           DEFINITION DES FONCTIONS
#-------------------------------------------------------------------------------#

aide_en_ligne ()
{
cat <<EOF

===========================================================================

Auteur  : E.BARREIRA
Date    : 25.09.2012

Infos   :

Ce script fait le ménage dans les rapports SARG.
Ces rapports se trouvent dans les sous répertoires de $RepSARG

Ils sont archivés compressés au bout de 15 jours dans les sous répertoires correspondants de $RepSARG/Archives

Ils sont ensuite supprimés au bout de :
	
	- 30 jours pour les daily
	- 60 jours pour les weekly
	- 90 jours pour les monthly

Il ne prend aucun paramètre.

Les logs sont visible ici : 

$InitLOG pour la log du jour

$LOG pour les logs sauvegardées 

(remplacer la date de fin par celle voulue ou se rendre dans le répertoire)

===========================================================================

EOF
}

FatalERROR ()
{
MSGERROR "ATTENTION UNE ERREUR FATALE EST SURVENUE. VERIFIEZ LES LOGS"
echo -e "\n  #-------------------------- ATTENTION -----------------------------#\n" >> $LOG
echo -e "  Une erreur fatale est survenue dans l'execution du script a l'étape $ETAPE\n" >> $LOG
echo -e "  $2\n" >> $LOG
echo -e "  #-------------------------- ATTENTION -----------------------------#\n" >> $LOG
cat $InitLOG >> $LOG
exit
}

MSG ()
{
#----- message en cyan
if [ x$TERM != "xxterm" ]
then
	echo -e "\n$1" >> $InitLOG
else
	echo -e "\t\t\033[46;36m $1 \033[0m"
	echo -e "\t\t\033[46;30m $1 \033[0m"
	echo -e "\t\t\033[46;36m $1 \033[0m"
fi
}

MSG2 ()
{
#----- message en jaune
if [ x$TERM != "xxterm" ]
then
	echo -e "\n$1" >> $InitLOG
else
	echo -e "\t\t\033[43;33m $1 \033[0m"
	echo -e "\t\t\033[43;30m $1 \033[0m"
	echo -e "\t\t\033[43;33m $1 \033[0m"
fi
}

MSGERROR ()
{
#----- message en rouge
if [ x$TERM != "xxterm" ]
then
	echo -e "\nATTENTION ERREUR : $1" >> $InitLOG
else
	echo -e "\t\t\033[41;31m $1 \033[0m"
	echo -e "\t\t\033[41;30m $1 \033[0m"
	echo -e "\t\t\033[41;31m $1 \033[0m"
fi
}

ROTATE ()
{

#--- durée de conservation en jours des rapports.
#--- NB : ils sont conservés zippé au delà de 15 jours. 

MSG "Archivage des rapports de $1"

ZipPERIOD="15"

case $1 in

	daily)
		((Period=30-$ZipPERIOD))
		MSG "la rétention retenue est de 30 jours pour $1"
	;;
	
	weekly)
		((Period=60-$ZipPERIOD))
		MSG "la rétention retenue est de 60 jours pour $1"
	;;

	monthly)
		((Period=90-$ZipPERIOD))
		MSG "la rétention retenue est de 90 jours pour $1"
	;;

	ONE-SHOT)
		((Period=60-$ZipPERIOD))
		MSG "la rétention retenue est de 60 jours pour $1"
	;;
esac

MSG "déplacement dans le répertoire $RepSARG/$1"
cd $RepSARG/$1
[ $? -ne 0 ] && FatalERROR "impossible de se déplacer dans le réperoire $RepSARG/$1"

for Rap in `find . -name "20*" -ctime +$ZipPERIOD -exec basename {} \;`
do
	MSG2 "archivage du rapport $RepSARG/$1/$Rap"
	echo "tar -zcvf $RepSARG/Archives/$1/$Rap.taz $Rap"
	[ $? -ne 0 ] && MSGERROR "Erreur lors de la création de l'archive $RepSARG/Archives/$1/$Rap.taz"

	MSG2 "Suppression du rapport $RepSARG/$1/$Rap après archivage"
	echo "rm -rf $Rap"
	[ $? -ne 0 ] && MSGERROR "Erreur lors de la suppression du rapport $RepSARG/$1/$Rap.taz"
done

MSG "Suppression des rapports archivés"
find $RepSARG/Archives/$1 -ctime +$Period -delete
[ $? -ne 0 ] &&  MSGERROR "Erreur lors de la suppression des rapports archivés"

}

#-------------------------------------------------------------------------------#
#                               CORPS DE SCRIPT
#-------------------------------------------------------------------------------#

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


#----- initialisation des fichiers de log
echo -e "\n" > $InitLOG
echo -e "\n" > $LOG

ETAPE=1

for REP in daily monthly weekly ONE-SHOT
do
	ROTATE $REP
done

ETAPE=2
MSG2 "Nettoyage des logs et répertoires sauvegardés"
find $RepLOGS -name "${MOI}.*" -mtime +7 -delete >> $InitLOG 2>&1
[ $? -ne 0 ] && MSGERROR "problème lors de la suppression des anciennes logs"

MSG "Sauvegarde de log"
cat $InitLOG > $LOG

[ $? -ne 0 ] && FatalERROR "Problème lors de la sauvegarde de la log"

