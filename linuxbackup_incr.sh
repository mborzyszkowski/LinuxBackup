#!/bin/bash


BACKUP_DIR=$1
FILES_DIR=$2
NAME_PREFIX=$3
GZIP=$4

# check if ext is set

if [ ! -z "$5" ]; then
	FIND_OPT="START"
	for ext in $(echo $5 | sed "s/,/ /g")
	do
		if [ "${FIND_OPT}" = "START" ]; then		
			FIND_OPT=.${ext}"$"
		else
			FIND_OPT=${FIND_OPT}"\|."${ext}"$"
		fi
	done
	FILE_LIST=$( find ${FILES_DIR}  | grep "${FIND_OPT}"  | tr '\n' ' ') 
	if [ "${FILE_LIST}" = "" ]; then
		 FILE_LIST=${FILES_DIR}
	fi
else
	FILE_LIST=${FILES_DIR}
fi


# current time
TIME=$(date +%Y_%m_%d_%H_%M)

echo "--------------------------"
echo "----- INCR BACKUP --------"
echo "----- at: ${TIME}"


if [ "${GZIP}" = true ]; then
	TAR_OPT="-cvzf"
	BACKUP_EXT="tgz"
else
	TAR_OPT="-cvf"
	BACKUP_EXT="tar"
fi

SNAR_FILE=${BACKUP_DIR}/${NAME_PREFIX}.snar

# incremantal backup becomes full if SNAR_FILE does not exists

if [ ! -f "${SNAR_FILE}" ]; then
	BACKUP_TYPE="full"
else
	BACKUP_TYPE="incr"
fi

TAR_FILE=${BACKUP_DIR}/${NAME_PREFIX}_${BACKUP_TYPE}_${TIME}.${BACKUP_EXT}

TAR_FILE_FULL_TMP=${BACKUP_DIR}/${NAME_PREFIX}_full_${TIME}.${BACKUP_EXT}

if [ -f "${TAR_FILE_FULL_TMP}" ]; then
	echo "linuxbackup_incr: Backup incr anulowany ponieważ istnieje FULL: ${TAR_FILE_FULL_TMP}"
	exit 0;
fi


echo "linuxbackup_incr: tar ${TAR_OPT} ${TAR_FILE} -g ${SNAR_FILE} ${FILE_LIST}"

tar ${TAR_OPT} ${TAR_FILE} -g ${SNAR_FILE} ${FILE_LIST}

