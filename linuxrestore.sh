#!/bin/bash


print_help(){
	if [ "$1" -gt 1 ]; then
		echo "Użycie opcji -h lub --help z innymi opcjami jest niedozwolone"
		exit 1
	fi
	echo " ---- HELP: napisz man linuxrestore -----"
	exit 0
}

print_version(){
	if [ "$1" -gt 1 ]; then
		echo "Użycie opcji -v lub --version z innymi opcjami jest niedozwolone"
		exit 1
	fi
	echo " ---- VERSION: program 0.01 -----"
	exit 0

}
###################################################################

#
# init
#
HELP=false
VERSION=false
GZIP=false
NAME_PREFIX=""
DATE_TO_RESTORE=""
BACKUP_DIR=""
OUT_DIR=""
###################################
# czytaj ustawienia

source $(dirname $0)/backup.config

# echo "ZENITY=${ZENITY}"

ZENITY_OUT=""

if [ "${ZENITY}" == "ON" ]; then
	ZENITY_OUT=$( zenity --forms --height 250 --width 600 \
                            --title="Parametry Backupu do dodania" \
                            --text="Podaj prefix backupu oraz parametry czasowe:" \
                            --separator="|" \
                            --add-entry="Prefix nazwy:" \
                            --add-entry="Czas, na który odtworzyć (np.:2017_05_14_12_01):" \
                            --add-list "Czy kompresować?" --list-values "TAK|NIE")
	ACCEPTED=$?
        if [ ! "${ACCEPTED}" == "0" ]; then
		echo "Zenity: Brak akceptacji"
		exit 1
	fi
	NAME_PREFIX=$(awk --field-separator='|' '{print $1}' <<<${ZENITY_OUT})
	DATE_TO_RESTORE=$(awk --field-separator='|' '{print $2}' <<<${ZENITY_OUT})
	GZIP=$(awk --field-separator='|' '{print $3}' <<<${ZENITY_OUT})
	if [ "${GZIP}" == "TAK" ]; then
		GZIP=true
	else
		GZIP=false
	fi
	BACKUP_DIR=$(zenity --file-selection --title="Ścieżka do plików z backupem:" --directory )                            
	ACCEPTED=$?
        if [ ! "${ACCEPTED}" == "0" ]; then
		echo "Zenity: Brak akceptacji ścieżki do backupów"
		exit 1
	fi                         
	OUT_DIR=$(zenity --file-selection --title="Ścieżka do wypakowania plików:" --directory )                            
	ACCEPTED=$?
        if [ ! "${ACCEPTED}" == "0" ]; then
		echo "Zenity: Brak akceptacji ścieżki do backupów"
		exit 1
	fi                         

	QUESTION=$(zenity --question --height 250 --width 600 --title="Podsumowanie" --text="Ustawiono:\nname=${NAME_PREFIX}\ndate=${DATE_TO_RESTORE}\nbackup-dir=${BACKUP_DIR}\nout-dir=${OUT_DIR}\ngzip=${GZIP}\n\nCzy akceptujesz ustawienia? ")
	ACCEPTED=$?
        if [ ! "${ACCEPTED}" == "0" ]; then
		echo "Zenity: Brak akceptacji parametrów"
		exit 1
	fi    	
#	echo ${ZENITY_OUT} 
#	echo ${NAME_PREFIX}
#	echo ${DATE_TO_RESTORE}
#	echo ${BACKUP_DIR}
#	echo ${OUT_DIR}
#	echo ${GZIP}
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
    		--date=*)
			DATE_TO_RESTORE="${i#*=}"
    		;;
    		--backup-dir=*)
			BACKUP_DIR="${i#*=}"
    		;;
    		--out-dir=*)
			OUT_DIR="${i#*=}"
    		;;
    		--gzip)
			GZIP=true
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
	
if [ "${HELP}" = true ]; then
	print_help "$#"
fi

if [ ${VERSION} = true ]; then
	print_version "$#"
fi

