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
  static const Int magic       := 0x78623233   // xb23
  static const Int magicEnd    := 0x78623233   // XB};
  static const Int version     := 0x2023_08
  static const Int magicLib    := 0x6c69627b   // lib{
  static const Int magicLibEnd := 0x7d6c6962   // }lib

  static const Int ctrlNull         := 1
  static const Int ctrlMarker       := 2
  static const Int ctrlNA           := 3
  static const Int ctrlRemove       := 4
  static const Int ctrlTrue         := 5
  static const Int ctrlFalse        := 6
  static const Int ctrlName         := 7
  static const Int ctrlStr          := 8
  static const Int ctrlNumberNoUnit := 9
  static const Int ctrlNumberUnit   := 10
  static const Int ctrlInt2         := 11
  static const Int ctrlInt8         := 12
  static const Int ctrlFloat8       := 13
  static const Int ctrlDuration     := 14
  static const Int ctrlRef          := 15
  static const Int ctrlUri          := 16
  static const Int ctrlDate         := 17
  static const Int ctrlTime         := 18
  static const Int ctrlDateTime     := 19
  static const Int ctrlEmptyDict    := 20
  static const Int ctrlNameDict     := 21
  static const Int ctrlGenericDict  := 22
  static const Int ctrlSpecRef      := 23
  static const Int ctrlList         := 24
  static const Int ctrlGrid         := 25
  static const Int ctrlVersion      := 26
  static const Int ctrlCoord        := 27
  static const Int ctrlSymbol       := 28
}


