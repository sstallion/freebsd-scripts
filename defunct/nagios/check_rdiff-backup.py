#!/usr/local/bin/python
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
import os
import subprocess
import sys

RDIFF_BACKUP_SH = '/var/scripts/backup/rdiff-backup.sh'


def get_changed_since(name, time):
    args = [RDIFF_BACKUP_SH, name, 'list', time]
    return subprocess.check_output(args, text=True).strip()


if __name__ == '__main__':
    parser = argparse.ArgumentParser(
        prog='check_backup.py',
        description='This plugin tests the rdiff-backup script')

    parser.add_argument('name',
        help='the configuration name to check for changes')

    parser.add_argument('time',
        help='the duration of time to check for changes')

    parser.add_argument(
        '--critical', '-c', metavar='INTEGER',
        nargs='?', type=int, default=0,
        help='number of changes for critical status (default: 0)')

    parser.add_argument(
        '--warning', '-w', metavar='INTEGER',
        nargs='?', type=int, default=0,
        help='number of changes for warning status (default: 0)')

    args = parser.parse_args()
    try:
        changes = get_changed_since(args.name, args.time)
        num_changes = len(changes.split('\n'))

        if num_changes <= args.critical:
            status = 'CRITICAL'
        elif num_changes <= args.warning:
            status = 'WARNING'
        else:
            status = 'OK'

        print('RDIFF-BACKUP %s - %d changes to %s since %s' %
            (status, num_changes, args.name, args.time))

        if status == 'WARNING':
            sys.exit(1)
        if status == 'CRITICAL':
            sys.exit(2)

    except Exception as e:
        print('RDIFF-BACKUP UNKNOWN - %s' % e)
        sys.exit(3)

    sys.exit(0)
