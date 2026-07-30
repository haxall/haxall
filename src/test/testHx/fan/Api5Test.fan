//
// Copyright (c) 2025, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   18 Feb 2025  Brian Frank  Creation
//

using concurrent
using inet
using xeto
using haystack
using auth
using axon
using hx

**
** Api5Test tests the v5 xeto protocol (Haystack 5.0) selected by the
** Xeto-Version header.
**
class Api5Test : ApiTest
{
  @HxTestProj
  Void test()
  {
    // the v5 HTTP dispatch is not implemented yet, but the op funcs
    // themselves are, so exercise what can run today
    doOpsFunc

    /* TODO: enable once ApiDispatchV5 is implemented
    init
    doCommon
    doEval
    cleanup
    */
  }

//////////////////////////////////////////////////////////////////////////
// Ops
//////////////////////////////////////////////////////////////////////////

  ** The v5 "ops" format is a quick listing for debugging and discovery,
  ** deliberately not a machine readable schema - the spec op serves that
  ** purpose.  Version 4 clients get the legacy def format from
  ** ApiDispatchV4Ops instead, which never reaches this function.
  Void doOpsFunc()
  {
    g := (Grid)eval("ops()")

    // every row must validate against the OpInfo spec
    ns := proj.ns
    opInfo := ns.spec("sys.api::OpInfo")
    verifyEq(g.meta->of, Ref("sys.api::OpInfo"))
    g.each |row|
    {
      verifyEq(ns.validate(row, opInfo).hasErrs, false, row->qname)
    }

    // the listing is qname, doc, noSideEffects, signature -- not a
    // machine readable schema; the spec op serves that purpose
    ["qname", "doc", "noSideEffects", "signature"].each |c|
    {
      verifyNotNull(g.col(c, false), c)
    }
    verifyNull(g.col("params", false))
    verifyNull(g.col("returns", false))

    // rows are sorted by qname so the listing is stable
    verify(g.size > 0)
    verifyEq(g.toRows.map |r->Str| { r->qname },
             g.toRows.map |r->Str| { r->qname }.dup.sort)

    // about: no params, typed result, GET-able
    about := verifyOpRow(g, "sys.api::about")
    verifyEq(about->signature, "() -> AboutInfo")
    verifyEq(about.has("noSideEffects"), true)

    // close: no params, no result, POST only
    close := verifyOpRow(g, "sys.api::close")
    verifyEq(close->signature, "() -> None")
    verifyEq(close.has("noSideEffects"), false)

    // read: a required filter plus a defaulted checked flag
    read := verifyOpRow(g, "sys.api::read")
    verifyEq(read->signature, "(filter: Filter, checked: Bool = true) -> Dict")

    // readById: "id" is nullable so the signature marks it with ? and does NOT
    // report a bogus default of @x inherited from the Ref type's meta
    byId := verifyOpRow(g, "sys.api::readById")
    verifyEq(byId->signature, "(id: Ref?, checked: Bool = true) -> Dict")

    // doc is the first sentence only, never a mid-sentence cut and
    // never the whole hard wrapped paragraph
    verifyEq(about->doc, "Return summary information about the server")
    verifyEq(read->doc, "Read the first entity which matches [filter](ph.doc::Filters)")
  }

  private Dict verifyOpRow(Grid g, Str qname)
  {
    row := g.find |r| { r->qname == qname }
    verifyNotNull(row, qname)
    return row
  }

//////////////////////////////////////////////////////////////////////////
// Dialect Hooks
//////////////////////////////////////////////////////////////////////////

  override ApiVersion version() { ApiVersion.v5 }

  ** Version 5 encodes the args as a JSON dict and decodes clean JSON
  override Obj? callOp(Client c, Str op, Str:Obj args)
  {
    call(c, op, args)
  }

//////////////////////////////////////////////////////////////////////////
// Eval
//////////////////////////////////////////////////////////////////////////

  Void doEval()
  {
    verifyEval(a)
    verifyEval(b)
    verifyEval(c)
  }

  private Void verifyEval(Client c)
  {
    verifyCall(c, "eval", ["expr":"today()"], Date.today)
  }

//////////////////////////////////////////////////////////////////////////
// Utils
//////////////////////////////////////////////////////////////////////////

  Void verifyCall(Client c, Str op, Obj args, Obj? expect)
  {
    actual := call(c, op, args)
    verifyEq(actual, expect)
  }

  Obj? call(Client c, Str op, Obj args)
  {
    // TODO: just temp solution
    x := c.toWebClient(op.toUri)
    req := StrBuf()
    JsonWriter(req.out).writeVal(Etc.makeDict(args))
    if (debug) { echo(">>>>"); echo(req) }
    x.postStr(req.toStr)
    res := x.resIn.readAllStr
    if (debug) { echo("<<<<"); echo(res) }
    return JsonReader(res.in).readVal
  }

  const Bool debug := false
}

