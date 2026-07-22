//
// Copyright (c) 2026, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   22 Jul 2026  Brian Frank  Creation
//

using xeto

**
** AGen models the @Gen facet on a type or slot declaration
**
internal const class AGen
{
  new make(Int line, Str? raw, Dict meta)
  {
    this.line = line
    this.raw  = raw
    this.meta = meta
  }

  const Int line      // zero based line of the @Gen facet
  const Str? raw      // raw meta string from source or null
  const Dict meta     // raw parsed as xeto dict

  override Str toStr() { raw == null ? "@Gen" : "@Gen {$raw}" }
}

