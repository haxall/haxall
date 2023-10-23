# -*- coding: utf-8 -*-
#
# Copyright (c) 2021, SkyFoundry LLC
# Licensed under the Academic Free License version 3.0
#
# History:
#   20 Jul 2021  Matthew Giannini  Creation
#

import io
import struct
import datetime
import numpy

from functools import reduce

import pandas.core.frame

from .control import BrioControl
from ..brio import NativeBrioReader
from ..haystack import *

BRIO_WRITE_MAP = {
    type(None): "_write_null",
    Marker: "_write_marker",
    NA: "_write_na",
    Remove: "_write_remove",
    bool: "_write_bool",
    int: "_write_int",
    numpy.int64: "_write_int",
    numpy.int32: "_write_int",
    numpy.int8: "_write_int",
    numpy.int16: "_write_int",
    numpy.uint64: "_write_int",
    numpy.uint32: "_write_int",
    numpy.uint8: "_write_int",
    numpy.uint16: "_write_int",
    float: "_write_float",
    str: "_write_str",
    Ref: "_write_ref",
    datetime.date: "_write_date",
    datetime.time: "_write_time",
    datetime.datetime: "_write_datetime",
    pandas.Timestamp: "_write_pandas_timestamp",
    bytes: "_write_bytes",
    dict: "_write_dict",
    list: "_write_list",
    Grid: "_write_grid",
    numpy.ndarray: "_write_ndarray",
    pandas.core.frame.DataFrame: "_write_dataframe"
}


