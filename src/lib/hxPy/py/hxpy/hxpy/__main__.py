# -*- coding: utf-8 -*-
#
# Copyright (c) 2021, SkyFoundry LLC
# Licensed under the Academic Free License version 3.0
#
# History:
#   22 Jul 2021  Matthew Giannini  Creation
#

import argparse
import logging

from .hxpy import HxPy

if __name__ == '__main__':
    # parse args
    parser = argparse.ArgumentParser(description='Haxall Python IPC')
    parser.add_argument('-p', '--port', default="8888", type=int)
    parser.add_argument('--host', default='0.0.0.0')
    parser.add_argument('-k', '--key', required=True)
    parser.add_argument('-t', '--timeout', default="10", type=int)
    parser.add_argument('--level', choices=["WARN", "INFO", "DEBUG"], default="WARN")
    args = parser.parse_args()

    # configure logger
    level = logging.WARNING
    if args.level == "INFO":
        level = logging.INFO
    elif args.level == "DEBUG":
        level = logging.DEBUG
    logging.basicConfig(
        level=level,
        format='%(asctime)s [%(name)s] [%(levelname)s] %(message)s',
        datefmt='%Y-%m-%d %H:%M:%S')
    log = logging.getLogger("hxpy")
    log.setLevel(level)

    # run
    with HxPy((args.host, args.port), args.key, args.timeout, log) as hx:
        hx.run()

    log.info("HxPy exiting")
# main
