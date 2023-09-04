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

  static const Int ctrlMarker      := 0x01
  static const Int ctrlNA          := 0x02
  static const Int ctrlRemove      := 0x03
  static const Int ctrlTrue        := 0x04
  static const Int ctrlFalse       := 0x05
  static const Int ctrlName        := 0x06
  static const Int ctrlStr         := 0x07
  static const Int ctrlRef         := 0x08
  static const Int ctrlUri         := 0x09
  static const Int ctrlDate        := 0x0A
  static const Int ctrlTime        := 0x0B
  static const Int ctrlDateTimeI4  := 0x0C
  static const Int ctrlDateTimeI8  := 0x0D
  static const Int ctrlEmptyDict   := 0x0E
  static const Int ctrlNameDict    := 0x0F
  static const Int ctrlGenericDict := 0x10
  static const Int ctrlSpecRef     := 0x20
}


