#!/bin/sh
# SPDX-License-Identifier: BSD-2-Clause
#
# Copyright (c) 2022 Steven Stallion <sstallion@gmail.com>
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions
# are met:
# 1. Redistributions of source code must retain the above copyright
#    notice, this list of conditions and the following disclaimer.
# 2. Redistributions in binary form must reproduce the above copyright
#    notice, this list of conditions and the following disclaimer in the
#    documentation and/or other materials provided with the distribution.
#
# THIS SOFTWARE IS PROVIDED BY THE AUTHOR AND CONTRIBUTORS "AS IS" AND
# ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
# ARE DISCLAIMED.  IN NO EVENT SHALL THE AUTHOR OR CONTRIBUTORS BE LIABLE
# FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
# DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
# OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
# HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
# LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
# OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
# SUCH DAMAGE.

readonly APIVERSION=201	# See https://rdiff-backup.net/api/
readonly EFLOCK=127	# Backup still in progress

. /usr/local/etc/rdiff-backup.conf

namevar()
{
	for var; do
		eval $var=\$${name}$var
		eval val=\$$var
		if [ -z "$val" ]; then
			eval $var=\$default$var
		fi
	done
}

setvars()
{
	lockfile=$(printf "/var/run/rdiff-backup-%s.lock" $name)
	logfile=$(printf "/var/log/backup/rdiff-backup-%s.log" $name)

	namevar _flags _source _target _files _retention

	if [ -n "${_files}" ]; then
		_flags="$_flags --include-globbing-filelist ${_files}"
	fi
}

run_local()
{
	rdiff-backup $*
}

run_remote()
{
	flock -E $EFLOCK -n $lockfile rdiff-backup --api-version $APIVERSION $*
}

cron()
{
	( backup && prune ) | moreutils-ts >>$logfile
}

list()
{
	_time=${1:-$_retention}
	run_local list files --changed-since $_time $_target
}

backup()
{
	run_remote backup $_flags $* $_source $_target
	_status=$?
	if [ $_status != 0 ]; then
		if [ $_status = $EFLOCK ]; then
			echo 1>&2 "Backup still in progress; check ${logfile}."
		else
			echo 1>&2 "Backup failed with status ${_status}; check ${logfile}."
		fi
		exit $_status
	fi
}

prune()
{
	run_remote remove increments --older-than $_retention $* $_target 2>/dev/null
	_status=$?
	if [ $_status != 0 ]; then
		if [ $_status = $EFLOCK ]; then
			echo 1>&2 "Backup still in progress; check ${logfile}."
		else
			#echo 1>&2 "Prune failed with status ${_status}; check ${logfile}."
			:
		fi
		# TODO: rdiff-backup-2.1.0 now fails irrespective of --force,
		# which causes unnecessary noise in periodic(8). For now, we
		# ignore errors and send stderr to /dev/null until rdiff-backup
		# can restore sanity.
		#exit $_status
		exit 0
	fi
}

regress()
{
	run_remote regress $* $_target
	_status=$?
	if [ $_status != 0 ]; then
		if [ $_status = $EFLOCK ]; then
			echo 1>&2 "Backup still in progress; check ${logfile}."
		else
			echo 1>&2 "Regress failed with status ${_status}; check ${logfile}."
		fi
		exit $_status
	fi
}

usage()
{
	echo 1>&2 "Usage: $(basename $0) name cron|list|backup|prune|regress [flags]"
	exit 1
}

if [ $# -lt 2 ]; then
	usage
fi

name="$1"; shift
setvars

case "$1" in
cron|list|backup|prune|regress)
	eval "$@"
	;;
*)
	usage
	;;
esac
exit 0
