#!/usr/bin/bash

# call this with $ ./backup.sh <full source string> <dest> <src alias> <port>

SRC_DIR=$1
DEST_DIR=$2
SRC_ALIAS=$3
PORT=$4
timestamp=$(date "+%Y%m%d_%H%M%S")
read -d_ datestamp junk < <(echo $timestamp)

logdir=$DEST_DIR/$SRC_ALIAS/log/$timestamp
historydir=$DEST_DIR/$SRC_ALIAS/history/$datestamp
backupdir=$DEST_DIR/$SRC_ALIAS/backup
errlog=$DEST_DIR/backuplog


#make the directory structure for the backup copy
install --directory $historydir
install --directory $backupdir/
install --directory $logdir
touch $logdir/backup
touch $historydir/../MANIFEST.txt
touch $historydir/.skip_backup

#find changes since last run
rsync --dry-run --itemize-changes --out-format="%i|%n|" --recursive \
    --update --delete --one-file-system --protect-args -e"ssh -p$PORT" \
    --exclude=".allowed_users" \
    "$SRC_DIR" $backupdir | \
    sed '/^ *$/d' > \
    $logdir/dryrun 

#make the changed, created, deleted lists
grep "^.f" $logdir/dryrun >> \
    $logdir/onlyfiles
grep "^.f+++++++++" $logdir/onlyfiles | \
    awk -F '|' '{print $2 }' | \
    sed 's@^/@@' >> \
    $logdir/created
grep --invert-match "^.f+++++++++" $logdir/onlyfiles | \
    awk -F '|' '{print $2 }' | \
    sed 's@^/@@' >> \
    $logdir/changed
grep "^\.d" $logdir/dryrun | \
    awk -F '|' '{print $2 }' | \
    sed -e 's@^/@@' -e 's@/$@@' >> \
    $logdir/changed
grep "^cd" $logdir/dryrun | \
    awk -F '|' '{print $2 }' | \
    sed -e 's@^/@@' -e 's@/$@@' >> \
    $logdir/created
grep "^*deleting" $logdir/dryrun | \
    awk -F '|' '{print $2 }' >> \
    $logdir/deleted


#the following are the files that have been changed or deleted
cat $logdir/deleted > /tmp/rsync.list
cat $logdir/changed >> /tmp/rsync.list
sort  --unique /tmp/rsync.list > $logdir/ch_del

cat $logdir/ch_del | while read line
do
    if ! grep "$line" $historydir/.skip_backup  
    then
        if ! grep "===${datestamp}===" $historydir/../MANIFEST.txt
        then
            echo >> $historydir/../MANIFEST.txt
            echo "===${datestamp}===" >> $historydir/../MANIFEST.txt
        fi
        echo $line >> $historydir/../MANIFEST.txt
        echo $line >> $logdir/backup
    fi
done

cat $logdir/created >> $historydir/.skip_backup
cat $logdir/backup >> $historydir/.skip_backup



#take the changed/deleted files and make a history point
rsync --update --files-from=$logdir/backup -e"ssh -p$PORT" \
    --protect-args --no-perms --chmod=ugo=rwX --exclude=".allowed_users" \
    $backupdir/ \
    $historydir 
    
#update the main backup directory to mirror the source
rsync --recursive --update --delete --one-file-system -P \
    --protect-args -e"ssh -p$PORT" --no-perms --chmod=ugo=rwX \
    --exclude=".allowed_users" \
    "$SRC_DIR" \
    $backupdir 

#cleanup:
if [ -s /tmp/rsync.errlog ]
then
    echo >> $errlog
    echo "Error: $SRC_ALIAS" >> $errlog
    cat /tmp/rsync.errlog >> $errlog
fi

if [ ! -s $logdir/dryrun ]
then
    rm -rf $logdir
fi

if [ ! -s $historydir/.skip_backup ]
then
    rm -rf $historydir
fi
