#!/usr/bin/bash

EXEC_PATH=/home/dwpaley/backup #CHANGE THIS
PURGE_PATH=$EXEC_PATH/purge_files
HOSTS_FILE=/home/dwpaley/backup/local_data/rsync_hosts #CHANGE THIS
DEST_PATH=/home/dwpaley/backup/backupdest/CNILabs_backup #CHANGE THIS

rm -rf $PURGE_PATH
mkdir $PURGE_PATH


# Choose the computer to purge
n=0
while IFS=, read name user ip port remotepath junk1 exclude junk
do
    if [ $name = "end" ]; then break; fi
    echo -e "$n \t $name"
    hosts_list[$n]="$name,$user,$ip,$port,$remotepath,$junk1,$exclude,$junk"
    let n=$n+1
done < <(cat $HOSTS_FILE)

echo

read -p "Purge backups for computer # " hostn
IFS=, read toolname junk < <(echo "${hosts_list[$hostn]}")


#Choose the backup date to rewind to
n=0
while read backupdate
do
    echo $backupdate >> $PURGE_PATH/backupdates
    echo -e "$n \t $backupdate"
    let n=$n+1
done < <(ls -1 $DEST_PATH/$toolname/history |sed '/MANIFEST.txt/d')
    

let n=n-1
echo 
echo Select a date.
echo 
echo Backups before the selected date will be deleted.
echo
read -p "Type a number (e.g. $n), not a date: " daten



head -n +$daten $PURGE_PATH/backupdates \
    |sort -r \
    |sed "s@^@$DEST_PATH/$toolname/history/@" \
    > $PURGE_PATH/purge_todo

read spacefreed junk < <(du -hcs --files0-from=- < <(tr '\n' '\0' <$PURGE_PATH/purge_todo)|tail -1)
echo
echo -n "$spacefreed will be freed. Backups for $toolname for "
echo "$(basename "$(head -1 $PURGE_PATH/purge_todo)")" and earlier will be deleted.
echo
read -p "If you want to proceed, please type YES: " answer

if [ $answer = YES ]
then
    while read delpath
    do
	rm -rf $delpath
    done < $PURGE_PATH/purge_todo
    echo "The old backups were purged."
else
    echo "Nothing was done."
fi







echo
echo Done
read -p "Press enter to quit"
rm -rf $PURGE_PATH
