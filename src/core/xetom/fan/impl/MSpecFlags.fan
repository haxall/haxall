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
  static const Int maybe       := 0x0001
  static const Int marker      := 0x0002
  static const Int scalar      := 0x0004
  static const Int ref         := 0x0008
  static const Int multiRef    := 0x0010
  static const Int choice      := 0x0020
  static const Int dict        := 0x0040
  static const Int list        := 0x0080
  static const Int query       := 0x0100
  static const Int func        := 0x0200
  static const Int interface   := 0x0400
  static const Int comp        := 0x0800
  static const Int transient   := 0x1000
  static const Int inheritMask := 0xFFFF

  // non-inherited flags
  static const Int self     := 0x01_0000
  static const Int none     := 0x02_0000
  static const Int global   := 0x04_0000
  static const Int enum     := 0x08_0000  // base is sys::Enum
  static const Int and      := 0x10_0000  // base is sys::And
  static const Int or       := 0x20_0000  // base is sys::Or
  static const Int haystack := 0x40_0000  // maps to Kind/haystack fidelity

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

