//
// Copyright (c) 2019, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   27 Jun 2019  Brian Frank  Creation
//

using concurrent
using xeto
using haystack

**
** CellDef implementation
**
@Js
internal const class MCellDef : WrapDict, CellDef
{
  new make(AtomicRef parentRef, Int index, Str name, Dict meta)
    : super(meta)
  {
    this.parentRef  = parentRef
    this.index   = index
    this.name    = name
    this.defVal  = meta["defVal"]
    this.ro      = isReadonly(meta)
  }

  internal static Bool isReadonly(Dict meta)
  {
    meta.has("ro") || meta.has("bindOut")
  }

  override MCompDef parent() { parentRef.val }
  private const AtomicRef parentRef
  const override Int index
  const override Str name
  const Obj? defVal
  const Bool ro

  override Str toStr()
  {
    s := StrBuf()
    s.add(name).add(": ").add(super.toStr)
    return s.toStr
  }
}

