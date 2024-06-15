#!/usr/bin/env python
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

import argparse
import subprocess
import sys
import time
from datetime import datetime, timedelta

ZFS_AUTOBACKUP_SH = '/var/scripts/backup/zfs-autobackup.sh'


def get_snapshots(name):
    args = [ZFS_AUTOBACKUP_SH, name, 'list', '-Hp']
    stdout = subprocess.check_output(args, text=True)
    if not stdout:
        return None
    return stdout.split('\n')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(
        prog='check_zfs-autobackup.py',
        description='This plugin tests the zfs-autobackup script')

    parser.add_argument('name',
        help='the configuration name to check for changes')

    parser.add_argument(
        '--critical', '-c', metavar='INTEGER',
        nargs='?', type=int, default=14,
        help='number of days for critical status (default: 14)')

    parser.add_argument(
        '--warning', '-w', metavar='INTEGER',
        nargs='?', type=int, default=7,
        help='number of days for warning status (default: 7)')

    args = parser.parse_args()
    try:
        snapshots = get_snapshots(args.name)
        if not snapshots:
            raise ValueError('No snapshots for %s' % args.name)

        name, creation = snapshots[0].split('\t')
        dt = datetime.fromtimestamp(int(time.time())) - \
             datetime.fromtimestamp(int(creation))

        if dt > timedelta(days=args.critical):
            status = 'CRITICAL'
        elif dt > timedelta(days=args.warning):
            status = 'WARNING'
        else:
            status = 'OK'

        print('ZFS-AUTOBACKUP %s - %s since last snapshot for %s' %
              (status, dt, args.name))

        for line in snapshots:
            if line:
                print(line)

        if status == 'WARNING':
            sys.exit(1)
        if status == 'CRITICAL':
            sys.exit(2)

    except Exception as e:
        print('ZFS-AUTOBACKUP UNKNOWN - %s' % e)
        sys.exit(3)

    sys.exit(0)
