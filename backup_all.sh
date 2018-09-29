#!/usr/bin/bash

EXEC_PATH=/home/dwpaley/backuptest
HOSTS_FILE=/home/dwpaley/backuptest/rsync_hosts
DEST_PATH=/home/dwpaley/backuptest/dest/CNILabs_backup/
ERRLOG=$DEST_PATH/backuplog

LOCK_NAME=backup_all
LOCK_DIR=/tmp/${LOCK_NAME}.lock
PID_FILE=${LOCK_DIR}/${LOCK_NAME}.pid

if mkdir $LOCK_DIR 2>/dev/null

then
    # previous job was finished
    echo $$ > $PID_FILE

    # Do the backup job on all lines in HOSTS_FILE
    while IFS=, read name user ip port remotepath junk
    do
        $EXEC_PATH/backup.sh "$user@$ip:$remotepath" $DEST_PATH $name $port \
            2> /tmp/backup.log
        if [ -s /tmp/backup.log ]
        then
            echo >> $ERRLOG
            echo `date` >> $ERRLOG
            echo "Error: $name" >> $ERRLOG
            cat /tmp/backup.log >> $ERRLOG
        fi
    done < <(cat $HOSTS_FILE)

    # Should do some form of drive push as well

    rm -rf $LOCK_DIR
    exit

else
    #previous job still running OR crashed
    if [ -f $PID_FILE ] && kill -0 $(cat $PID_FILE) 2> /dev/null
    then 
        echo "Running [PID $(cat ${PID_FILE})]" >&2
        exit
    else
        rm -rf $LOCK_DIR
        exit
    fi

fi
