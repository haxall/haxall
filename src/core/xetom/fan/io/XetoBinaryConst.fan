//
// Copyright (c) 2023, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   8 Aug 2023  Brian Frank  Creation
//

using concurrent
using util
using xeto

**
** Xeto binary constants
**
@Js
mixin XetoBinaryConst
{
  static const Int magicLib      := 0x6c69627b   // lib{
  static const Int magicLibEnd   := 0x7d6c6962   // }lib
  static const Int magicLibVer   := 0x7265673a   // reg:
  static const Int specOwnOnly   := ';'          // encoding own meta/slots only
  static const Int specInherited := '+'          // encoding inherited too (for and/or)

  static const Int ctrlNull          := 1
  static const Int ctrlMarker        := 2
  static const Int ctrlNA            := 3
  static const Int ctrlNone          := 4
  static const Int ctrlTrue          := 5
  static const Int ctrlFalse         := 6
  static const Int ctrlStrConst      := 7
  static const Int ctrlStrNew        := 8
  static const Int ctrlStrPrev       := 9
  static const Int ctrlNumberNoUnit  := 10
  static const Int ctrlNumberUnit    := 11
  static const Int ctrlInt2          := 12
  static const Int ctrlInt8          := 13
  static const Int ctrlFloat8        := 14
  static const Int ctrlDuration      := 15
  static const Int ctrlRef           := 16
  static const Int ctrlUri           := 17
  static const Int ctrlDate          := 18
  static const Int ctrlTime          := 19
  static const Int ctrlDateTime      := 20
  static const Int ctrlBuf           := 21
  static const Int ctrlGenericScalar := 22
  static const Int ctrlTypedScalar   := 23
  static const Int ctrlEmptyDict     := 24
  static const Int ctrlNameDict      := 25
  static const Int ctrlGenericDict   := 26
  static const Int ctrlTypedDict     := 27
  static const Int ctrlSpecRef       := 28
  static const Int ctrlList          := 29
  static const Int ctrlGrid          := 30
  static const Int ctrlSpan          := 31
  static const Int ctrlVersion       := 32
  static const Int ctrlCoord         := 33
}

