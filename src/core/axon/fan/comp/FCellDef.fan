//
// Copyright (c) 2019, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   27 Jun 2019  Brian Frank  Creation
//

using concurrent
using haystack

**
** Cell facet to apply to AbstractComp slots
**
@Js
facet class Cell : Define
{
  ** Meta data for the cell encoded as a Trio string
  const Obj? meta

  ** Decode into meta tag name/value pairs
  @NoDoc override Void decode(|Str,Obj| f)
  {
    if (meta != null)
    {
      TrioReader(meta.toStr.in).readDict.each |v, n| { f(n, v) }
    }
  }
}

**************************************************************************
** FCellDef
**************************************************************************

**
** CellDef implementation for Fantom components
**
@Js
internal const class FCellDef : WrapDict, CellDef
{
  new make(FCompDef parent, Int index, Field field, Cell facet)
    : super(toMeta(field, facet))
  {
    this.parent  = parent
    this.index   = index
    this.name    = field.name
    this.field   = field
    this.ro      = MCellDef.isReadonly(wrapped)
  }

  private static Dict toMeta(Field field, Cell facet)
  {
    acc := Str:Obj?[:]
    facet.decode |n, v| { acc[n] = v }
    return Etc.makeDict(acc)
  }

  override const FCompDef parent
  const override Int index
  const override Str name
  const Field field
  const Bool ro

  override Str toStr()
  {
    s := StrBuf()
    s.add(name).add(": ").add(super.toStr)
    return s.toStr
  }

  Obj? getCell(AbstractComp comp)
  {
    field.get(comp)
  }

  Void setCell(AbstractComp comp, Obj? val)
  {
    if (ro) throw ReadonlyErr("Cannot set readonly cell: $name")
    field.set(comp, val)
  }
}

