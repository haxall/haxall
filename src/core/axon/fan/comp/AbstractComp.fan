//
// Copyright (c) 2019, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   26 Jul 2019  Brian Frank  Creation
//

**
** AbstractComp is base class for Fantom components.
** See `docHaxall::Comps#fantom`.
**
@Js
abstract class AbstractComp : Comp
{
  ** Reflect the given type
  static CompDef reflect(Type type)
  {
    return FCompDef(type, type.name.decapitalize)
  }

  ** All components must implement single arg constructor
  new make(Obj init) { this.defRef = init }

  ** Get the definition
  override final CompDef def() { defRef }
  internal const FCompDef defRef

  ** Get a cell value by name or raise error if not a valid cell
  @Operator override final Obj? get(Str name)
  {
    getCell(def.cell(name))
  }

  ** Set a cell value by name or raise error if not a valid cell
  @Operator override final This set(Str name, Obj? val)
  {
    setCell(def.cell(name), val)
  }

  ** Get a cell value by its cell definition
  override final Obj? getCell(CellDef cd)
  {
    ((FCellDef)cd).getCell(this)
  }

  ** Set a cell value by its cell definition
  override final This setCell(CellDef cd, Obj? val)
  {
    ((FCellDef)cd).setCell(this, val)
    return this
  }

  ** Recompute the component's cells
  override final This recompute(AxonContext cx)
  {
    onRecompute(cx)
    return this
  }

  ** Callback to recompute the cells
  protected abstract Void onRecompute(AxonContext cx)

  ** Debug string
  override final Str toStr() { "Comp<${def.name}>" }

  ** Return list of current cell values
  @NoDoc override final Obj?[] cellVals()
  {
    def.cells.map |cell| { getCell(cell) }
  }

  ** Debug dump
  @NoDoc override final Void dump(OutStream out := Env.cur.out) { MComp.doDump(this, out) }
}

