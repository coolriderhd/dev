#!/bin/bash
#-------------------------------------------------------------------------------#
#               Aphorisme directeur (petite manie contractée avec JLT)
#-------------------------------------------------------------------------------#
#
#       Vous faites le ménage de l'univers avec les ustensiles du raisonnement.
#       Bon. Vous arrivez à une saleté bien rangée.”
#
#       Léon-Paul Fargue
#
#-------------------------------------------------------------------------------#
#                           DEFINITION DES FONCTIONS
#-------------------------------------------------------------------------------#

aide_en_ligne ()
{
cat <<EOF

===========================================================================

Auteur  : E.BARREIRA
Date    : 13/05/2020

Infos   :

Ce script lancé par cron fait la copie à intervalle régulier des fichiers de
sauvegarde SAP/HANA

Pour la partie SYS les fichiers sont copié;
de $SourceSYS vers $DestSYS

Pour la partie DB les fichiers sont copiés;
de $SourceDBHQ4 vers $DestDBHQ4

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

#-------------------------------------------------------------------------------#
#                      DEFINITION DES VARIABLES GLOBALES
#-------------------------------------------------------------------------------#

#------ gestion des dates
MyDATE=`date +%Y%m%d`

#----- gestion des répertoires
SourceDBHQ4="/hana/shared/HP4/HDB00/backup/log/DB_HP4"
DestDBHQ4="/backup_nfs/PROD/LOG_PS4/DB_HP4"
SourceSYS="/hana/shared/HP4/HDB00/backup/log/SYSTEMDB"
DestSYS="/backup_nfs/PROD/LOG_PS4/SYSTEMDB"
RepLOGS="/usr/sap/HP4/HDB00/ebalogs"

#----- gestion des fichiers en sortie
MOI=`basename $0 |awk -F. '{print$1}'`
InitLOG="$RepLOGS/${MOI}.log"
LOG="$RepLOGS/${MOI}.log.$MyDATE"

#----- Variables Divers
NFS="backup_nfs"

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

DATE=$(date +%D-%Hh%M)
MSG $DATE
echo -e "\n" >> $InitLOG

ETAPE=1
MSG "Vérification de la présence des montages NFS"

DF=$(df |egrep -w $NFS|wc -l)

[[ $DF -ne 1 ]] && FatalERROR "Erreur à l'étape $ETAPE :: Le Montage NFS backup_nfs n'est pas présent"

MSG "Le montage est présent on continue"

((ETAPE=$ETAPE+1))
MSG "Début de l'étape $ETAPE :: Synchro de $SourceSYS vers $DestSYS"
echo -e "\n" >> $InitLOG

/usr/bin/rsync -Ppavh --chmod=D777,F644 --delete-after $SourceSYS/ $DestSYS >> $InitLOG 2>&1

RET=$?
echo -e "\n" >> $InitLOG

[[ $RET -ne 0 ]] && FatalERROR "Erreur à l'étape $ETAPE :: Il y a un souci de synchronisation. Code retour :: $RET"

((ETAPE=$ETAPE+1))
MSG "Verification de la cohérence du dernier fichier"

FICsysdest=$(ls -lrt $DestSYS |tail -1|awk '{print $NF}')

MSG "Entre $SourceSYS/$FICsysdest et $DestSYS/$FICsysdest"

FICsysorigSUM=$(md5sum $SourceSYS/$FICsysdest|awk '{print $1}')
FICsysdestSUM=$(md5sum $DestSYS/$FICsysdest|awk '{print $1}')

if [[ $FICsysorigSUM = $FICsysdestSUM ]]
then
        MSG "La vérification checksum est cohérente"
else
        MSGERROR "La vérification checksum n'est pas cohérente, suppression du dernier fichier"
	MSG2 "La comparaison entre $SourceSYS/$FICsysdest et $DestSYS/FICsysdest indique une erreur"
	MSG2 "checksum $SourceSYS/$FICsysdest = $FICsysorigSUM"
	MSG2 "checksum $DestSYS/$FICsysdest = $FICsysdestSUM"

        rm $DestSYS/$FICsysdest
fi

((ETAPE=$ETAPE+1))
MSG "Debut de l'étape $ETAPE synchro de $SourceDBHQ4 vers $DestDBHQ4"
echo -e "\n" >> $InitLOG

/usr/bin/rsync -Ppavh --chmod=D777,F644 --delete-after $SourceDBHQ4/ $DestDBHQ4 >> $InitLOG 2>&1

RET=$?
echo -e "\n" >> $InitLOG

[[ $RET -ne 0 ]] && FatalERROR "Erreur à l'étape $ETAPE :: Il y a un souci de synchronisation. Code retour :: $RET"

((ETAPE=$ETAPE+1))
MSG "Verification de la cohérence du dernier fichier $SourceDBHQ4 et $DestDBHQ4"

FICdest=$(ls -lrt $DestDBHQ4|tail -1|awk '{print $NF}')

MSG "Entre $SourceDBHQ4/$FICdest et $DestDBHQ4/$FICdest"

FICorigSUM=$(md5sum $SourceDBHQ4/$FICdest|awk '{print $1}')
FICdestSUM=$(md5sum $DestDBHQ4/$FICdest|awk '{print $1}')

if [[ $FICorigSUM = $FICdestSUM ]]
then
        MSG "La vérification checksum est cohérente"
else
        MSGERROR "La vérification checksum n'est pas cohérente, suppression du dernier fichier"
	MSG2 "La comparaison entre $SourceDBHQ4/$FICdest et $DestDBHQ4/$FICdest indique une erreur"
        MSG2 "checksum $SourceDBHQ4/$FICdest = $FICorigSUM"
        MSG2 "checksum $DestDBHQ4/$FICdest = $FICdestSUM"
	

        rm $DestDBHQ4/$FICdest
fi

((ETAPE=$ETAPE+1))
MSG "Suppression des fichiers de log et des mails d'execution crontab"

find $RepLOGS -name "${MOI}.*" -mtime +7 -delete >> $InitLOG 2>&1
cat /dev/null > /var/spool/mail/hp4adm

MSG2 "Fin d'execution du script"
echo -e "\n" >> $InitLOG


