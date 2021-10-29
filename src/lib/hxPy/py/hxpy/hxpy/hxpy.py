# -*- coding: utf-8 -*-
#
# Copyright (c) 2021, SkyFoundry LLC
# Licensed under the Academic Free License version 3.0
#
# History:
#   23 Jul 2021  Matthew Giannini  Creation
#

import socket
import struct
from . import brio
from .haystack import Marker


class HxPy:
    """HxPy"""

    def __init__(self, address, api_key, timeout, log):
        self._address = address
        self._api_key = api_key
        self._timeout = timeout
        self._log = log

    def __enter__(self):
        self._log.debug(f'Listen on {self._address} with key {self._api_key}')
        self._listener = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        self._listener.settimeout(self._timeout)
        self._listener.bind(self._address)
        self._listener.listen()
        (self._socket, addr) = self._listener.accept()
        self._log.debug(f'Accepted connection')
        return self

    def __exit__(self, type, value, traceback):
        self._socket.close()
        self._listener.close()

    ##########################################################
    # Run
    ##########################################################

    def run(self):
        log = self._log

        # handle auth packet
        auth = self._recv_brio()
        log.debug(f'Auth {auth}')
        if auth["key"] != self._api_key:
            raise IOError("Invalid api key")
        self._send_brio({"ok": Marker()})

        # handle instructions
        local_vars = {}
        instrs = self._recv_brio()
        while instrs:
            for instr in instrs:
                log.debug(f'process {instr}')
                if "def" in instr:
                    self._define(instr, local_vars)
                if "exec" in instr:
                    self._exec(instr, local_vars)
                elif "eval" in instr:
                    result = self._eval(instr, local_vars)
                    self._send_brio(result)
                    log.debug(f'eval => {result}')
            # for
            instrs = self._recv_brio()
        # while

    ##########################################################
    # Instructions
    ##########################################################

    def _define(self, instr, local_vars):
        name = instr["def"]
        val = instr.get("v")
        local_vars[name] = val

    def _exec(self, instr, local_vars):
        code = instr["exec"]
        return exec(code, local_vars, local_vars)

    def _eval(self, instr, local_vars):
        expr = instr["eval"]
        return eval(expr, local_vars, local_vars)

    ##########################################################
    # IO Util
    ##########################################################

    def _recv_brio(self):
        frame = self._recv_frame()
        if not frame:
            return None
        val = brio.NativeBrioReader(frame).read_val()
        return val

    def _recv_frame(self):
        lenbuf = self._recvall(4)
        if not lenbuf:
            return None
            # raise IOError('No frame data received. Remote server closed the connection')
        frame_len, = struct.unpack('!I', lenbuf)
        return self._recvall(frame_len)

    def _recvall(self, count):
        buf = bytearray()
        while count:
            newbuf = self._socket.recv(count)
            if not newbuf:
                return None
            buf.extend(newbuf)
            count -= len(newbuf)
        return bytes(buf)

    def _send_brio(self, val):
        frame = brio.NativeBrioWriter.to_bytes(val)
        self._socket.sendall(frame)

# HxPy
