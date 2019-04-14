#!/bin/bash
# Name :- Pushkar Madan.
# Email :- pushkar.madan@yahoo.com
# Date :- 15 April 2019
# Purpose :- Generalise and Standardize git script which can be easily deployed for various modules just by add paths to temp-dir and prod-dir.
# Milestone :- None
# Stake :- Undefined.
# Last modification of generic script :- 15 April 2019
# Reason for last modification :- Creation.
# Script Type :- Generic (This will enable identifying script easily using grep  to add  patch from generic scripts if necessary.)
# Notes :- Script is based on idea where checkout|clone of the code is made in temperoary directory and  then synced to production directory excluding irrelevant files and folder.
# 

### Initalizing variables with default value. (Don't change the value unless you want to mess with the logic of script.)
UPDATE_FLAG="0"
REVERT_FLAG="0"
SET_ENV_FLAG="0"
SEND_SMS_FLAG="0"
SEND_MAIL_FLAG="0"
USE_TAG="0"
TFLAG="0"
LATEST="0" 
STAGE="0" ### To determine message to be displayed when syncing code.
DT=$(date +%d-%m-%Y)
### End of default variables.

### Variables which needs to be updated when deploying script.
SEND_MAIL_ID="alerts@example.com"
MAIL_RECIPIENT="foo@example.com" ### One can add multiple recipients, using comma seperated list.
TEMP_DIR="" ### Path to the temperoary checkout directory.
PROD_DIR="" ### Path to production directory i.e. DocRoot.
MODULE="" ### Name of the module|application|service for which code is being take live.
HASH_RANGE="50" #When reverting check maximum of 50  old heads in history.
APP_USER="apache"
RSYNC_EXCLUDE="--exclude=.svn --exclude=.git"
SMS_NO_FILE=""
### End of editable variables.

line() {
echo -e "\n----------------------------\n"
}

bigline() {
echo -e "\n===============================================================================\n"
}

logfile() {
tee -a /var/log/${MODULE}_git_${DT}.txt
}

### To display how to use the script.
USAGE(){
echo -e "Kindly pass appropriate options and arguments.\nUsage :- ${0} -h (For help)\n \t ${0} {-r (To revert git code.) OR -u (To update to given Revision diff not more than 50) OR -t \"<TAG>\" (To updated the code to given tag.)} \n \t ${0} -t \"<git tag>\"\n \t ${0} -n \"<git Hash>|latest\"(This is necessary with -u and -r, you can pass either \"<git hash>\" or \"latest\" to this.\"latest\" can be used only with update -u  and same will update the code to latest head available.)\n \t ${0} -s (To send SMS, provided standars sms script and sms number file is defined and available.)\n \t ${0} -m (To send MAIL)"

}

### To exit after displaying usage.
BAD_USAGE(){
USAGE
exit 3

}

