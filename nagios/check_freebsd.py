#!/usr/local/bin/python
# SPDX-License-Identifier: BSD-2-Clause
#
# Copyright (c) 2024 Steven Stallion <sstallion@gmail.com>
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

FREEBSD_UPDATE_BIN = '/usr/sbin/freebsd-update'

if __name__ == '__main__':
    parser = argparse.ArgumentParser(
        prog='check_freebsd.py',
        description='This plugin tests FreeBSD update status')

    parser.add_argument(
        '--jail', '-j', metavar='jailname',
        help='check jail instead of the main system')

    args = parser.parse_args()
    try:
        run_args = [FREEBSD_UPDATE_BIN]
        if args.jail is not None:
            run_args.extend(['-j', args.jail])
        run_args.append('updatesready')

        proc = subprocess.run(run_args, stdout=subprocess.PIPE, text=True)
        stdout = proc.stdout.strip()
        if proc.returncode == 0:
            raise Exception(stdout)
        print('FREEBSD OK - %s' % stdout)

    except Exception as e:
        print('FREEBSD CRITICAL - %s' % e)
        sys.exit(2)

    sys.exit(0)
