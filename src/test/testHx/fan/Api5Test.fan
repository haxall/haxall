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
    /* TODO: enable once ApiDispatchV5 is implemented
    init
    doCommon
    doEval
    cleanup
    */
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
    verifyCall(c, "hx.eval", ["expr":"today()"], Date.today)
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

