//
// Copyright (c) 2024, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   30 Oct 2024  Brian Frank  Creation
//

using xeto
using haystack

**
** GridExporter turns xeto data into Haystack grid then uses
** one of the standard haystack formats for export.
**
@Js
class GridExporter : Exporter
{

//////////////////////////////////////////////////////////////////////////
// Constructor
//////////////////////////////////////////////////////////////////////////

  new make(MNamespace ns, OutStream out, Dict opts, Filetype filetype) : super(ns, out, opts)
  {
    this.filetype = filetype
  }

//////////////////////////////////////////////////////////////////////////
// Export
//////////////////////////////////////////////////////////////////////////

  override This start()
  {
    return this
  }

  override This end()
  {
    grid := toGrid
    filetype.writer(out, opts).writeGrid(grid)
    return this
  }

  override This lib(Lib lib)
  {
    add(libMeta(lib))

    lib.specs.each |x| { spec(x) }

    nonNestedInstances(lib).each |x| { instance(x) }

    return this
  }

  private Dict libMeta(Lib lib)
  {
    Etc.dictRemove(lib, "loaded")
  }

  override This spec(Spec spec)
  {
    add(specToDict(spec, 0))
    return this
  }

  private Dict specToDict(Spec x, Int depth)
  {
    effective := this.isEffective && depth <= 1
    meta := effective ? x.meta : x.metaOwn
    slots := effective ? x.slots : x.slotsOwn

    acc := Str:Obj[:]
    acc.ordered = true
    acc["id"] = x.id
    if (x.isType) acc.addNotNull("base", x.base?.id)
    else acc["type"] = x.type.id
    acc["spec"] = specRef
    meta.each |v, n| { acc[n] = v }

    if (!slots.isEmpty)
    {
      slotsAcc := Str:Obj[:]
      slotsAcc.ordered = true
      slots.each |slot|
      {
        slotsAcc[slot.name] = specToDict(slot, depth+1)
      }
      acc["slots"] = Etc.dictFromMap(slotsAcc)
    }

    return Etc.makeDict(acc)
  }

  override This instance(Dict instance)
  {
    add(instance)
    return this
  }

//////////////////////////////////////////////////////////////////////////
// Definitions
//////////////////////////////////////////////////////////////////////////

  private Void add(Dict x)
  {
    dicts.add(Etc.dictToHaystack(x))
  }

  Grid toGrid()
  {
    Etc.makeDictsGrid(meta, dicts)
  }

//////////////////////////////////////////////////////////////////////////
// Fields
//////////////////////////////////////////////////////////////////////////

  private const Filetype filetype
  private Dict? meta
  private Dict[] dicts := [,]
}

