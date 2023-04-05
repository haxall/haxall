# -*- coding: utf-8 -*-
#
# Copyright (c) 2021, SkyFoundry LLC
# Licensed under the Academic Free License version 3.0
#
# History:
#   19 Jul 2021  Matthew Giannini  Creation
#

import datetime
import struct
import io
import codecs
import zoneinfo
import pytz

from .control import BrioControl
from ..haystack import *


# >>> numpy.ndarray((2,2), numpy.dtype(">d"), data)

class NativeBrioReader:
    """Read BRIO to native Python types (not Haystack)"""

    """Haystack epoch is midnight on 2000-01-01 UTC"""
    epoch = datetime.datetime(2000, 1, 1, tzinfo=pytz.timezone("UTC"))

    def __init__(self, data):
        self._data = data
        self._pos = 0
        self._intern_strs = {}
        self._intern_tzs = {}

    def avail(self):
        size = len(self._data)
        return size - self._pos if (self._pos <= size) else 0

    def read_dict(self):
        v = self.read_val()
        if type(v) is dict:
            return v
        else:
            raise IOError(f'Expected Dict, not {type(v)}')

    def read_val(self):
        ctrl = self._u1()
        if ctrl == BrioControl.ctrlNull:
            return None
        elif ctrl == BrioControl.ctrlMarker:
            return Marker()
        elif ctrl == BrioControl.ctrlNA:
            return NA()
        elif ctrl == BrioControl.ctrlRemove:
            return Remove()
        elif ctrl == BrioControl.ctrlFalse:
            return False
        elif ctrl == BrioControl.ctrlTrue:
            return True
        elif ctrl == BrioControl.ctrlNumI2:
            return self._consume_numi2()[0]
        elif ctrl == BrioControl.ctrlNumI4:
            return self._consume_numi4()[0]
        elif ctrl == BrioControl.ctrlNumF8:
            return self._consume_numf8()[0]
        elif ctrl == BrioControl.ctrlRefStr:
            return self._consume_ref_str()
        elif ctrl == BrioControl.ctrlRefI8:
            return self._consume_refi8()
        elif ctrl == BrioControl.ctrlStr:
            return self._consume_str()
        elif ctrl == BrioControl.ctrlUri:
            return self._consume_uri()
        elif ctrl == BrioControl.ctrlDate:
            return self._consume_date()
        elif ctrl == BrioControl.ctrlTime:
            return self._consume_time()
        elif ctrl == BrioControl.ctrlDateTimeI4:
            return self._consume_datetimei4()
        elif ctrl == BrioControl.ctrlDateTimeI8:
            return self._consume_datetimei8()
        elif ctrl == BrioControl.ctrlCoord:
            return self._consume_coord();
        elif ctrl == BrioControl.ctrlBuf:
            return self._consume_buf()
        elif ctrl == BrioControl.ctrlDictEmpty:
            return {}
        elif ctrl == BrioControl.ctrlDict:
            return self._consume_dict()
        elif ctrl == BrioControl.ctrlListEmpty:
            return []
        elif ctrl == BrioControl.ctrlList:
            return self._consume_list()
        elif ctrl == BrioControl.ctrlGrid:
            return self._consume_grid()
        else:
            raise NotImplementedError(f'Unsupported data type: {hex(ctrl)} pos={self._pos}')

    ##########################################################
    # Decode
    ##########################################################

    def _u1(self, expect=None):
        byte = self._data[self._pos]
        self._pos = self._pos + 1
        if expect and byte != ord(expect):
            raise IOError(f"Unexpected byte: {hex(byte)} {chr(byte)} != {hex(ord(expect))} {expect}")
        return byte

    def _u2(self):
        return struct.unpack("!H", self._consume(2))[0]

    def _consume_numi2(self):
        val, = struct.unpack("!h", self._consume(2))
        unit = self._consume_unit()
        return val, unit

    def _consume_numi4(self):
        val, = struct.unpack("!i", self._consume(4))
        unit = self._consume_unit()
        return val, unit

    def _consume_ref_str(self):
        id = self._decode_str(False)
        dis = self._decode_str_chars(False)
        return Ref(id, dis)

    def _consume_refi8(self):
        handle, = struct.unpack("!q", self._consume(8))
        dis = self._decode_str_chars(False)
        return Ref(Ref.make_handle(handle).id(), dis)

    def _consume_numf8(self):
        val, = struct.unpack("!d", self._consume(8))
        unit = self._consume_unit()
        return val, unit

    def _consume_unit(self):
        s = self._decode_str(False)
        if not s:
            return None
        return s

    def _consume_str(self):
        return self._intern_str(self._decode_str(True))

    def _consume_uri(self):
        return self._decode_str(False)

    def _consume_date(self):
        return datetime.date(*struct.unpack("!h b b", self._consume(4)))

    def _consume_time(self):
        millis, = struct.unpack("!I", self._consume(4))
        h = int((millis / (1000 * 60 * 60)) % 24)
        m = int((millis / (1000 * 60)) % 60)
        s = int((millis / 1000) % 60)
        ms = millis % 1000
        return datetime.time(h, m, s, ms * 1000)

    def _consume_datetimei4(self):
        secs, = struct.unpack("!l", self._consume(4))
        tz = self._consume_timezone()
        delta = datetime.timedelta(seconds=secs)
        return (NativeBrioReader.epoch + delta).astimezone(tz)

    def _consume_datetimei8(self):
        nanos, = struct.unpack("!q", self._consume(8))
        tz = self._consume_timezone()
        delta = datetime.timedelta(microseconds=nanos/1000)
        return (NativeBrioReader.epoch + delta).astimezone(tz)

    def _consume_timezone(self):
        name = self._decode_str(False)
        tz = self._intern_tzs.get(name)
        if not tz:
            # BRIO uses only timezone name, not full name so need to try
            # and find it
            for avail in zoneinfo.available_timezones():
                if avail == name or avail.endswith(f'/{name}'):
                    self._intern_tzs[name] = tz = pytz.timezone(avail)
                    break
        if not tz:
            raise RuntimeError(f'Timezone not found: {name}')
        return tz

    def _consume_coord(self):
        bits, = struct.unpack("!q", self._consume(8))
        return Coord.unpack(bits)

    def _consume_buf(self):
        size = self._decode_varint()
        return self._consume(size)

    def _consume_dict(self):
        self._u1('{')
        count = self._decode_varint()
        acc = {}
        for i in range(count):
            tag = self._decode_str(True)
            val = self.read_val()
            acc[tag] = val
        self._u1('}')

        # check for ndarray
        if acc.get("ndarray") == Marker():
            return self._decode_ndarray(acc)

        return acc

    def _consume_list(self):
        self._u1('[')
        size = self._decode_varint()
        acc = [None] * size
        for i in range(size):
            val = self.read_val()
            acc[i] = val
        self._u1(']')
        return acc

    def _consume_grid(self):
        self._u1('<')
        num_cols = self._decode_varint()
        num_rows = self._decode_varint()

        gb = GridBuilder()
        gb.set_meta(self.read_dict())
        for c in range(0, num_cols):
            gb.add_col(self._decode_str(True), self.read_dict())

        for r in range(0, num_rows):
            cells = []
            for c in range(0, num_cols):
                cells.append(self.read_val())
            gb.add_row(cells)

        self._u1('>')
        return gb.to_grid()

    def _consume(self, n):
        if self._pos + n > len(self._data):
            raise RuntimeError(f'{n} bytes not available: {self.avail()}')
        consumed = self._data[self._pos:self._pos + n]
        self._pos = self._pos + n
        return consumed

    def _decode_str(self, intern):
        code = self._decode_varint()
        if code >= 0:
            raise RuntimeError(f'Constant pool not supported: {code}')
        return self._decode_str_chars(intern)

    def _decode_str_chars(self, intern):
        # the size is the number of utf-8 characters, *not* the length
        # of the string.
        size = self._decode_varint()
        pos = self._pos
        # Get a file-ish view of a portion of the data containing the str
        file = io.BytesIO(self._data[pos:pos + (size * 4)])
        # create a reader that can read utf-8 data and read size chars into a str
        c = codecs.getreader("utf-8")(file)
        s = ''.join([c.read(1) for _ in range(size)])
        # advance our pos by the number of actual bytes we read
        self._pos = self._pos + c.tell()

        if intern:
            s = self._intern_str(s)
        # this all seemed harder than it should have been
        return s

    def _decode_varint(self):
        v = self._u1()
        if v == 0xff:
            return -1
        elif (v & 0x80) == 0:
            return v
        elif (v & 0xc0) == 0x80:
            return ((v & 0x3f) << 8) | self._u1()
        elif (v & 0xe0) == 0xc0:
            return ((((v & 0x1f) << 8) | self._u1()) << 16) | self._u2()
        else:
            return struct.unpack("!q", self._consume(8))[0]

    def _intern_str(self, v):
        i = self._intern_strs.get(v)
        if not i:
            self._intern_strs[v] = i = v
        return i

    def _decode_ndarray(self, spec):
        import numpy
        rows = spec["r"]
        cols = spec["c"]
        buf = spec["bytes"]
        return numpy.ndarray((rows, cols), dtype=">d", buffer=buf)

# NativeBrioReader
