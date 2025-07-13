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
** Api4Test tests Haxall 4.x Xeto based APIs defined by Haystack 5.0
**
class Api4Test : ApiTest
{
  @HxTestProj
  Void test()
  {
    init
    doPing
    doEval
    cleanup
  }

//////////////////////////////////////////////////////////////////////////
// Ping
//////////////////////////////////////////////////////////////////////////

  Void doPing()
  {
    verifyPing(a)
    verifyPing(b)
    verifyPing(c)
  }

  private Void verifyPing(Client c)
  {
    dict := call(c, "sys.ping", [:]) as Dict
    ts := (DateTime)dict->time
    verifyEq(ts.date, Date.today)
    verifyEq(ts.tz, TimeZone.cur)
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

