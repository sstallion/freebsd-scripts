#!/bin/sh
# SPDX-License-Identifier: BSD-2-Clause
#
# Copyright (c) 2025 Steven Stallion <sstallion@gmail.com>
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

readonly EFLOCK=127	# Backup still in progress

. /usr/local/etc/zfs-autobackup.conf

namevar()
{
	local _name=$(echo $name | sed -e 's/[^A-z0-9_]/_/g')
	for var; do
		eval $var=\$${_name}$var
		eval val=\$$var
		if [ -z "$val" ]; then
			eval $var=\$default$var
		fi
	done
}

setvars()
{
	lockfile=$(printf "/var/run/zfs-autobackup-%s.lock" $name)
	logfile=$(printf "/var/log/backups/zfs-autobackup-%s.log" $name)

	namevar _flags _target_path \
		_ssh_config _ssh_source _ssh_target \
		_schedule _source_schedule target_schedule \
		_property_format _snapshot_format _hold_format

	if [ -n "${_ssh_config}" ]; then
		_flags="$_flags --ssh-config=${_ssh_config}"
	fi

	if [ -n "${_ssh_source}" ]; then
		_flags="$_flags --ssh-source=${_ssh_source}"
	fi

	if [ -n "${_ssh_target}" ]; then
		_flags="$_flags --ssh-target=${_ssh_target}"
	fi

	: ${_source_schedule:=${_schedule}}
	if [ -n "${_source_schedule}" ]; then
		_flags="$_flags --keep-source=${_source_schedule}"
	fi

	: ${_target_schedule:=${_schedule}}
	if [ -n "${_target_schedule}" ]; then
		_flags="$_flags --keep-target=${_target_schedule}"
	fi

	if [ -n "${_property_format}" ]; then
		_flags="$_flags --property-format=${_property_format}"
	fi

	if [ -n "${_snapshot_format}" ]; then
		_flags="$_flags --snapshot-format=${_snapshot_format}"
	fi

	if [ -n "${_hold_format}" ]; then
		_flags="$_flags --hold-format=${_hold_format}"
	fi
}

cron()
{
	backup | moreutils-ts >>$logfile
}

list()
{
	local command="zfs list -H -r -o name,creation -S creation -t snapshot $* ${_target_path}"
	(
		if [ -z "${_target_path}" ]; then
			sh -c "${command}"
		else
			ssh $_ssh_target $command
		fi
	) | grep "@${name}-"
}

summary()
{
	list $* | sed 's/.*@\(.*\)$/\1/' | sort -u
}

backup()
{
	flock -E $EFLOCK -n $lockfile zfs-autobackup $_flags $* $name $_target_path
	local _status=$?
	if [ $_status != 0 ]; then
		if [ $_status = $EFLOCK ]; then
			echo 1>&2 "Backup still in progress; check ${logfile}."
		else
			echo 1>&2 "Backup failed with status ${_status}; check ${logfile}."
		fi
		exit $_status
	fi
}

resume()
{
	backup "$@" --no-snapshot
}

usage()
{
	echo 1>&2 "Usage: $(basename $0) name cron|list|summary|backup|resume [flags]"
	exit 1
}

if [ $# -lt 2 ]; then
	usage
fi

name="$1"; shift
setvars

case "$1" in
cron|list|summary|backup|resume)
	eval "$@"
	;;
*)
	usage
	;;
esac
exit 0
