//
// Copyright (c) 2026, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   3 Aug 2026  Brian Frank  Creation
//

using util

**************************************************************************
** XetoFidelity
**************************************************************************

** Data fidelity and type erasure level
@Js
enum class XetoFidelity
{
  full,
  haystack,
  json

  Bool isFull() { this === full }

  Bool isHaystack() { this === haystack }

  ** Coerce value to the proper level of data fidelity
  Obj? coerce(Obj? x)
  {
    if (this === haystack) return XetoUtil.toHaystack(x)
    if (this === json) throw Err("JSON fidelity not supported yet")
    return x
  }
}

**************************************************************************
** JsonBoxMode
**************************************************************************

** Control how xeto scalars are box in Xeto JSON encoding:
**   - none: never box
**   - auto: box only when reader cannot infer from spec
**   - all: always box every scalar
@Js
enum class JsonBoxMode
{
  none,
  auto,
  all

  Bool isNone() { this === none }

  Bool isAuto() { this === auto }

  Bool isAll() { this === all }
}

