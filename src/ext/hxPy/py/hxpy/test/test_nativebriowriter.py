# -*- coding: utf-8 -*-
#
# Copyright (c) 2021, SkyFoundry LLC
# Licensed under the Academic Free License version 3.0
#
# History:
#   21 Jul 2021  Matthew Giannini  Creation
#

import unittest
import io
import datetime
import struct
import numpy
import pandas
import pytz

from hxpy.brio import NativeBrioWriter
from hxpy.brio import NativeBrioReader
from hxpy.haystack import *


class TestNativeBrioWriter(unittest.TestCase):

    def test_null(self):
        with io.BytesIO() as f:
            NativeBrioWriter(f).write_val(None)
            self.assertEqual(bytes(f.getbuffer()), bytes([0x00]))

    def test_marker(self):
        with io.BytesIO() as f:
            NativeBrioWriter(f).write_val(Marker())
            self.assertEqual(bytes(f.getbuffer()), bytes([0x01]))

    def test_na(self):
        with io.BytesIO() as f:
            NativeBrioWriter(f).write_val(NA())
            self.assertEqual(bytes(f.getbuffer()), bytes([0x02]))

    def test_remove(self):
        with io.BytesIO() as f:
            NativeBrioWriter(f).write_val(Remove())
            self.assertEqual(bytes(f.getbuffer()), bytes([0x03]))

    def test_bool(self):
        with io.BytesIO() as f:
            NativeBrioWriter(f).write_val(True).write_val(False)
            self.assertEqual(bytes(f.getbuffer()), bytes([0x05, 0x04]))

    def test_numbers(self):
        with io.BytesIO() as f:

            def b():
                return bytes(f.getbuffer())[pos:]

            pos = 0
            brio = NativeBrioWriter(f).write_val(12)
            self.assertEqual(bytes.fromhex("06000cff00"), b())

            pos = f.tell()
            brio.write_val(123_456_789)
            self.assertEqual(bytes.fromhex("07075bcd15ff00"), b())

            pos = f.tell()
            brio.write_val(123_456.789)
            self.assertEqual(bytes.fromhex("0840fe240c9fbe76c9ff00"), b())

            # boundary tests
            pos = f.tell()
            brio.write_val(0x7fff)
            self.assertEqual(bytes.fromhex("067fffff00"), b())

            pos = f.tell()
            brio.write_val(0x7fff+1)
            self.assertEqual(bytes.fromhex("0700008000ff00"), b())

            pos = f.tell()
            brio.write_val(-32767)
            self.assertEqual(bytes.fromhex("068001ff00"), b())

            pos = f.tell()
            brio.write_val(-32768)
            self.assertEqual(bytes.fromhex("07ffff8000ff00"), b())

            pos = f.tell()
            brio.write_val(0x7fff_ffff)
            self.assertEqual(bytes.fromhex("077fffffffff00"), b())

            pos = f.tell()
            brio.write_val(0x8000_0000)
            self.assertEqual(bytes.fromhex("0841e0000000000000ff00"), b())

            pos = f.tell()
            brio.write_val(-2147483648)
            self.assertEqual(bytes.fromhex("0780000000ff00"), b())

            pos = f.tell()
            brio.write_val(-2147483649)
            self.assertEqual(bytes.fromhex("08c1e0000000200000ff00"), b())

    def test_str(self):
        with io.BytesIO() as f:
            # empty string
            brio = NativeBrioWriter(f).write_val("")
            self.assertEqual(bytes.fromhex("09ff00"), bytes(f.getbuffer()))

            # "a"
            f.seek(0)
            brio.write_val("a")
            self.assertEqual(bytes.fromhex("09ff0161"), bytes(f.getbuffer()))

            # unicode
            f.seek(0)
            brio.write_val("λόγος")
            self.assertEqual(bytes.fromhex("09ff05cebbe1bdb9ceb3cebfcf82"), bytes(f.getbuffer()))

    def test_ref(self):
        with io.BytesIO() as f:
            brio = NativeBrioWriter(f).write_val(Ref("foo", "Foo"))
            self.assertEqual(bytes.fromhex("0aff03666f6f03466f6f"), bytes(f.getbuffer()))
        with io.BytesIO() as f:
            brio = NativeBrioWriter(f).write_val(Ref("1deb31b8-7508b187"))
            self.assertEqual(bytes.fromhex("0b1deb31b87508b18700"), bytes(f.getbuffer()))

    def test_date(self):
        with io.BytesIO() as f:
            NativeBrioWriter(f).write_val(datetime.date(2021, 7, 21))
            self.assertEqual(struct.pack("!b h b b", 0x0d, 2021, 7, 21), bytes(f.getbuffer()))

    def test_time(self):
        with io.BytesIO() as f:
            NativeBrioWriter(f).write_val(datetime.time(0, 0, 0))
            self.assertEqual(bytes.fromhex("0e00000000"), bytes(f.getbuffer()))

            f.seek(0)
            NativeBrioWriter(f).write_val(datetime.time(11, 59, 59, 999000))
            self.assertEqual(bytes.fromhex("0e02932dff"), bytes(f.getbuffer()))

            f.seek(0)
            NativeBrioWriter(f).write_val(datetime.time(23, 59, 59, 999000))
            self.assertEqual(bytes.fromhex("0e05265bff"), bytes(f.getbuffer()))

    def test_datetime(self):
        new_york = pytz.timezone("America/New_York")
        with io.BytesIO() as f:
            NativeBrioWriter(f).write_val(datetime.datetime(2015, 11, 30 , 12, 3, 57).astimezone(new_york))
            self.assertEqual(bytes.fromhex("0f1def3dfdff084e65775f596f726b"), bytes(f.getbuffer()))

        with io.BytesIO() as f:
            NativeBrioWriter(f).write_val(datetime.datetime(2015, 11, 30, 12, 2, 33 , 378_000).astimezone(new_york))
            self.assertEqual(bytes.fromhex("1006f83cbfe7d92c80ff084e65775f596f726b"), f.getbuffer())

    # def test_coord(self):
    #     with io.BytesIO() as f:
    #         NativeBrioWriter(f).write_val(Coord.from_str("C(84,-123)"))
    #         self.assertEqual(bytes.fromhex("110a5f07800365c040"), f.getbuffer())

    def test_dict(self):
        with io.BytesIO() as f:
            # empty dict
            brio = NativeBrioWriter(f).write_val({})
            self.assertEqual(bytes([0x14]), bytes(f.getbuffer()))

            # dict
            f.seek(0)
            brio.write_val({"a": 1, "b": "B"})
            self.assertEqual(bytes.fromhex("157b02ff0161060001ff00ff016209ff01427d"), bytes(f.getbuffer()))

            # nested dict
            f.seek(0)
            brio.write_val({"a": 1, "nested": {"b": "B"}})
            self.assertEqual(bytes.fromhex("157b02ff0161060001ff00ff066e6573746564157b01ff016209ff01427d7d"), bytes(f.getbuffer()))

    def test_ndarray(self):
        with io.BytesIO() as f:
            arr = numpy.array([[1,2,3], [4,5,6]], ">d")
            brio = NativeBrioWriter(f).write_val(arr)
            decoded = NativeBrioReader(bytes(f.getbuffer())).read_val()
            self.assertTrue(numpy.array_equal(arr, decoded))
            # expect = bytes.fromhex("157b04ff0172060002ff00ff0163060003ff00ff05627974657313303ff000000000000040000000000000004008000000000000401000000000000040140000000000004018000000000000ff076e646172726179017d")
            # self.assertEqual(expect, bytes(f.getbuffer()))

    def test_list(self):
        with io.BytesIO() as f:
            # empty list
            brio = NativeBrioWriter(f).write_val([])
            self.assertEqual(bytes([0x16]), bytes(f.getbuffer()))

            # list with values
            f.seek(0)
            brio.write_val([1,2])
            self.assertEqual(bytes.fromhex("175b02060001ff00060002ff005d"), bytes(f.getbuffer()))

            # list of dict
            f.seek(0)
            brio.write_val([{"a": 1}, {"b": 2}])
            self.assertEqual(bytes.fromhex("175b02157b01ff0161060001ff007d157b01ff0162060002ff007d5d"), bytes(f.getbuffer()))

    def test_grid(self):
        with io.BytesIO() as f:
            # empty grid
            brio = NativeBrioWriter(f).write_val(Grid.empty_grid())
            self.assertEqual(bytes.fromhex("183c0000143e"), bytes(f.getbuffer()))

            # test empty panda DataFrame
            f.seek(0)
            frame = pandas.DataFrame()
            brio.write_val(frame)
            self.assertEqual(bytes.fromhex("183c0000143e"), bytes(f.getbuffer()))

            # v0  v1  v2
            #  1   2   3
            #  4   5   6
            f.seek(0)
            gb = GridBuilder()
            gb.add_col_names(["v0", "v1", "v2"])
            gb.add_row([1,2,3])
            gb.add_row([4,5,6])
            g = gb.to_grid()
            brio.write_val(g)
            self.assertEqual(bytes.fromhex("183c030214ff02763014ff02763114ff02763214060001ff00060002ff00060003ff00060004ff00060005ff00060006ff003e"), bytes(f.getbuffer()))

            # test panda DataFrame equivalent to above
            f.seek(0)
            # frame = pandas.DataFrame(data=[[1,2,3], [4,5,6]], columns=["v0","v1","v2"])
            frame = pandas.DataFrame(data=[[1,2,3], [4,5,6]])
            brio.write_val(frame)
            self.assertEqual(bytes.fromhex("183c030214ff02763014ff02763114ff02763214060001ff00060002ff00060003ff00060004ff00060005ff00060006ff003e"), bytes(f.getbuffer()))


# TestNativeBrioWriter
