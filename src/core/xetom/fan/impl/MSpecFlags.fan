//
// Copyright (c) 2023, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   29 Jan 2023  Brian Frank  Creation
//


@Js
const class MSpecFlags
{
  // inherited flags
  static const Int maybe       := 0x00_0001
  static const Int marker      := 0x00_0002
  static const Int scalar      := 0x00_0004
  static const Int ref         := 0x00_0008
  static const Int multiRef    := 0x00_0010
  static const Int choice      := 0x00_0020
  static const Int dict        := 0x00_0040
  static const Int list        := 0x00_0080
  static const Int grid        := 0x00_0100
  static const Int file        := 0x00_0200
  static const Int query       := 0x00_0400
  static const Int func        := 0x00_0800
  static const Int interface   := 0x00_1000
  static const Int comp        := 0x00_2000
  static const Int entity      := 0x00_4000
  static const Int transient   := 0x00_8000
  static const Int output      := 0x01_0000
  static const Int inheritMask := 0xFF_FFFF

  // non-inherited flags
  static const Int self     := 0x01_00_0000
  static const Int none     := 0x02_00_0000
  static const Int global   := 0x04_00_0000
  static const Int enum     := 0x08_00_0000  // base is sys::Enum
  static const Int and      := 0x10_00_0000  // base is sys::And
  static const Int or       := 0x20_00_0000  // base is sys::Or
  static const Int haystack := 0x40_00_0000  // maps to Kind/haystack fidelity

  static Str flagsToStr(Int flags)
  {
    s := StrBuf()
    MSpecFlags#.fields.each |f|
    {
      if (f.isStatic && f.type == Int# && !f.name.endsWith("Mask"))
      {
        has := flags.and(f.get(null)) != 0
        if (has) s.join(f.name, ",")
      }
    }
    return "{" + s.toStr + "}"
  }
}

