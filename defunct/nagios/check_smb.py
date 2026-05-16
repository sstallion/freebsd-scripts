#!/usr/local/bin/python
# SPDX-License-Identifier: BSD-2-Clause
#
# Copyright (c) 2019 Steven Stallion <sstallion@gmail.com>
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

SMBCLIENT_BIN = '/usr/local/bin/smbclient'


def get_smb_services(hostname):
    args = [SMBCLIENT_BIN, '-L', hostname, '-N']
    return subprocess.check_output(args, text=True).strip()


if __name__ == '__main__':
    parser = argparse.ArgumentParser(
        prog='check_smb.py',
        description='This plugin uses the smbclient program to obtain the '
                    'list of services available for the given host.')

    parser.add_argument(
        '--hostname', '-H', metavar='HOST',
        type=str, default=None, required=True,
        help='the host name you want to query')

    args = parser.parse_args()
    try:
        services = get_smb_services(args.hostname)
        print('SMB OK - %s' % services)

    except Exception as e:
        print('SMB UNKNOWN - %s' % e)
        sys.exit(3)

    sys.exit(0)
