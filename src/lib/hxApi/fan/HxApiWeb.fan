//
// Copyright (c) 2021, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   20 May 2021  Brian Frank  Creation
//

using concurrent
using web
using haystack
using hx

**
** HTTP API web service handling
**
const class HxApiWeb : HxLibWeb, WebOpUtil
{
  new make(HxApiLib lib) : super(lib) { this.lib = lib }

  override const HxApiLib lib

  override Namespace ns() { lib.rt.ns }

  override Void onService()
  {
    try
    {
      // first level of modRel is operation name
      path := req.modRel.path
      if (path.size != 1) return res.sendErr(404)
      opName := path[0]

      // authenticate user
      cx := rt.users.authenticate(req, res)
      if (cx == null) return
      cx.timeout = HxContext.timeoutDef
      Actor.locals[Etc.cxActorLocalsKey] = cx

      // map operation to Axon function
      opDef := cx.ns.def("op:$opName", false)
      if (opDef == null) return res.sendErr(404)

      // GET requests can only call ops with no side effects
      if (req.isGet && opDef.missing("noSideEffectsX"))
        return res.sendErr(405, "GET not allowed for op '$opName'")

      // instantiate subclass of HxApiOp
      op := (HxApiOp)Type.find(opDef->typeName).make
      op.support = this
      op.onService(req, res, cx)
    }
    catch (Err e)
    {
      if (res.isCommitted)
        e.trace
      else
        writeRes(toErrGrid(e))
    }
    finally
    {
      Actor.locals.remove(Etc.cxActorLocalsKey)
    }
  }

  ** Read Haystack op request grid
  private Grid? readReq()
  {
    doReadReq(req, res)
  }

  ** Writer Haystack op response grid
  private Void writeRes(Obj? result)
  {
    if (res.isCommitted) return
    doWriteRes(req, res, Etc.toGrid(result))
  }

  ** Write error response
  private Grid toErrGrid(Err err, Obj? meta := null)
  {
    if (lib.rec.has("disableErrTrace"))
    {
      meta = Etc.makeDict(meta)
      meta = Etc.dictSet(meta, "errTrace", "${err}\n  Trace disabled")
    }
    return Etc.makeErrGrid(err, meta)
  }
}