class NativeBrioWriter:
    """Serialize native python types to Haystack BRIO encoding"""

    @staticmethod
    def to_bytes(val):
        with io.BytesIO() as f:
            NativeBrioWriter(f).write_val(val)
            return bytes(f.getbuffer())

    def __init__(self, file):
        self._file = file
        self.strict = False

    def close(self):
        self._file.close()

    def write_val(self, val):
        try:
            val_type = type(val)
            return getattr(self, BRIO_WRITE_MAP[val_type])(val)
        except AttributeError:
            if self.strict:
                raise IOError(f'Cannot encode {val} [{type(val)}]')
            return self._write_str(str(val))
    
    ##########################################################
    # Encode
    ##########################################################

    def _write_null(self, _=None):
        self._file.write(bytes([BrioControl.ctrlNull]))
        return self

    def _write_marker(self, _=None):
        self._file.write(bytes([BrioControl.ctrlMarker]))
        return self

    def _write_na(self, _=None):
        self._file.write(bytes([BrioControl.ctrlNA]))
        return self

    def _write_remove(self, _=None):
        self._file.write(bytes([BrioControl.ctrlRemove]))
        return self

    def _write_bool(self, val):
        ctrl = BrioControl.ctrlTrue if val else BrioControl.ctrlFalse
        return self._u1(ctrl)

    def _write_int(self, val, unit=None):
        unit = "" if not unit else unit
        if -32_767 <= val <= 32_767:
            self._u1(BrioControl.ctrlNumI2)
            self._file.write(struct.pack("!h", val))
            return self._encode_str(unit)
        elif -2_147_483_648 <= val <= 2_147_483_647:
            self._u1(BrioControl.ctrlNumI4)
            self._file.write(struct.pack("!i", val))
            return self._encode_str(unit)
        else:
            return self._write_float(val, unit)

    def _write_float(self, val, unit=None):
        unit = "" if not unit else unit
        self._u1(BrioControl.ctrlNumF8)
        self._file.write(struct.pack("!d", val))
        return self._encode_str(unit)

    def _write_str(self, val):
        self._u1(BrioControl.ctrlStr)
        return self._encode_str(val)

    def _write_ref(self, val):
        # encode id
        i8 = self._ref_to_i8(val)
        if i8 >= 0:
            self._u1(BrioControl.ctrlRefI8)
            self._file.write(struct.pack("!q", i8))
        else:
            self._u1(BrioControl.ctrlRefStr)
            self._encode_str(val.id())

        # dis
        dis = val.dis()
        if not dis:
            dis = ""
        self._encode_str_chars(dis)
        return self

    def _ref_to_i8(self, val):
        try:
            # 1deb31b8-7508b187
            id = val.id()
            if len(id) != 17 or id[8] != '-':
                return -1
            i8 = 0
            for i in range(17):
                if i == 8:
                    continue
                i8 = (i8 << 4) | (int(id[i], 16))
            return i8
        except:
            return -1

    def _write_date(self, val):
        self._u1(BrioControl.ctrlDate)
        return self._u2(val.year)._u1(val.month)._u1(val.day)

    def _write_time(self, val):
        self._u1(BrioControl.ctrlTime)
        h = val.hour * (1000 * 60 * 60)
        m = val.minute * (1000 * 60)
        s = val.second * 1000
        millis = val.microsecond / 1000
        self._file.write(struct.pack("!I", int(h + m + s + millis)))
        return self

    def _write_datetime(self, val):
        sec = 1000000000
        ticks = ((val - NativeBrioReader.epoch) / datetime.timedelta(microseconds=1)) * 1000

        # get timezone name
        tzname = val.tzinfo.zone # e.g. America/New_York
        idx = tzname.find("/")
        if idx != -1:
            tzname = tzname[idx+1:]

        if ticks % sec == 0:
            self._u1(BrioControl.ctrlDateTimeI4)
            self._file.write(struct.pack("!l", int(ticks / sec)))
            self._encode_str(tzname)
        else:
            self._u1(BrioControl.ctrlDateTimeI8)
            self._file.write(struct.pack("!q", int(ticks)))
            self._encode_str(tzname)
        return self

    def _write_pandas_timestamp(self, val):
        val = val.to_pydatetime()
        return self._write_datetime(val)

    def _write_bytes(self, val):
        self._u1(BrioControl.ctrlBuf)
        self._encode_varint(len(val))
        self._file.write(val)
        return self

    def _write_dict(self, val):
        if not val:
            return self._u1(BrioControl.ctrlDictEmpty)

        self._u1(BrioControl.ctrlDict)
        self._u1(ord('{'))

        # count non-null tags
        count = reduce(lambda acc, x: acc if x is None else acc + 1, val.values(), 0)
        self._encode_varint(count)

        # write tag name/value pairs
        for (k, v) in val.items():
            if not (v is None):
                self._encode_str(k)
                self.write_val(v)

        return self._u1(ord('}'))

    def _write_list(self, val):
        if not val:
            return self._u1(BrioControl.ctrlListEmpty)

        self._u1(BrioControl.ctrlList)
        self._u1(ord('['))
        self._encode_varint(len(val))
        for item in val:
            self.write_val(item)
        return self._u1(ord(']'))

    def _write_grid(self, grid):
        self._u1(BrioControl.ctrlGrid)
        self._u1(ord('<'))
        cols = grid.cols()
        self._encode_varint(len(cols))
        self._encode_varint(grid.size())

        self._write_dict(grid.meta())
        for col in cols:
            self._encode_str(col.name())
            self._write_dict(col.meta())
        for row in grid.rows():
            for col in cols:
                self.write_val(row.val(col))
        self._u1(ord('>'))
        return self

    def _write_ndarray(self, val):
        # special support for writing an ndarray as a special dict
        shape = val.shape
        if len(shape) == 1:
            shape = (shape[0], 1)
        elif len(shape) != 2:
            raise IOError(f"Cannot encode ndarray with shape {shape}")
        spec = {
            "ndarray": Marker(),
            "r": shape[0],
            "c": shape[1],
            "bytes": val.astype(numpy.dtype(">d")).ravel().tobytes()
        }
        return self._write_dict(spec)

    def _write_dataframe(self, frame):
        self._u1(BrioControl.ctrlGrid)
        self._u1(ord('<'))
        cols = frame.columns
        self._encode_varint(len(cols))
        self._encode_varint(len(frame.index))

        self._write_dict({})
        for idx, col in enumerate(cols):
            if type(col) != str:
                col = f"v{col}"
            self._encode_str(col)
            self._write_dict({})
        for idx, row in frame.iterrows():
            for col in cols:
                v = row[col]
                self.write_val(row[col])

        self._u1(ord('>'))
        return self

    def _u1(self, byte):
        self._file.write(bytes([byte]))
        return self

    def _u2(self, val):
        self._file.write(struct.pack("!h", val))
        return self

    def _encode_str(self, val):
        self._encode_varint(-1)
        self._encode_str_chars(val)
        return self

    def _encode_str_chars(self, val):
        self._encode_varint(len(val))
        self._file.write(val.encode("utf-8"))
        return self

    def _encode_varint(self, val):
        self._file.write(NativeBrioWriter.to_varint_bytes(val))
        return self

    @staticmethod
    def to_varint_bytes(val):
        if val < 0:
            return bytes([0xff])
        elif val <= 0x7f:
            return struct.pack("!B", val)
        elif val <= 0x3fff:
            return struct.pack("!H", val | 0x8000)
        elif val <= 0x1fff_ffff:
            return struct.pack("!L", val | 0xc000_0000)
        else:
            return struct.pack("!B Q", 0xe0, val)

# NativeBrioWriter
