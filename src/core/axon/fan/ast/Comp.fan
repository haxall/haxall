//
// Copyright (c) 2019, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   28 Jun 2019  Brian Frank  Creation
//

**
** Comp is an instance of CompDef. See `docSkySpark::Comps`.
**
@Js
mixin Comp
{
  ** Definition of the component
  abstract CompDef def()

  ** Get a cell value by name or raise error if not a valid cell
  @Operator abstract Obj? get(Str name)

  ** Set a cell value by name or raise error if not a valid cell
  @Operator abstract This set(Str name, Obj? val)

  ** Get a cell value by its cell definition
  abstract Obj? getCell(CellDef cd)

  ** Set a cell value by its cell definition
  abstract This setCell(CellDef cd, Obj? val)

  ** Recompute cells
  abstract This recompute(AxonContext cx)

  ** Return list of current cell values
  @NoDoc abstract Obj?[] cellVals()

  ** Debug dump
  @NoDoc abstract Void dump(OutStream out := Env.cur.out)
}