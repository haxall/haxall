//
// Copyright (c) 2024, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   30 Oct 2024  Brian Frank  Creation
//

using xeto
using xeto::Lib
using haystack::Dict
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
    if (filetype.name == "trio")
      add(lib.meta)
    else
      meta = lib.meta

    lib.specs.each |x| { addSpec(x) }

    lib.instances.each |x| { add(x) }

    return this
  }

  override This spec(Spec spec)
  {
    addSpec(spec)
    return this
  }

  override This instance(Dict instance)
  {
    add(instance)
  }

//////////////////////////////////////////////////////////////////////////
// Definitions
//////////////////////////////////////////////////////////////////////////

  private This addSpec(Spec x)
  {
    add((Dict)x)
  }

  private This add(Dict x)
  {
    dicts.add(x)
    return this
  }

  private Grid toGrid()
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

