//
// Copyright (c) 2026, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   22 Jul 2026  Brian Frank  Creation
//

**
** AFlags models the declaration modifiers for a type or slot
**
internal const class AFlags
{
  static const AFlags none := AFlags {}

  new make(|This|? f := null) { if (f != null) f(this) }

  const Bool isAbstract    // abstract class or slot
  const Bool isConst       // const class/mixin
  const Bool isEnum        // enum class
  const Bool isMixin       // mixin (not class)
  const Bool isOverride    // slot override keyword
  const Bool isStatic      // slot static keyword

  override Str toStr()
  {
    s := StrBuf()
    if (isAbstract) s.join("abstract", ",")
    if (isConst)    s.join("const", ",")
    if (isEnum)     s.join("enum", ",")
    if (isMixin)    s.join("mixin", ",")
    if (isOverride) s.join("override", ",")
    if (isStatic)   s.join("static", ",")
    return s.toStr
  }
}

