#!/bin/bash


print_vars(){
	echo NAME_PREFIX = ${NAME_PREFIX}
	echo "FULL_INTERVAL = ${FULL_INTERVAL}"
	echo "INC_INTERVAL = ${INC_INTERVAL}"
	echo FILES_DIR = ${FILES_DIR}
	echo GZIP = ${GZIP}
	echo EXT = ${EXT}
	echo BACKUP_DIR = ${BACKUP_DIR}
	echo HELP = ${HELP}
	echo VERSION = ${VERSION}
}

print_help(){
	if [ "$1" -gt 1 ]; then
		echo "Użycie opcji -h lub --help z innymi opcjami jest niedozwolone"
		exit 1
	fi
	echo " ---- HELP: napisz man linuxbackup -----"
	exit 0
}

print_version(){
	if [ "$1" -gt 1 ]; then
		echo "Użycie opcji -v lub --version z innymi opcjami jest niedozwolone"
		exit 1
	fi
	echo " ---- VERSION: program 0.01 -----"
	exit 0132dh

}

###################################################################

#
# init
#
HELP=false
VERSION=false
GZIP=false
REMOVE=false
NAME_PREFIX=""
FULL_INTERVAL=""
INC_INTERVAL=""
FILES_DIR=""
EXT=""
BACKUP_DIR=""

###################################
# czytaj ustawienia

source $(dirname $0)/backup.config

echo "ZENITY=${ZENITY}"

ZENITY_OUT=""

if [ "${ZENITY}" == "ON" ]; then
	ZENITY_OUT=$( zenity --forms --height 250 --width 600 \
                            --title="Parametry Backupu do dodania" \
                            --text="Podaj prefix backupu oraz parametry czasowe:" \
                            --separator="|" \
                            --add-entry="Prefix nazwy:" \
                            --add-entry="Odstepy pełnego backupu (jak w cron):" \
                            --add-entry="Odstepy przyrostowego backupu (j.w.):" \
                            --add-entry="Rozszerzenia plików (lista rozdzielona ,):" \
                            --add-list "Czy kompresować?" --list-values "TAK|NIE")
	ACCEPTED=$?
        if [ ! "${ACCEPTED}" == "0" ]; then
		echo "Zenity: Brak akceptacji"
		exit 1
	fi
	NAME_PREFIX=$(awk --field-separator='|' '{print $1}' <<<${ZENITY_OUT})
	FULL_INTERVAL=$(awk --field-separator='|' '{print $2}' <<<${ZENITY_OUT})
	INC_INTERVAL=$(awk --field-separator='|' '{print $3}' <<<${ZENITY_OUT})
        EXT=$(awk --field-separator='|' '{print $4}' <<<${ZENITY_OUT})
	GZIP=$(awk --field-separator='|' '{print $5}' <<<${ZENITY_OUT})
	if [ "${GZIP}" == "TAK" ]; then
		GZIP=true
	else
		GZIP=false
	fi
        FILES_DIR=$(zenity --file-selection --title="Ścieżka do backupowanych plików:" --directory )
	ACCEPTED=$?
        if [ ! "${ACCEPTED}" == "0" ]; then
		echo "Zenity: Brak akceptacji ścieżki do backupowanych plików"
		exit 1
	fi                         
	BACKUP_DIR=$(zenity --file-selection --title="Ścieżka do plików z backupem:" --directory )                            
	ACCEPTED=$?
        if [ ! "${ACCEPTED}" == "0" ]; then
		echo "Zenity: Brak akceptacji ścieżki do backupów"
		exit 1
	fi                         
	REMOVE=$(zenity --forms --title="Usuwanie ?" --add-list="Czy usunąć z crona?" --list-values "TAK|NIE" )
	if [ "${REMOVE}" == "TAK" ]; then
		REMOVE=true
	else
		REMOVE=false
	fi
	QUESTION=$(zenity --question --height 250 --width 600 --title="Podsumowanie" --text="Ustawiono:\n name=${NAME_PREFIX}\nfull-interval=${FULL_INTERVAL}\ninc-interval=${INC_INTERVAL}\npath=${FILES_DIR}\nbackup-dir=${BACKUP_DIR}\ngzip=${GZIP}\nremove=${REMOVE}\n\nCzy akceptujesz ustawienia? ")
	ACCEPTED=$?
        if [ ! "${ACCEPTED}" == "0" ]; then
		echo "Zenity: Brak akceptacji parametrów"
		exit 1
	fi    	
