# Backup Scripts

The scripts in this directory are intended to be called from `cron(8)` to
provide automated backups on FreeBSD. Two scripts are available to manage file
backups (`rdiff-backup.sh`) and ZFS snapshots and backups (`zfs-autobackup.sh`).

The following dependencies should be installed to use these scripts:
```
# pkg install flock moreutils py39-rdiff-backup py39-zfs-autobackup
```

The following should be added to `/etc/crontab` to schedule backups:
```
SHELL=/bin/sh
PATH=/sbin:/bin:/usr/sbin:/usr/bin:/usr/local/sbin:/usr/local/bin
#
#minute	hour	mday	month	wday	who	command
#
# Backup files after daily/weekly/monthly maintenance.
45	6	*	*	*	root	/var/scripts/backup/rdiff-backup.sh <name> cron
# Snapshot ZFS datasets at midnight.
@daily				root	/var/scripts/backup/zfs-autobackup.sh <name> cron
```

Job output is logged in the `/var/log/backup` directory. To manage log sizes,
`newsyslog(8)` can be configured to rotate logs periodically:
```
/var/log/backup/*.log                   640  4     *    $W0     GJ
```

Scripts are executed as superuser; `zfs-autobackup` supports specifying a
non-default SSH configuration, however `rdiff-backup` does not. As such the
default SSH configuration for root should be used if needed.

Generally speaking, `rdiff-backup.sh` is used to pull backups from hosts on the
network specified in `/usr/local/etc/rdiff-backup.conf`. `zfs-autobackup.sh` is
used to create snapshots and optionally push backups to hosts specified in
`/usr/local/etc/zfs-autobackup.conf`. Variables should be prefixed with the name
of the backup to execute. The default prefix can be used to provide settings for
all backups.

Both scripts can be called manually to perform additional operations such as
resuming and pruning backups as well as listing information about completed
backups.
