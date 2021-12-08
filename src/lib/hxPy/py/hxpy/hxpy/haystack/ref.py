# -*- coding: utf-8 -*-
#
# Copyright (c) 2021, SkyFoundry LLC
# Licensed under the Academic Free License version 3.0
#
# History:
#   07 Dec 2021  Matthew Giannini  Creation
#

class Ref:
    @staticmethod
    def make_handle(handle):
        time = (handle >> 32) & 0xffff_ffff
        rand = handle & 0xffff_ffff
        return Ref(f"{format(time, '08x')}-{format(rand, '08x')}")

    def __init__(self, id, dis=None):
        self._id = id
        self._dis = dis

    def id(self):
        return self._id

    def dis(self):
        return self._dis

    def __str__(self):
        return f'{self.id()}'

    def __eq__(self, other):
        if isinstance(other, Ref):
            return self.id() == other.id()
        return False

# Ref
