#!/usr/bin/bash

EXEC_PATH=/home/dwpaley/backup #CHANGE THIS
HOSTS_FILE=/home/dwpaley/backup/local_data/rsync_hosts #CHANGE THIS
DEST_PATH=/home/dwpaley/backup/backupdest/CNILabs_backup/ #CHANGE THIS
ERRLOG=$DEST_PATH/backuplog

read MAILTO < $EXEC_PATH/local_data/email_list

LOCK_NAME=backup_all
LOCK_DIR=/tmp/${LOCK_NAME}.lock
PID_FILE=${LOCK_DIR}/${LOCK_NAME}.pid


if ! mkdir $LOCK_DIR 2>/dev/null

then
    #previous job still running OR crashed
    if [ -f $PID_FILE ] && kill -0 $(cat $PID_FILE) 2> /dev/null
    then 
        echo "A backup or rewind job is currently running [PID $(cat ${PID_FILE})]" >&2
        exit
    else
	echo "There was an abandoned backup or rewind job. You may try again immediately."
        rm -rf $LOCK_DIR
        exit
    fi
fi
echo $$ > $PID_FILE

# if we get here, the previous job was finished successfully


# Do the backup job on all lines in HOSTS_FILE
while IFS=, read name user ip port remotepath junk1 exclude junk
do

	if [ $name == "end" ]
	then
	    break
	fi

	echo "========== Backing up $name =========="

        $EXEC_PATH/backup.sh "$user@$ip:$remotepath" $DEST_PATH $name $port \
	    "$EXEC_PATH/$exclude" 2> /tmp/backuplog.txt 

        if [ -s /tmp/backuplog.txt ]
        then
            echo >> $ERRLOG
            echo `date` >> $ERRLOG
            echo "Error: $name" >> $ERRLOG
	    mail -s "backup error: $name" -a /tmp/backuplog.txt $MAILTO <<<""
            cat /tmp/backuplog.txt >> $ERRLOG
        fi

done < <(cat $HOSTS_FILE)


# Cleanup by deleting the PID lock file and sending a notification email
rm -rf $LOCK_DIR
mail -s "backup done" $MAILTO <<<"CNI Labs backup done at $(date)"

