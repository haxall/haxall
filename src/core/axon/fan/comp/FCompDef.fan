//
// Copyright (c) 2019, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   26 Jul 2019  Brian Frank  Creation
//

using concurrent
using xeto
using haystack
using axon::Comp

**
** FCompDef is CompDef for Fantom comps which subclass AbstractComp
**
@Js
internal const class FCompDef : CompDef
{
  new make(Type type, Str name, Dict meta)
    : super(Loc(type.qname), name, meta, Literal.nullVal)
  {
    list := FCellDef[,]
    map := Str:FCellDef[:]

    type.fields.each |field|
    {
      facet := field.facet(Cell#, false)
      if (facet == null) return

      cd := FCellDef(this, list.size, field, facet)
      list.add(cd)
      map.add(cd.name, cd)
    }

    this.compType = type
    this.cells = list
    this.cellsMap = map
  }

  const Type compType

  override const FCellDef[] cells

  override Int size() { cells.size }

  override FCellDef? cell(Str name, Bool checked := true)
  {
    cell := cellsMap[name]
    if (cell != null) return cell
    if (checked) throw UnknownCellErr("${this.name}.${name}")
    return null
  }

  override Comp instantiate() { compType.make([this]) }

  private const Str:FCellDef cellsMap
}

