#!/usr/bin/bash

EXEC_PATH=/home/dwpaley/backup #CHANGE THIS
DEST_PATH=/home/dwpaley/backup/backupdest/CNILabs_backup #CHANGE THIS
read MAILTO < $EXEC_PATH/local_data/email_list
cd $DEST_PATH


mail -s "Storage report" $MAILTO < <(
read dname dtotal dused dfree junk < <(df -B1024000000|grep centos01-home) #CHANGE THIS
echo "Free space (GB): $dfree"
echo "Storage used in old backups (GB, rounded up):"
echo 
find . -type d -maxdepth 2 -name history -exec du -B1024000000 -d0 {} \; 2>/dev/null
echo 
echo "Storage used in current backups (GB, rounded up):"
find . -type d -maxdepth 2 -name backup -exec du -B1024000000 -d0 {} \; 2>/dev/null
)