### To check if multiple instance are running.
CHECK_INSTANCE(){
#pass the script name to funcion.
INSTANCE=${0##/*/}
LOCF=/tmp/${INSTANCE%.*}.lock
INSTANCE_COUNT="$(pgrep -caf ${INSTANCE} )"
DEF_INST_COUNT=0

# to enable passing function if used with sudo.
if [ ! -z  "${SUDO_USER}" ]; then
    DEF_INST_COUNT="2"
elif [ -z "${SUDO_USER}" ] ; then
    DEF_INST_COUNT="1"
else
    echo "some thing wrong."
    exit 11
fi

echo "Total Instance Count :- ${INSTANCE_COUNT}"
if [ "${INSTANCE_COUNT}" -gt "${DEF_INST_COUNT}" ]; then
    echo "More than one instance running exiting script"
    exit 12
elif [ "${INSTANCE_COUNT}" -le "${DEF_INST_COUNT}" ];then
    echo -e "Seems Single instance running for :- ${INSTANCE}\nContinuing with execution of script."
else
    echo "instance check conditions doesn't match exiting."
    exit 13
fi

if [ -e "${LOCF}" ] ;then
    echo "lockfile ${LOCF} already exists .... exiting"
    exit 14
else
    echo "Creating lock file."
    touch "${LOCF}"
fi

}


### Verify if hash is valid.
VERIFY_HASH(){
USER_HEAD="${1}"
if [ "$(echo ${USER_HEAD} | wc -c)" -eq 41 ];then
	echo "Seems to be a valid Hash."
elif [ "${USER_HEAD}" == "latest" ];then
	echo "Seems you have chosen lastest."
else
	echo "Hash provided by you seems to be invalid, exiting."
	exit 2
fi

}

### To sync the code.
SYNC_CODE(){
CURRENT_HEAD=$(cd ${TEMP_DIR} && git log -n 1 | awk '/^commit\ /&&$0=$2')

if [ "${PROD_HEAD}" != "${CURRENT_HEAD}" ]; then

	echo "Updating permission on temp directory."
	chown -R ${APP_USER}. ${TEMP_DIR}
	
	echo "Syncing Code ..."
	rsync -crvogWP ${RSYNC_EXCLUDE} ${TEMP_DIR} ${PROD_DIR}
else
	echo "Seems both old HEAD ${PROD_HEAD} and new HEAD ${CURRENT_HEAD} are same no need to Sync code Exiting."
	exit 0
fi

### Display appropriate messages for logging and  debugging in future.
if [ "${STAGE}" == "1" ];then
	bigline
	[ -n "${PROD_TAG}" ] && echo "Updated from Production Tag ${PROD_TAG} to HEAD :- ${REV} as on $(date)" || echo "Updated production head from ${PROD_HEAD} to ${REV} as on $(date)"
	bigline
elif [ "${STAGE}" == "2" ];then
	bigline
	[ -n "${PROD_TAG}" ] && echo "Updated from Production Tag ${PROD_TAG} to HEAD :- ${CURRENT_HEAD} as on $(date)" || echo "Updated production head from ${PROD_HEAD} to ${CURRENT_HEAD} as on $(date)"
	bigline
elif [ "${STAGE}" == "3" ];then
	bigline
	[ -n "${PROD_TAG}" ] && echo "Reverted from Production Tag ${PROD_TAG} to HEAD :- ${REV}" || echo "Reverted production head from ${PROD_HEAD} to ${REV} as on $(date)"
	bigline
elif [ "${STAGE}" == "4" ];then
	bigline
	[ -n "${PROD_TAG}" ] && echo "Changing from Production Tag ${PROD_TAG} to ${TAG} as on $(date)" || echo "Changing from production HEAD ${PROD_HEAD} to Tag ${TAG} as on $(date)"
	bigline
else
	bigline
	bigline
	echo "ATTENTION !! WARNING !! NO VALID STAGE RECORDED KINDLY CHECK IF THE CODE UPDATE PROCESS HAS EXECUTED PROPERLY."
	bigline
	bigline
	exit 13
fi

SEND_SMS
SEND_MAIL

}

### To revert back to previous revision.
GIT_REVERT(){
USER_HEAD="${1}"

#echo "checking if has passed is withing safe range."
HASH_LIST="$(cd ${TEMP_DIR} && git log -n ${HASH_RANGE} | awk '/^commit/&&$0=$2')"

if $(echo ${HASH_LIST} | grep  -q -o  "${USER_HEAD}") ; then
	cd ${TEMP_DIR} && git checkout master | logfile
	cd ${TEMP_DIR} && git reset --hard "${USER_HEAD}" | logfile
	cd ${TEMP_DIR} && git clean -f | logfile
else
	echo "Seems you are trying to revert to revision older then allowed range ${HASH_RANGE}, exiting."
	exit 5
fi

SYNC_CODE

}

### To Reset back to production head.
RESET_PROD_HEAD(){
echo "Resetting HEAD back to OLD state."
cd ${TEMP_DIR} 
git checkout master
git reset --hard ${PROD_HEAD}
git clean -f

}

### To update code to newer revisions.
GIT_UPDATE(){
USER_HEAD="${1}"

if [ "${USER_HEAD}" == "latest" ] ;then
	### Updating Code to approrpiare revision.
	echo "Seems hash you've requeste to update the code to latest Head"
	cd ${TEMP_DIR}
	git checkout master
	git pull
else
	### Determining new hash list.
	cd ${TEMP_DIR} && git checkout master && git pull && NEW_HASH_LIST="$(cd ${TEMP_DIR} && git log | awk -v stop=${PROD_HEAD} 'BEGIN{show=1}{if(/^commit/ && show == 1 && $2 !~ stop ){print $2}else if(/^commit/ && $2 == stop){show=0;exit}}')" || ((echo "new unable to determing git hash" && RESET_PROD_HEAD && exit 3 ))

	if [ ! -z "${NEW_HASH_LIST}" ] && echo "${NEW_HASH_LIST}" |grep -qo "${USER_HEAD}" ; then
		echo "Seems appropriate git head provided proceeding code update process."
	else
		echo "Hash provided is not valid HEAD for updating code to newer version exiting."
		RESET_PROD_HEAD
		exit 3
	fi

	echo "Updating the head to ${USER_HEAD}"
	cd ${TEMP_DIR}
	git checkout master
	git pull
	git reset --hard "${USER_HEAD}" 
	git clean -f
fi
SYNC_CODE

}

### To work with git tags.
GIT_TAG(){
OLDIFS="${IFS}"
IFS=$'\n' ### In case whitespaces are used un tag names.

for REPO_TAG in $(cd ${TEMP_DIR} && git fetch && git tag );do 
	if [ "${REPO_TAG}" == "${TAG}" ];then TFLAG=1; break;fi
done

if [ ${TFLAG} == "1" ];then
	cd ${TEMP_DIR}
	git fetch
	git checkout "${TAG}"
else
	echo "Seems you've provided incorrect tag, exiting."
	exit 2
fi

IFS="${OLDIFS}" ### Resetting IFS so it won't mess with for loops executed in future.
SYNC_CODE

}

### For sending SMS.
SEND_SMS(){
SMS_REV="$(cd ${TEMP_DIR} && git log -n 1 |  awk '/^commit/&&$0=$2' )"
SMS_AUTH="$(cd ${TEMP_DIR} && git log -n1 | awk '/^Author:/&&$0=$2":"$3')"
SMS_COMMENT="$(cd ${TEMP_DIR} && git log -n1 | awk '!/commit\ /&&!/^Author:\ /&&!/^Date:\ /&&NF')"
SMSTEXT=$(echo "${MODULE} code ${1}, taken live by : ${SMS_AUTH}; Rev : ${SMS_REV}; Info : ${SMS_COMMENT}")

echo "Checking if valid SMS recipient list available."

if [ "${SEND_SMS_FLAG}" != "1" ];then
	echo "SMS send flag is not enabled."
	break 
elif [ "${SEND_SMS_FLAG}" == "1" -a ! -f "${SMS_NO_FILE}" ];then
	echo "SMS send flag enabled but, ${SMS_NO_FILE} doesn't exists not sending SMS."
	exit 9
elif [ -f "${SMS_NO_FILE}" -a "${SEND_SMS_FLAG}" == "1" -a "$(grep -v ^\# ${SMS_NO_FILE}|wc -l | awk '{print $1}')" -ge "1" ];then
	echo "${SMS_NO_FILE} Seems to exists with more than one entry and SMS flag is enabled Sending SMS."
	/scripts/standard_sms_sending_script.sh -m "${SMSTEXT}" -f ${SMS_NO_FILE}

elif [ -f "${SMS_NO_FILE}" -a "${SEND_SMS_FLAG}" == "1" -a "$(grep -v ^\# ${SMS_NO_FILE}|wc -l | awk '{print $1}')" -lt "1" ];then
	echo "Seems ${SMS_SEND_FILE} doesn't contain appropriate entries for sms recipient[s]."
	exit 10
else
	echo "Kindly Ignore this :- Not enough information avaialble for Sending SMS."
fi

}

### For sending MAIL.
SEND_MAIL(){
MAIL_REV="$(cd ${TEMP_DIR} && git log -n 1 |  awk '/^commit/&&$0=$2' )"
MAIL_AUTH="$(cd ${TEMP_DIR} && git log -n1 | awk '/^Author:/&&$0=$2":"$3')"
MAIL_COMMENT="$(cd ${TEMP_DIR} && git log -n1 | awk '!/commit\ /&&!/^Author:\ /&&!/^Date:\ /&&NF')"
MAIL_BODY="$(echo "${MODULE} code ${1}, taken live by : ${MAIL_AUTH}; Rev : ${MAIL_REV}; Info : ${MAIL_COMMENT}")"
MAIL_SUB="Code for ${MODULE} taken live - $(date +'%Y-%m-%d %T' )" 

echo "Checking if valid MAIL recipient list available."

if [ "${SEND_MAIL_FLAG}" != "1" ];then
	echo "Mail send flag is not enabled."
	break 
elif [ "${SEND_MAIL_FLAG}" == "1" ];then
	echo "${MAIL_BODY}"	| mail -s "${MAIL_SUB}" ${MAIL_RECIPIENT}
else
	echo "Kindly Ignore this :- Not enough information avaialble for Sending Mail."
fi

}

LOG_HEADER(){
PROD_HEAD="$(cd ${TEMP_DIR} && git log -n 1 | awk '/^commit/&&$0=$2')"
PROD_TAG="$(cd ${TEMP_DIR} && git status | awk '/^HEAD\ detached\ at\ /&&sub("HEAD detached at ","")')"

bigline
[ -n "${PROD_TAG}" ] && echo "Starting Code update Process while production TAG on \"${PROD_TAG}\", and HEAD :- \"${PROD_HEAD}\" as on $(date)" ||  echo "Starting Code update Process while production HEAD :- \"${PROD_HEAD}\" as on $(date)"
bigline

}

### Main

CHECK_INSTANCE

trap "rm -f ${LOCF}" SIGINT SIGTERM EXIT

while getopts "h n: u r s t: m" o ; do
	case "${o}" in
		h)
			USAGE
			exit 0
		;;
		n)
			REV="${OPTARG}"
		;;
		u)
			UPDATE_FLAG="1"
		;;
		r)
			REVERT_FLAG="1"
		;;
		s)
			SEND_SMS_FLAG="1"
		;;
		t)
			TAG="${OPTARG}"
			USE_TAG="1"
		;;
		m)
			SEND_MAIL_FLAG="1"
		;;
		*)
			BAD_USAGE
		;;
	esac
