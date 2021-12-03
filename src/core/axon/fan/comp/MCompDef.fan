//
// Copyright (c) 2019, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   26 Jun 2019  Brian Frank  Creation
//

using concurrent
using haystack

**
** CompDef implementation
**
@Js
internal const class MCompDef : CompDef
{
  new make(Loc loc, Str name, Dict meta, Expr body, CellDef[] cells, Str:CellDef cellsMap)
    : super(loc, name, meta, body)
  {
    this.cells = cells
    this.cellsMap = cellsMap
  }

  override const MCellDef[] cells

  override Int size() { cells.size }


  override MCellDef? cell(Str name, Bool checked := true)
  {
    cell := cellsMap[name]
    if (cell != null) return cell
    if (checked) throw UnknownCellErr("${this.name}.${name}")
    return null
  }

  override Comp instantiate()
  {
    MComp(this)
  }

  private const Str:MCellDef cellsMap
}