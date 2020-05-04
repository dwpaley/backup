# CNI Labs Backup

This is a basic backup system that was implemented at Columbia Nano Initiative to
backup scientific data collected on computers in the shared labs. It is intended
to run daily. It makes a datestamped incremental backup of any file that was 
changed or deleted since the last run. Utilities are provided for the following:

* Run a backup job at any time: backup_all.sh
* Generate a storage report and send it by email: check_storage.sh
* Purge old backups: purge_old.sh
* Restore a backup to a specified date: rewind.sh

This is intended for recovery from catastrophes: hard drive crashes, ransomware
attacks, etc. It is not really designed for recovering individual files. However,
everything is stored without modification and a dated list of all files is kept
in the individual history directories with the name MANIFEST.txt.

## Disclaimer

I made every effort to write this with safety in mind, but you should not use it
trustingly. Particularly, rewind.sh will overwrite data on the computer you are
rewinding (although it does make a history point first). Test everything locally
before using it on valuable data.

## Configuration

1. Hardware: At Columbia, this is implemented on a rack server running Centos 7
with RAID 10 storage. We used 
[this recipe](https://community.spiceworks.com/topic/2062740-how-to-build-a-36tb-storage-server-for-1588-49-in-less-than-an-hour),
 omitting the adapter for the tape drive.

2. Configuring the computers to be backed up: The backup jobs use rsync with the
connection established by key-based ssh.  In my case the computers to back up 
were mostly Windows 7 machines and I installed Cygwin with openssh, rsync, and 
cygrunsrv. I used port translation to direct ssh connections to the right
machines. Your configuration can be anything that provides the backup server
with key-based ssh access to the computers you will back up.

3. Configuring the backup scripts: 

* Place all files in a convenient directory; I used ~/backup. 
* Modify a few hard-coded file paths: In the backup scripts, a few lines are
labeled `#CHANGE THIS`. They are directory names, file names, and a filesystem
label. Update them to match your system.
* Provide the login information for the computers you will back up: Move the
directory local_data_example to local_data. Edit the file rsync_hosts to provide
the requested information. Place any exclude patterns in files in
local_data/exclude/.
* Place your contact information in local_data/email_list. Not all email servers
will accept email from these scripts, but my personal gmail does.
* Add backup_all.sh to your crontab. I run it daily at 12:01am. I also run
check_storage.sh weekly at 9:00am Mondays.

## Usage

* backup_all.sh and check_storage.sh are intended to call as cron jobs, but you can
run them manually at any time.
* purge_old.sh is an interactive script to delete
old backups; it runs interactively and will prompt before doing anything
permanent.
* rewind.sh is for restoring backups and also runs interactively. It
will generate a list of proposed changes before rewinding to the requested date.
**It is extremely important to read and understand the proposed changes before
you confirm the rewind job.**

## Known issues

* Performance: If you are backing up a huge file system, it will take a while.
My largest individual backup job checks about 5,000,000 file and takes 1 hour.
Most of that time is checking file attributes. I imagine some optimizations are
possible.

* Permissions: This preserves the permissions of all files. If a directory does
not grant user execute permission, the rsync job will fail when it tries to
access that directory. This should never happen, but Cygwin occasionally does
strange things with permissions.

## Contact

Daniel Paley: dwpaley@gmail.com