done

shift $((OPTIND-1))

### Verify flags.
if [ -z "${TEMP_DIR}" -o -z "${PROD_DIR}" ];then
	echo "Seems Temperoary directory and production directories are not defined in script exiting."
	exit 3
elif [ "${UPDATE_FLAG}" == "1" -a "${REVERT_FLAG}" == "0" -a "${USE_TAG}" == "0" -a -n "${REV}" -a "${REV}" != "latest" ];then
	STAGE="1"
	echo "Udate flag provided updating code."
	VERIFY_HASH "${REV}"
	LOG_HEADER
	GIT_UPDATE "${REV}"
	
elif [ "${UPDATE_FLAG}" == "1" -a "${REVERT_FLAG}" == "0" -a "${USE_TAG}" == "0" -a "${REV}" == "latest" ];then
	STAGE="2"
	echo "Updating code to latest head available."
	VERIFY_HASH "${REV}"
	LOG_HEADER
	GIT_UPDATE "${REV}"

elif [ "${UPDATE_FLAG}" == "0" -a "${REVERT_FLAG}" == "1" -a "${USE_TAG}" == "0" -a -n "${REV}" -a "${REV}" != "latest" ];then
	STAGE="3"
	echo "Revert flag provided reverting code."
	VERIFY_HASH "${REV}"
	LOG_HEADER
	GIT_REVERT "${REV}"

elif [ "${UPDATE_FLAG}" == "0" -a "${REVERT_FLAG}" == "0" -a "${USE_TAG}" == "1" -a -n "${TAG}" ];then
	STAGE="4"
	echo "User will be using tag."
	LOG_HEADER
	GIT_TAG "${TAG}"

else
	STAGE=0
	echo "Seems you've chosen to perform more than one permitted operation at a time, i.e either update to given head, or revert to given head, or change the head to given tag exiting."
	BAD_USAGE

fi
