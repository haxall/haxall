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
** CompDef data flow component definition
**
@Js
const abstract class CompDef : Fn
{

//////////////////////////////////////////////////////////////////////////
// Construction
//////////////////////////////////////////////////////////////////////////

  ** Constructor
  @NoDoc new make(Loc loc, Str name, Expr body) : super(loc, name, FnParam.cells, body) {}

//////////////////////////////////////////////////////////////////////////
// Abstract methods
//////////////////////////////////////////////////////////////////////////

  ** Return compdef as type
  @NoDoc override ExprType type() { ExprType.compdef }

  ** Number of cells
  @NoDoc abstract Int size()

  ** List data cells for component
  abstract CellDef[] cells()

  ** Lookup a cell by name or raise UnknownCellErr
  abstract CellDef? cell(Str name, Bool checked := true)

  ** Create instance of this component definition
  abstract Comp instantiate()

//////////////////////////////////////////////////////////////////////////
// Fn overrides
//////////////////////////////////////////////////////////////////////////

  ** Return true
  @NoDoc override final Bool isComp() { true }

  ** Return true because we process our own parameters
  @NoDoc override final Bool isNative() { true }

  ** Call the comp def as a function
  @NoDoc override final Obj? callx(AxonContext cx, Obj?[] args, Loc loc)
  {
    // new instance
    comp := instantiate

    // map Dict arg to cell
    if (args.size > 0)
    {
      arg := args[0] as Dict ?: throw ArgErr("Must call comp with Dict arg")
      arg.each |v, n|
      {
        cell := cell(n, false)
        if (cell != null) comp.setCell(cell, v)
      }
    }

    // compute
    comp.recompute(cx)

    // return all cells as Dict
    result := Str:Obj?[:]
    cells.each |cell|
    {
      v := comp.getCell(cell)
      if (v != null) result[cell.name] = v
    }
    return Etc.makeDict(result)
  }

  @NoDoc override Void walk(|Str key, Obj? val| f)
  {
    super.walk(f)
    cellsMap := Str:Dict[:]
    cells.each |cell| { cellsMap[cell.name] = cell }
    f("cells", Etc.makeDict(cellsMap))
  }

  @NoDoc override final Printer print(Printer out)
  {
    out.w("defcomp").nl
    out.indent
    cells.each |cell| { out.w(cell.name).w(": ").val(cell).nl }
    body.print(out)
    out.unindent
    out.w("end").nl
    return out
  }

  ** Debug dump
  @NoDoc Void dump(OutStream out := Env.cur.out)
  {
    out.printLine("--- $name ---")
    cells.each |cell| { out.print("  ").printLine(cell) }
    out.flush
  }


}