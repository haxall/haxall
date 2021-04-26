//
// Copyright (c) 2019, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   28 Jun 2019  Brian Frank  Creation
//

**
** Comp implementation
**
@Js
internal class MComp : Comp
{
  new make(MCompDef def)
  {
    this.def = def
    this.cells = MCell[,]
    this.cells.capacity = def.cells.size
    def.cells.each |x| { this.cells.add(MCell(x)) }
  }

  override const MCompDef def

  @Operator override Obj? get(Str name)
  {
    getCell(def.cell(name))
  }

  @Operator override This set(Str name, Obj? val)
  {
    setCell(def.cell(name), val)
  }

  override Obj? getCell(CellDef cd)
  {
    checkMyCellDef(cd)
    return cells[cd.index].get
  }

  override This setCell(CellDef cd, Obj? val)
  {
    checkMyCellDef(cd)
    cells[cd.index].set(val)
    return this
  }

  override Obj?[] cellVals()
  {
    cells.map |cell| { cell.get }
  }

  override This recompute(AxonContext cx)
  {
    // build variable map
    vars := Str:Obj?[:]
    cells.each |cell| { vars[cell.name] = cell.get }

    // run block
    cx.callInNewFrame(def, Obj#.emptyList, def.loc, vars)

    // set variables back to cells
    cells.each |cell, i| { cell.recomputed(vars[cell.name]) }

    return this
  }

  override Str toStr() { "Comp<${def.name}>" }

  private Void checkMyCellDef(CellDef cd)
  {
    if (def.cells[cd.index] !== cd) throw Err("Not my cell def: $cd")
  }

  override Void dump(OutStream out := Env.cur.out) { doDump(this, out) }
  static Void doDump(Comp comp, OutStream out)
  {
    out.printLine("--- $comp.def.name [$comp] ---")
    comp.def.cells.each |c| { out.print("  ").print(c.name).print(": ").printLine(comp.getCell(c)) }
    out.flush
  }

  private MCell[] cells
}