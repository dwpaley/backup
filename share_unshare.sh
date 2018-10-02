#!/usr/bin/bash

BACKUP_DIR=sandbox2/dest/CNI/CNILabs_backup

cat $BACKUP_DIR/.allowed_users | while read user; do

    find $BACKUP_DIR -name .allowed_users -print0 \
        | xargs -0 grep -l $user \
        | while read f; do 
        find "$(dirname "$f")" -maxdepth 2 -name .allowed_users -print0 \
            | xargs -0 grep -L dwpaley
        done | sed -e's@/.allowed_users$@@' > ${user}.no.txt

done

#cat no.txt |sed -e's/^/"/' -e's/$/"/' |tr '\n' ' ' |xargs -n10 -s200000 drive share -no-prompt -emails dwpaley@gmail.com -role reader -type user
