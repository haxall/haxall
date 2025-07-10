# -*- coding: utf-8 -*-
#
# Copyright (c) 2021, SkyFoundry LLC
# Licensed under the Academic Free License version 3.0
#
# History:
#   19 Jul 2021  Matthew Giannini  Creation
#

import unittest
import random
import sys
import struct
import datetime
import numpy
from zoneinfo import ZoneInfo

from hxpy.brio import NativeBrioReader
from hxpy.brio import NativeBrioWriter
from hxpy.haystack import *


class TestNativeBrioReader(unittest.TestCase):

    def test_null(self):
        data = bytes([0x00])
        self.assertIsNone(NativeBrioReader(data).read_val())

    def test_marker(self):
        data = bytes([0x01])
        self.assertEqual(NativeBrioReader(data).read_val(), Marker())

    def test_na(self):
        data = bytes([0x02])
        self.assertEqual(NativeBrioReader(data).read_val(), NA())

    def test_remove(self):
        data = bytes([0x03])
        self.assertEqual(NativeBrioReader(data).read_val(), Remove())

    def test_bool(self):
        data = bytes([0x04, 0x05])
        brio = NativeBrioReader(data)
        self.assertFalse(brio.read_val())
        self.assertTrue(brio.read_val())

    def test_numbers(self):
        brio = NativeBrioReader(bytes.fromhex("06000cff00"))
        self.assertEqual(brio.read_val(), 12)

        brio = NativeBrioReader(bytes.fromhex("07075bcd15ff00"))
        self.assertEqual(brio.read_val(), 123_456_789)

        # with a unit
        brio = NativeBrioReader(bytes.fromhex("07075bcd15ff02c2b046"))
        self.assertEqual(brio.read_val(), 123_456_789)

        # float with a unit
        brio = NativeBrioReader(bytes.fromhex("0840fe240c9fbe76c9ff02c2b046"))
        self.assertEqual(brio.read_val(), 123_456.789)

        # boundary tests
        brio = NativeBrioReader(bytes.fromhex("067fffff00"))
        self.assertEqual(brio.read_val(), 0x7fff)

        brio = NativeBrioReader(bytes.fromhex("0700008000ff00"))
        self.assertEqual(brio.read_val(), 0x7fff+1)

        brio = NativeBrioReader(bytes.fromhex("068001ff00"))
        self.assertEqual(brio.read_val(), -32767)

        brio = NativeBrioReader(bytes.fromhex("07ffff8000ff00"))
        self.assertEqual(brio.read_val(), -32768)

        brio = NativeBrioReader(bytes.fromhex("077fffffffff00"))
        self.assertEqual(brio.read_val(), 0x7fff_ffff)

        brio = NativeBrioReader(bytes.fromhex("0841e0000000000000ff00"))
        self.assertEqual(brio.read_val(), 0x8000_0000)

        brio = NativeBrioReader(bytes.fromhex("0780000000ff00"))
        self.assertEqual(brio.read_val(), -2147483648)

        brio = NativeBrioReader(bytes.fromhex("08c1e0000000200000ff00"))
        self.assertEqual(brio.read_val(), -2147483649)

    def test_str(self):
        # empty string
        data = bytes([0x09, 0xff, 0x00])
        brio = NativeBrioReader(data)
        self.assertEqual(brio.read_val(), "")

        # "a"
        data = bytes([0x09, 0xff, 0x01, 0x61])
        brio = NativeBrioReader(data)
        self.assertEqual(brio.read_val(), "a")

        # unicode str surrounded with nulls to test correctly positioned
        # to read next value
        data = bytes.fromhex("0009ff05cebbe1bdb9ceb3cebfcf8200")
        brio = NativeBrioReader(data)
        self.assertIsNone(brio.read_val())
        self.assertEqual(brio.read_val(), "λόγος")
        self.assertIsNone(brio.read_val())

    def test_ref(self):
        # string id Ref("foo", "Foo")
        data = bytes.fromhex("0aff03666f6f03466f6f")
        brio = NativeBrioReader(data)
        self.assertEqual(brio.read_val(), Ref("foo", "Foo"))

        # i8 ref Ref("1deb31b8-7508b187")
        data = bytes.fromhex("0b1deb31b87508b18700")
        brio = NativeBrioReader(data)
        self.assertEqual(brio.read_val(), Ref("1deb31b8-7508b187"))

    def test_date(self):
        data = struct.pack("!b h b b", 0x0d, 2021, 7, 21)
        brio = NativeBrioReader(data)
        self.assertEqual(datetime.date(2021, 7, 21), brio.read_val())

    def test_time(self):
        # midnight
        data = bytes.fromhex("0e00000000")
        brio = NativeBrioReader(data)
        self.assertEqual(datetime.time(0, 0, 0), brio.read_val())

        # 11:59:59.999
        data = bytes.fromhex("0e02932dff")
        brio = NativeBrioReader(data)
        self.assertEqual(datetime.time(11, 59, 59, 999000), brio.read_val())

        # 23:59:59.999
        data = bytes.fromhex("0e05265bff")
        brio = NativeBrioReader(data)
        self.assertEqual(datetime.time(23, 59, 59, 999000), brio.read_val())

    def test_datetime(self):
        new_york = ZoneInfo("America/New_York")
        warsaw = ZoneInfo("Europe/Warsaw")

        # 2015-11-30T12:02:33.378-05:00 New_York
        data = bytes.fromhex("1006f83cbfe7d92c80ff084e65775f596f726b")
        brio = NativeBrioReader(data)
        self.assertEqual(datetime.datetime(2015, 11, 30, 12, 2, 33, 378_000, tzinfo=new_york), brio.read_val())

        # 2015-11-30:T12:03:57-05:00 New_York
        data = bytes.fromhex("0f1def3dfdff084e65775f596f726b")
        brio = NativeBrioReader(data)
        self.assertEqual(datetime.datetime(2015, 11, 30, 12, 3, 57, tzinfo=new_york), brio.read_val())

        # 2015-11-30T12:03:57.000123-05:00 New_York
        data = bytes.fromhex("1006f83cd3601d8278ff084e65775f596f726b")
        brio = NativeBrioReader(data)
        self.assertEqual(datetime.datetime(2015, 11, 30, 12, 3, 57, microsecond=123, tzinfo=new_york), brio.read_val())

        # 2000-01-01T00:00:00+01:00 Warsaw
        data = bytes.fromhex("0ffffff1f0ff06576172736177")
        brio = NativeBrioReader(data)
        self.assertEqual(datetime.datetime(2000, 1, 1, tzinfo=warsaw), brio.read_val())

        # 2000-01-01T00:00:00.832+01:00 Warsaw
        data = bytes.fromhex("10fffffcba00deb000ff06576172736177")
        brio = NativeBrioReader(data)
        self.assertEqual(datetime.datetime(2000, 1, 1, microsecond=832_000, tzinfo=warsaw), brio.read_val())

        # 1999-06-07T01:02:00-04:00 New_York
        data = bytes.fromhex("0ffeee0ec8ff084e65775f596f726b")
        brio = NativeBrioReader(data)
        self.assertEqual(datetime.datetime(1999, 6, 7, 1, 2, tzinfo=new_york), brio.read_val())

        # 1950-06-07T01:02:00-04:00 New_York
        data = bytes.fromhex("0fa2c36148ff084e65775f596f726b")
        brio = NativeBrioReader(data)
        self.assertEqual(datetime.datetime(1950, 6, 7, 1, 2, tzinfo=new_york), brio.read_val())

        # 1950-06-07T01:02:00.123-04:00 New_York
        data = bytes.fromhex("10ea4aa7624f67a4c0ff084e65775f596f726b")
        brio = NativeBrioReader(data)
        self.assertEqual(datetime.datetime(1950, 6, 7, 1, 2, microsecond=123_000, tzinfo=new_york), brio.read_val())

    def test_coord(self):
        data = bytes.fromhex("110a5f07800365c040")
        brio = NativeBrioReader(data)
        self.assertEqual(Coord.from_str("C(84, -123)"), brio.read_val())

    def test_buf(self):
        # <ctrl=13><size=04><buf="foo!">
        data = bytes.fromhex("1304666f6f21")
        brio = NativeBrioReader(data)
        self.assertEqual(bytes.fromhex("666f6f21"), brio.read_val())

    def test_dict(self):
        # empty dict
        data = bytes([0x14])
        brio = NativeBrioReader(data)
        self.assertEqual(brio.read_val(), {})

        # dict ["a": 1, "b": "B"]
        data = bytes.fromhex("157b02ff0161060001ff00ff016209ff01427d")
        brio = NativeBrioReader(data)
        self.assertDictEqual(brio.read_val(), {"a": 1, "b": "B"})

        # nested dict ["a": 1, "nested": ["b":"B"]]
        data = bytes.fromhex("157b02ff0161060001ff00ff066e6573746564157b01ff016209ff01427d7d")
        brio = NativeBrioReader(data)
        self.assertDictEqual(brio.read_val(), {"a": 1, "nested": {"b": "B"}})

    def test_grid(self):
        # empty grid
        data = bytes.fromhex("183c0000143e")
        brio = NativeBrioReader(data)
        self.assertTrue(brio.read_val().is_empty())

        # [[1, 2, 3], [4, 5, 6]]
        data = bytes.fromhex("183c030214ff02763014ff02763114ff02763214060001ff00060002ff00060003ff00060004ff00060005ff00060006ff003e")
        brio = NativeBrioReader(data)
        g = brio.read_val()
        self.assertEqual(2, g.size())
        self.assertEqual(1, g.val(0,0))
        self.assertEqual(6, g.val(1,2))

    def test_ndarray(self):
        # [[1, 2, 3], [4, 5, 6]]
        # test round-tripping an ndarray
        data = bytes.fromhex("157b04ff0172060002ff00ff0163060003ff00ff05627974657313303ff000000000000040000000000000004008000000000000401000000000000040140000000000004018000000000000ff076e646172726179017d")
        brio = NativeBrioReader(data)
        self.assertTrue(numpy.array_equal(numpy.array([[1, 2, 3], [4, 5, 6]], ">d"), brio.read_val()))

    def test_list(self):
        # empty list
        data = bytes([0x16])
        brio = NativeBrioReader(data)
        self.assertListEqual(brio.read_val(), [])

        # list with values [1,2]
        data = bytes.fromhex("175b02060001ff00060002ff005d")
        brio = NativeBrioReader(data)
        self.assertListEqual(brio.read_val(), [1, 2])

        # list of dict [{"a":1}, {"b":2}]
        data = bytes.fromhex("175b02157b01ff0161060001ff007d157b01ff0162060002ff007d5d")
        brio = NativeBrioReader(data)
        self.assertEqual(brio.read_val(), [{"a": 1}, {"b": 2}])

    def test_varint(self):
        # Explicit checks along boundaries:
        # - 0xxx: one byte (0 to 127)
        # - 10xx: two bytes (128 to 16_383)
        # - 110x: four bytes (16_384 to 536_870_911)
        # - 1110: nine bytes (536_870_912 .. Int.maxVal)
        vals  = [-1, 0, 30, 64, 127, 128, 1000, 16_383, 16_384, 500_123, 536_870_911, 536_870_912, 123_456_789_123]
        sizes = [1,  1,  1,  1,   1,   2,    2,      2,      4,       4,           4,           9,               9]

        buf = bytearray()
        for i, val in enumerate(vals):
            old_size = len(buf)
            buf.extend(NativeBrioWriter.to_varint_bytes(val))
            new_size = len(buf)
            self.assertEqual(new_size - old_size, sizes[i])

        r = NativeBrioReader(buf)
        for i, val in enumerate(vals):
            x = r._decode_varint()
            self.assertEqual(val, x)

        bound_a = 127
        bound_b = 16_383
        bound_c = 536_870_911
        vals.clear()
        for i in range(10_000):
            j = random.choice(range(8))
            if j == 0:
                vals.append(random.choice(range(0, bound_a)))
            elif j == 1:
                vals.append(random.choice(range(bound_a, bound_b)))
            elif j == 2:
                vals.append(random.choice(range(bound_b, bound_c)))
            elif j == 3:
                vals.append(random.choice(range(bound_a-10, bound_a+10)))
            elif j == 4:
                vals.append(random.choice(range(bound_b-10, bound_b+10)))
            elif j == 5:
                vals.append(random.choice(range(bound_c-20, bound_c+20)))
            elif j == 6:
                vals.append(-1)
            else:
                vals.append(random.choice(range(0, sys.maxsize)))
        # for

        buf = bytearray()
        for v in vals:
            buf.extend(NativeBrioWriter.to_varint_bytes(v))
        r = NativeBrioReader(buf)
        for i, v in enumerate(vals):
            x = r._decode_varint()
            self.assertEqual(v, x)


# TestNativeBrioReader