#	echo ${ZENITY_OUT} 
#	echo ${NAME_PREFIX}
#	echo ${FULL_INTERVAL}
#	echo ${INC_INTERVAL}
#	echo ${EXT}
#	echo ${GZIP}
#	echo ${FILES_DIR}
#	echo ${BACKUP_DIR}
#	echo ${REMOVE}
#	exit 0
else
	#
	# read options
	#
	for i in "$@"
	do
		case $i in
    		--name=*)
			NAME_PREFIX="${i#*=}"
    		;;
   		--full-interval=*)
			FULL_INTERVAL="${i#*=}"
    		;;
	    	--inc-interval=*)
			INC_INTERVAL="${i#*=}"
   	 	;;
    		--path=*)
			FILES_DIR="${i#*=}"
	    	;;
	    	--gzip)
			GZIP=true
	    	;;
	    	--ext=*)
			EXT="${i#*=}"
    		;;
    		--backup-dir=*)
			BACKUP_DIR="${i#*=}"
    		;;
    		--remove)
			REMOVE=true
    		;;
    		-h|--help)
			HELP=true
	    	;;
    		-v|--version)
			VERSION=true
    		;;
    		*)
			echo "$i": nieznana opcja
			exit 1
    		;;
		esac
	done
fi
# print_vars
#echo "src dirname:"$(dirname $0)
# echo "base name:  "$(basename $0)
# echo "pwd:        "$(pwd)
	
if [ "${HELP}" = true ]; then
	print_help "$#"
fi

if [ ${VERSION} = true ]; then
	print_version "$#"
fi

# test FILES_DIR
if [ -d "${FILES_DIR}" ]; then
	if [ -L "${FILES_DIR}" ]; then
		FILES_DIR=$(cd -P "${FILES_DIR}" && pwd)
	else 
		FILES_DIR=$(cd "${FILES_DIR}" && pwd)
	fi
else 
	echo "Ścieżka plików do backupowania: ${FILES_DIR} nie istnieje"
	exit 1
fi

# test BACKUP_DIR
if [ -d "${BACKUP_DIR}" ]; then
	if [ -L "${BACKUP_DIR}" ]; then
		BACKUP_DIR=$(cd -P "${BACKUP_DIR}" && pwd)
	else 
		BACKUP_DIR=$(cd "${BACKUP_DIR}" && pwd)
	fi
else 
	echo "Ścieżka docelowa: ${BACKUP_DIR} nie istnieje"
   	exit 1
fi


# add to cron
SCRIPT_PATH=$(dirname $0)
SCRIPT_FULL_NAME=linuxbackup_full.sh
SCRIPT_INCR_NAME=linuxbackup_incr.sh
SCRIPT_PARAMS=${BACKUP_DIR}" "${FILES_DIR}" "${NAME_PREFIX}" "${GZIP}" "${EXT}
if [ "${REMOVE}" = false ]; then
	# add full backup to cron
	(crontab -u $USER -l ; \
    		echo "${FULL_INTERVAL} "${SCRIPT_PATH}"/"${SCRIPT_FULL_NAME}" "${SCRIPT_PARAMS}" >> "${BACKUP_DIR}"/"${NAME_PREFIX}".log 2>&1") |\
    	crontab -u $USER -
	echo "crontab for user "$USER" add line:"
	echo "${FULL_INTERVAL} "${SCRIPT_PATH}"/"${SCRIPT_FULL_NAME}" "${SCRIPT_PARAMS}" >> "${BACKUP_DIR}"/"${NAME_PREFIX}".log 2>&1"
	# add incremantal backup to cron
	(crontab -u $USER -l ; \
    		echo "${INC_INTERVAL} "${SCRIPT_PATH}"/"${SCRIPT_INCR_NAME}" "${SCRIPT_PARAMS}" >> "${BACKUP_DIR}"/"${NAME_PREFIX}".log 2>&1") |\
    	crontab -u $USER -
	echo "crontab for user "$USER" add line:"
	echo "${INC_INTERVAL} "${SCRIPT_PATH}"/"${SCRIPT_INCR_NAME}" "${SCRIPT_PARAMS}" >> "${BACKUP_DIR}"/"${NAME_PREFIX}".log 2>&1"

else
	# remove full backup from cron
	crontab -u $USER -l | grep -v "${SCRIPT_PATH}/${SCRIPT_FULL_NAME}\s${SCRIPT_PARAMS// /'\s'}" |\
	crontab -u $USER -
	# remove incremantal backup from cron
	crontab -u $USER -l | grep -v "${SCRIPT_PATH}/${SCRIPT_INCR_NAME}\s${SCRIPT_PARAMS// /'\s'}" |\
	crontab -u $USER -
	
fi

