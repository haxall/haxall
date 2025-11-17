//
// Copyright (c) 2024, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   30 Apr 2024  Brian Frank  Creation
//

using xeto
using xetom
using haystack
using axon
using folio
using hx

**
** AbstractAxonTest
**
abstract class AbstractAxonTest : HxTest
{
  Namespace initNamespace(Str[] libs)
  {
    // nuke existing using recs
    proj.libs.clear

    // add new using recs
    libs.each |lib| { addLib(lib) }

    // sync
    proj.sync
    ns := proj.ns
    return ns
  }

  Namespace ns()
  {
    proj.ns
  }

  Void verifyEval(Str expr, Obj? expect)
  {
    verifyEq(makeContext.eval(expr), expect)
  }

  Void verifySpec(Str expr, Str qname)
  {
    cx := makeContext
    x := cx.eval(expr)
    // echo("::: $expr => $x [$x.typeof]")
    verifySame(x, ns.type(qname))
  }

  Obj? toHay(Obj? x)
  {
    XetoUtil.toHaystack(x)
  }

}

