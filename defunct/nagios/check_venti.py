#!/usr/bin/env python
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
import re
import sys

import requests


def atoi(s):
    return int(s.replace(',', ''))


def get_and_parse(url):
    r = requests.get(url)
    if not r.ok:
        raise ValueError('Unexpected response status: %d' % r.status_code)
    venti = {}
    for line in r.iter_lines(decode_unicode=True):
        for key, value in re.findall(r'([\w\s]+)=([^\s]+)\s?', line):
            venti[key] = value
    return venti


if __name__ == '__main__':
    parser = argparse.ArgumentParser(
        prog='check_venti.py',
        description='This plugin tests the Venti service on the specified host.')

    parser.add_argument(
        '--hostname', '-H', metavar='ADDRESS',
        required=True,
        help='Host name or IP address')

    parser.add_argument(
        '--port', '-p', metavar='INTEGER',
        nargs='?', type=int, default=8000,
        help='Port number (default: 8000)')

    parser.add_argument(
        '--critical', '-c', metavar='INTEGER',
        nargs='?', type=int, default=90,
        help='Percent of used space for critical status (default: 90%%)')

    parser.add_argument(
        '--warning', '-w', metavar='INTEGER',
        nargs='?', type=int, default=80,
        help='Percent of used space for warning status (default: 80%%)')

    args = parser.parse_args()
    try:
        storage = get_and_parse('http://%s:%d/storage' % (args.hostname, args.port))

        usage = 100.0 * atoi(storage['used']) / atoi(storage['total space'])
        if usage >= args.critical:
            status = 'CRITICAL'
        elif usage >= args.warning:
            status = 'WARNING'
        else:
            status = 'OK'

        print('VENTI %s - %s %.1f%% free (total space=%s used=%s data=%s)' % (
            status, storage['index'], 100.0 - usage, # free
            storage['total space'], storage['used'], storage['data']))

        if status == 'WARNING':
            sys.exit(1)
        if status == 'CRITICAL':
            sys.exit(2)

    except Exception as e:
        print('VENTI UNKNOWN - %s' % e)
        sys.exit(3)

    sys.exit(0)
