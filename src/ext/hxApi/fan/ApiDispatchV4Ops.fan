//
// Copyright (c) 2026, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   29 Jul 2026  Brian Frank  Creation
//

using xeto
using haystack
using axon
using hx
using web

abstract class ApiDispatchV4Op : ApiDispatchV4
{
  static const Str:Type specials := [
    "read":      ApiDispatchV4Read#,
    "defs":      ApiDispatchV4Defs#,
    "filetypes": ApiDispatchV4Filetypes#,
    "libs":      ApiDispatchV4Libs#,
    "ops":       ApiDispatchV4Ops#,
  ]

  new make(ApiPipeline p) : super(p) {}

  ** These adapters service the legacy op themselves rather than calling the
  ** func, so they always take the request grid whole no matter what params
  ** the func declares
  override Bool funcTakesReqGrid() { true }

  override Obj? call(Obj?[] args) { doCall(args[0]) }

  abstract Grid doCall(Grid req)
}

**************************************************************************
** Read
**************************************************************************

class ApiDispatchV4Read : ApiDispatchV4Op
{
  new make(ApiPipeline p) : super(p) {}

  override Grid doCall(Grid req)
  {
    if (req.isEmpty) throw Err("Request grid is empty")

    if (req.has("filter"))
    {
      reqRow := req.first
      filter := Filter.fromStr(reqRow->filter)
      opts   := reqRow
      return cx.db.readAll(filter, opts)
    }

    if (req.has("id"))
    {
      return cx.db.readByIds(req.ids, false)
    }

    throw Err("Request grid missing id or filter col")
  }
}

**************************************************************************
** Defs
**************************************************************************

internal class ApiDispatchV4Defs : ApiDispatchV4Op
{
  new make(ApiPipeline p) : super(p) {}

  override Grid doCall(Grid req)
  {
    opts := req.first as Dict ?: Etc.dict0
    limit := (opts["limit"] as Number)?.toInt ?: Int.maxVal
    filter := Filter.fromStr(opts["filter"] as Str ?: "", false)
    acc := Def[,]
    incomplete := false
    eachDef(cx) |def|
    {
      if (filter != null && !filter.matches(def, cx)) return
      if (acc.size >= limit) { incomplete = true; return }
      acc.add(def)
    }
    meta := incomplete ? Etc.dict2("incomplete", Marker.val, "limit", Number(limit)) : Etc.dict0
    return Etc.makeDictsGrid(meta, acc)
  }

  virtual Void eachDef(Context cx, |Def| f) { cx.defs.eachDef(f) }
}

**************************************************************************
** Filetypes
**************************************************************************

internal class ApiDispatchV4Filetypes : ApiDispatchV4Defs
{
  new make(ApiPipeline p) : super(p) {}

  override Void eachDef(Context cx, |Def| f) { cx.defs.feature("filetype").eachDef(f) }
}

**************************************************************************
** Libs
**************************************************************************

internal class ApiDispatchV4Libs: ApiDispatchV4Defs
{
  new make(ApiPipeline p) : super(p) {}

  override Void eachDef(Context cx, |Def| f) { cx.defs.libsList.each(f) }
}

**************************************************************************
** Ops
**************************************************************************

internal class ApiDispatchV4Ops: ApiDispatchV4Defs
{
  new make(ApiPipeline p) : super(p) {}

  override Void eachDef(Context cx, |Def| f) { cx.defs.feature("op").eachDef(f) }
}

