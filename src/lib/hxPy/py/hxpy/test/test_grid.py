# -*- coding: utf-8 -*-
#
# Copyright (c) 2021, SkyFoundry LLC
# Licensed under the Academic Free License version 3.0
#
# History:
#   13 Dec 2021  Matthew Giannini  Creation
#
import datetime
import unittest
import io
import pytz

from hxpy.haystack import Grid, GridBuilder
from hxpy.brio import *


class TestGrid(unittest.TestCase):

    def test_to_dataframe(self):
        g = GridBuilder().add_col_names(["a", "b", "c"]).add_row([1, 2, 3]).to_grid()
        self.assertEqual(g.col_names(), ["a", "b", "c"])
        f = g.to_dataframe()
        self.assertEqual(f.columns.values.tolist(), ["a", "b", "c"])
        self.assertEqual(f.values.tolist()[0], [1, 2, 3])

        g2 = Grid.from_dataframe(f)
        self.assertEqual(g2.col_names(), ["a","b","c"])
        self.assertEqual(g2.rows()[0].cells(), [1, 2, 3])

    def test_add_col_meta(self):
        gb = GridBuilder().add_col_names(["a", "b", "c"])
        self.assertEqual(gb.to_grid().col("a").meta(), {})

        gb.set_col_meta("a", {"foo":"bar"})
        self.assertEqual(gb.to_grid().col("a").meta(), {"foo":"bar"})

        gb.add_row([1,2,3])
        gb.set_col_meta("b", {"on":True})
        self.assertEqual(gb.to_grid().col("a").meta(), {"foo":"bar"})
        self.assertEqual(gb.to_grid().col("b").meta(), {"on":True})

    def test_dataframe_ts_roundtrip(self):
        # his grid with ts, and v0 column (one row)
        new_york = pytz.timezone("America/New_York")
        data = bytes.fromhex("183c0201157b05ff047669657709ff056368617274ff0868697353746172740f259ee3d0ff084e65775f596f726bff06686973456e640f25a03550ff084e65775f596f726bff086869734c696d6974062710ff00ff0364697309ff0e57656420312d4a616e2d323032307dff027473157b03ff066469734b657909ff0d75693a3a74696d657374616d70ff02747a09ff084e65775f596f726bff0b6368617274466f726d617409ff026b617dff027630157b14ff0363757201ff036d6f6410096885aa8e43c440ff03555443ff02747a09ff084e65775f596f726bff0963757253746174757309ff026f6bff05706f696e7401ff09726567696f6e5265660aff1f703a64656d6f53636865643a723a32383638383631372d35613239303632370d57617368696e67746f6e204443ff0368697301ff0663757256616c08408975999999999aff036b5768ff086469734d6163726f09ff1224657175697052656620246e61764e616d65ff0b686973496e74657276616c06000fff036d696eff076e61764e616d6509ff036b5768ff0865717569705265660aff1f703a64656d6f53636865643a723a32383638383631372d35643132333562641f47616974686572736275726720456c65634d657465722d4c69676874696e67ff0269640aff1f703a64656d6f53636865643a723a32383638383631372d61386366333532312347616974686572736275726720456c65634d657465722d4c69676874696e67206b5768ff0768697346756e6309ff0e656c65634b77546f4b7768486973ff06656e6572677901ff046b696e6409ff064e756d626572ff07736974655265660aff1f703a64656d6f53636865643a723a32383638383631372d35356532373131320c476169746865727362757267ff04756e697409ff036b5768ff0673656e736f7201ff076869734d6f646509ff0b636f6e73756d7074696f6e7d0f259ee3d0ff084e65775f596f726b084047a00000000000ff036b57683e")
        grid = NativeBrioReader(data).read_val()
        ts = datetime.datetime(2020, 1, 1, 0, 0, 0).astimezone(new_york)
        col = grid.col("ts")
        self.assertEqual(ts, grid.first().val(col))
        with io.BytesIO() as f:
            # roundtrip the grid as a dataframe and ensure timestamp is same
            brio = NativeBrioWriter(f).write_val(grid.to_dataframe())
            hex = ''.join(format(x, '02x') for x in bytes(f.getbuffer()))
            grid = NativeBrioReader(bytes.fromhex(hex)).read_val()
            self.assertEqual(ts, grid.first().val(col))


# TestGrid
