# -*- coding: utf-8 -*-
#
# Copyright (c) 2021, SkyFoundry LLC
# Licensed under the Academic Free License version 3.0
#
# History:
#   19 Jul 2021  Matthew Giannini  Creation
#

class BrioControl:
    """Defines binary control constants for brio"""

    ctrlNull = 0x00
    ctrlMarker = 0x01
    ctrlNA = 0x02
    ctrlRemove = 0x03
    ctrlFalse = 0x04
    ctrlTrue = 0x05
    ctrlNumI2 = 0x06
    ctrlNumI4 = 0x07
    ctrlNumF8 = 0x08
    ctrlStr = 0x09
    ctrlRefStr = 0x0a
    ctrlRefI8 = 0x0b
    ctrlUri = 0x0c
    ctrlDate = 0x0d
    ctrlTime = 0x0e
    ctrlDateTimeI4 = 0x0f # secs
    ctrlDateTimeI8 = 0x10 # ns
    ctrlCoord = 0x11
    ctrlXStr = 0x12
    ctrlBuf = 0x13
    ctrlDictEmpty = 0x14
    ctrlDict = 0x15
    ctrlListEmpty = 0x16
    ctrlList = 0x17
    ctrlGrid = 0x18
    ctrlSymbol = 0x19

# BrioControl