# test OUT_DIR
if [ -d "${OUT_DIR}" ]; then
	if [ -L "${OUT_DIR}" ]; then
		OUT_DIR=$(cd -P "${OUT_DIR}" && pwd)
	else 
		OUT_DIR=$(cd "${OUT_DIR}" && pwd)
	fi
else 
	echo "Ścieżka do odtworzenia plików: ${OUT_DIR} nie istnieje"
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
	echo "Ścieżka do kopii zapasowych: ${BACKUP_DIR} nie istnieje"
   	exit 1
fi

# archiv gziped or not
if [ "${GZIP}" = true ]; then
	TAR_OPT="-xvzf"
	BACKUP_EXT="tgz"
else
	TAR_OPT="-zvf"
	BACKUP_EXT="tar"
fi

# check DATE_TO_RESTORE
DATE_REGEX="^[0-9]{4}_[0-9]{2}_[0-9]{2}_[0-9]{2}_[0-9]{2}"
TAR_FILES=""

if [[ "${DATE_TO_RESTORE}" =~ ${DATE_REGEX} ]]; then
	# echo "find ${BACKUP_DIR} -name ${NAME_PREFIX}_full_*.${BACKUP_EXT}" 
	FULL_BACKUPS=$(find ${BACKUP_DIR} -name "${NAME_PREFIX}_full_*.${BACKUP_EXT}" | sort )
	# echo ${FULL_BACKUPS}	
	NAME_TO_COMPARE=${BACKUP_DIR}"/"${NAME_PREFIX}"_full_"${DATE_TO_RESTORE}"."${BACKUP_EXT}
	NUM_OF_SEP=$(echo ${NAME_PREFIX}"_full_" | grep -o "_" | wc -l )
 
	FULL_BACKUP=""
	# FULL_BACKUP_PREV=""
	for file in ${FULL_BACKUPS}
	do
		# FULL_BACKUP_PREV=${FULL_BACKUP}
		if [[ ! "$file" > "${NAME_TO_COMPARE}" ]]; then
			FULL_BACKUP=$file
		fi
	done
	if [ -z "${FULL_BACKUP}" ]; then 
		echo "Nie mogę znaleźć pełnego backupu spełniającego wszystkie warunki"
		exit 1
	fi
	#echo ${FULL_BACKUP}
	NAME_TO_COMPARE=${BACKUP_DIR}"/"${NAME_PREFIX}"_incr_"${DATE_TO_RESTORE}"."${BACKUP_EXT}
	
	YEAR_SEG=$((${NUM_OF_SEP} + 1))
	MON_SEG=$((${YEAR_SEG} + 1))
	DAY_SEG=$((${MON_SEG} + 1))
	H_SEG=$((${DAY_SEG} + 1))
	M_SEG=$((${H_SEG} + 1))
	
	ALL_BACKUPS=$(find ${BACKUP_DIR} -name "${NAME_PREFIX}*.${BACKUP_EXT}" |\
			 sort -t_ -k${YEAR_SEG} -k${MON_SEG} -k${DAY_SEG} -k${H_SEG} -k${M_SEG} -k${NUM_OF_SEP}r)
	# echo ${ALL_BACKUPS}
	for file in ${ALL_BACKUPS}
	do
		# echo $file
		if [ -n "${TAR_FILES}" ]; then
			if [[ $file =~ ${BACKUP_DIR}/${NAME_PREFIX}_incr_* ]]; then
				if [[ ! "$file" > "${NAME_TO_COMPARE}" ]]; then
					TAR_FILES=${TAR_FILES}" "$file
				fi
			fi 
		fi
		if [ "${FULL_BACKUP}" == "${file}" ]; then
			TAR_FILES="${FULL_BACKUP}"
		fi
			
	done
else
	echo "Opcja --date= powinna posiadać format: rok_miesiąc_dzień_godzina_minuta"
	echo "Znaleziono: ${DATE_TO_RESTORE}"
	echo "Przykład:   2017_05_14_16_40"
   	exit 1
fi

for file in ${TAR_FILES}
do
	echo "tar ${TAR_OPT} ${file} -C ${OUT_DIR}"
	tar ${TAR_OPT} ${file} -C ${OUT_DIR}
done
