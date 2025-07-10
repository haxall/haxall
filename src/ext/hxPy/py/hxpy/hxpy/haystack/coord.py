# -*- coding: utf-8 -*-
#
# Copyright (c) 2023, SkyFoundry LLC
# Licensed under the Academic Free License version 3.0
#
# History:
#   05 Apr 2023  Matthew Giannini  Creation
#

class Coord:
    def __init__(self, ulat, ulng):
        if ulat < -90_000_000 or ulat > 90_000_000:
            raise RuntimeError(f'Invalid lat > +/- 90: {ulat}')
        if ulng < -180_000_000 or ulng > 180_000_000:
            raise RuntimeError(f'Invalid lng > +/- 180: {ulng}')
        self._ulat = ulat
        self._ulng = ulng

    @staticmethod
    def from_str(s, checked=True):
        try:
            if (not s.startswith('C(')) or (not s.endswith(')')):
                raise RuntimeError()
            comma = s.index(',')
            return Coord(int(s[2:comma]) * 1_000_000, int(s[comma+1:-1]) * 1_000_000)
        except RuntimeError:
            pass
        if checked:
            raise RuntimeError(f'Invalid Coord str: {s}')
        return None

    @staticmethod
    def _makeu(ulat, ulng):
        return Coord(ulat, ulng)

    @staticmethod
    def unpack(bits):
        return Coord(((bits >> 32) & 0xffff_ffff) - 90_000_000,
                     (bits & 0xffff_ffff) - 180_000_000)

    def __eq__(self, other):
        if isinstance(other, Coord):
            return (self._ulat == other._ulat) and (self._ulng == other._ulng)
        return False

    def __str__(self):
        return f'C({self._u_to_str(self._ulat)},{self._u_to_str(self._ulng)})'

    def _u_to_str(self, ud):
        s = ""
        if ud < 0:
            s += '-'
            ud = -ud
        if ud < 1_000_000:
            s += ud / 1_000_000
            return s
        return "TODO"


# Coord
