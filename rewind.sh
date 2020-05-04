#!/usr/bin/bash

EXEC_PATH=/home/dwpaley/backup
REWIND_PATH=$EXEC_PATH/rewind_files
HOSTS_FILE=/home/dwpaley/backup/local_data/rsync_hosts
DEST_PATH=/home/dwpaley/backup/backupdest/CNILabs_backup
read MAILTO < $EXEC_PATH/local_data/email_list

ALWAYS_EXCLUDE=/home/dwpaley/backup/always_exclude

rm -rf $REWIND_PATH
mkdir $REWIND_PATH


# All the lock stuff is to make sure two jobs don't run concurrently. This shares
# a lock file with the backup_all script.

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



echo
echo "############################## REWIND ###############################"
echo
echo This can be a long job. I strongly recommend running it in person in 544 Hav.
echo because losing your SSH session while the job is in progress will cause needless
echo complications.
echo

# Choose the computer to rewind
n=0
while IFS=, read name user ip port remotepath junk1 exclude junk
do
    if [ $name = "end" ]; then break; fi
    echo -e "$n \t $name"
    hosts_list[$n]="$name,$user,$ip,$port,$remotepath,$junk1,$exclude,$junk"
    let n=$n+1
done < <(cat $HOSTS_FILE)

echo

read -p "Rewind computer # " hostn
IFS=, read toolname junk < <(echo "${hosts_list[$hostn]}")




# Check that there's enough free disk space (using df to check the hard drive and du to check
# the tool backup directory)
echo 
echo Checking free disk space. This may take a few minutes.
echo

read dname dtotal dused dfree junk < <(df -B1024000000|grep centos01-home) #CHANGE THIS
read dneeded junk < <(du -cd0 -B1024000000 $DEST_PATH/$toolname |tail -1)
let dneeded_safetymargin=$dneeded+100
let moreneeded=$dneeded_safetymargin-$dfree

echo "Backup $toolname"
echo "There are $dfree GB available and $dneeded_safetymargin GB needed. "

if [ $moreneeded -gt 0 ]
then
    echo "Not enough space. Please free $moreneeded GB and try again."
    exit
fi
#If we get here, there is enough space


# Now we make a fresh backup
echo
echo Counting files. May take up to 20 min for extremely large directories.
read nfiles junk < <(find $DEST_PATH/$toolname |wc)
let btime=$nfiles/40000+1
echo "The tool will now be backed up. Allow about $btime minutes."

IFS=, read name user ip port remotepath junk1 exclude junk < <(echo "${hosts_list[$hostn]}")
$EXEC_PATH/backup.sh "$user@$ip:$remotepath" $DEST_PATH $name $port \
    "$EXEC_PATH/$exclude" 2> /tmp/backuplog.txt

if [ -s /tmp/backuplog.txt ]
then
    cat /tmp/backuplog.txt
    echo The backup failed with the error listed above. Please fix it and try again.
    rm -rf $REWIND_PATH
    rm -rf $LOCK_DIR
    exit
fi






# Make a mirror of the tool backup.
let copytime=$dneeded/4+1
echo "Processing. This will take approximately $copytime minutes."
cp -rp $DEST_PATH/$toolname/backup $REWIND_PATH




#Choose the backup date to rewind to
n=0
while read backupdate
do
    echo $backupdate >> $REWIND_PATH/backupdates
    echo -e "$n \t $backupdate"
    let n=$n+1
done < <(ls -1 $DEST_PATH/$toolname/history |sed '/MANIFEST.txt/d')
    

let n=n-1
echo 
echo Select a date.
echo 
echo Legacy backups may not have a timestamp. These will typically rewind to ~12:01am
echo on the selected date.
echo
echo More recent backups are date- and time-stamped and will rewind to the 
echo specified date and time.
echo 
read -p "Type a number (e.g. $n), not a date: " daten

let daten=$daten+2	#We want to apply the cutoff after the selected date, not before


tail -n +$daten $REWIND_PATH/backupdates |sort -r > $REWIND_PATH/rewind_todo



# Go through the dated backups and rewind them one by one
while read rewind_date
do
    rm -f $REWIND_PATH/delete_todo

    #list all the files that were created on the date
    for f in $DEST_PATH/$toolname/log/$rewind_date*/created
    do
        cat $f >> $REWIND_PATH/delete_todo
    done

    #delete all those created files
    while read delete_item
    do
	rm -rf "$REWIND_PATH/backup/$delete_item"
    done < $REWIND_PATH/delete_todo
    
    #take all changed/deleted files (the contents of the history directory) and sync them back
    #into the mirror directory to rewind those changes
    rsync -rltD --exclude=".skip_backup" \
        $DEST_PATH/$toolname/history/$rewind_date/ $REWIND_PATH/backup 

done < $REWIND_PATH/rewind_todo






IFS=, read name user ip port remotepath junk1 exclude junk < <(echo "${hosts_list[$hostn]}")



rsync -n --itemize-changes --out-format="%i|%n|" \
    -rltD --delete --one-file-system -P \
    --protect-args -e"ssh -p$port" \
     --exclude-from="$EXEC_PATH/$exclude" \
    --exclude-from="$ALWAYS_EXCLUDE" \
    "$REWIND_PATH/backup/$(basename "$remotepath")/" \
    "$user@$ip:$remotepath" \
    |sed '/\.d\.\.t\.\.\.\.\.\./d' \
    |sed '/\.f\.\.t\.\.\.\.\.\./d' \
    >/tmp/rewind_todo.txt

mail -s "Proposed changes for $toolname rewind" -a /tmp/rewind_todo.txt $MAILTO <<<""

echo
echo "A test run was performed. A list of changes for the rewind was sent to"
echo "the emails in $EXEC_PATH/local_data/email_list and is also found in "
echo "/tmp/rewind_todo.txt."
echo
echo "Please check the change list. Files that will be sent to the tool PC are"
echo "labeled with a < and deletions are labeled *deleting."
echo
read -p "If you want to proceed, please type YES: " answer

if [ $answer = YES ]
then
    rsync -rltD --delete --one-file-system -P \
        --protect-args -e"ssh -p$port" \
         --exclude-from="$EXEC_PATH/$exclude" \
        --exclude-from="$ALWAYS_EXCLUDE" \
        "$REWIND_PATH/backup/$(basename "$remotepath")/" \
        "$user@$ip:$remotepath" 
else
    echo 
    echo Nothing was changed.
fi


echo
echo Done
read -p "Press enter to quit"
rm -rf $REWIND_PATH
rm -rf $LOCK_DIR















