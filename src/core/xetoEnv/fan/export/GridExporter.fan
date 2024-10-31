//
// Copyright (c) 2024, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   30 Oct 2024  Brian Frank  Creation
//

using xeto
using xeto::Lib
using haystack
using haystack::Dict
using haystack::Ref

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
    if (filetype.name == "trio")
      add(lib.meta)
    else
      meta = lib.meta

    lib.specs.each |x| { spec(x) }

    lib.instances.each |x| { instance(x) }

    return this
  }

  override This spec(Spec spec)
  {
    add(specToDict(spec))
    return this
  }

  private Dict specToDict(Spec x)
  {
    meta := isEffective ? x.meta : x.metaOwn
    slots := isEffective ? x.slots : x.slotsOwn

    acc := Str:Obj[:]
    acc.ordered = true
    acc["id"] = x._id
    if (x.isType) acc.addNotNull("base", x.base?._id)
    else acc["type"] = x.type._id
    acc["spec"] = specRef
    meta.each |v, n| { acc[n] = v }

    if (!slots.isEmpty)
    {
      slotsAcc := Str:Obj[:]
      slotsAcc.ordered = true
      slots.each |slot|
      {
        slotsAcc[slot.name] = specToDict(slot)
      }
      acc["slots"] = Etc.dictFromMap(slotsAcc)
    }

    return Etc.makeDict(acc)
  }

  override This instance(Dict instance)
  {
    // turn nested instances with an id to refs
    dict := instance.map |v|
    {
      nestedId := (v as Dict)?.get("id") as Ref
      if (nestedId != null && ns.instance(nestedId.id, false) != null)
        return nestedId
      return v
    }
    add(dict)
    return this
  }

//////////////////////////////////////////////////////////////////////////
// Definitions
//////////////////////////////////////////////////////////////////////////

  private Void add(Dict x)
  {
    dicts.add(x)
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

