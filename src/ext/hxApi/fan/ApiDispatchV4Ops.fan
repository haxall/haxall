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
    "watchPoll": ApiDispatchV4WatchPoll#,
  ]

  new make(ApiPipeline p) : super(p) {}

  ** These adapters service the legacy op themselves rather than calling the
  ** func, so they always take the request grid whole no matter what params
  ** the func declares: sys.api::read models 'filter' and 'checked', but
  ** ApiDispatchV4Read.doCall needs the grid
  override Bool takesReqGrid() { true }

  ** A failure raised by the special follows the same legacy contract as
  ** one raised by an op func: a 200 response carrying an error grid.
  ** Watch clients detect an invalid watch by exactly that grid.
  override Obj? call(Obj?[] args)
  {
    try
      return doCall(args[0])
    catch (ApiErr e)
      throw e
    catch (Err e)
      pipeline.writeErrGrid(e)
    return null
  }

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
    acc := Dict[,]
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

  virtual Void eachDef(Context cx, |Dict| f) { cx.defs.eachDef(f) }
}

**************************************************************************
** Filetypes
**************************************************************************

internal class ApiDispatchV4Filetypes : ApiDispatchV4Defs
{
  new make(ApiPipeline p) : super(p) {}

  ** Synthesize the def shaped rows from the Filetype registry, the
  ** system of record; the def namespace is no longer consulted
  override Void eachDef(Context cx, |Dict| f)
  {
    Filetype.list.each |ft|
    {
      acc := Str:Obj[:] { ordered = true }
      acc["def"] = Symbol("filetype:$ft.name")
      acc["filetype"] = Marker.val
      acc["dis"] = ft.dis
      acc["mime"] = ft.mime.toStr
      acc["fileExt"] = ft.fileExt
      acc["icon"] = ft.icon3
      doc := cx.ns.spec(ft.spec, false)?.meta?.get("doc") as Str
      if (doc != null) acc["doc"] = Etc.firstSentence(doc)
      f(Etc.dictFromMap(acc))
    }
  }
}

**************************************************************************
** Libs
**************************************************************************

internal class ApiDispatchV4Libs: ApiDispatchV4Defs
{
  new make(ApiPipeline p) : super(p) {}

  override Void eachDef(Context cx, |Dict| f) { cx.defs.libsList.each(f) }
}

**************************************************************************
** Ops
**************************************************************************

internal class ApiDispatchV4Ops: ApiDispatchV4Defs
{
  new make(ApiPipeline p) : super(p) {}

  override Void eachDef(Context cx, |Dict| f) { cx.defs.feature("op").eachDef(f) }
}

**************************************************************************
** WatchPoll
**************************************************************************

** Version 4 carries watchId/refresh/curValSub in the request grid meta
** rather than as named args, so map the meta tags onto the modeled func
internal class ApiDispatchV4WatchPoll : ApiDispatchV4Op
{
  new make(ApiPipeline p) : super(p) {}

  override Grid doCall(Grid req)
  {
    meta := req.meta
    watchId := meta["watchId"] as Str ?: throw Err("Missing meta.watchId")
    return PhApiFuncs.watchPoll(watchId, meta["refresh"] as Marker, meta["curValSub"] as Marker)
  }
}

