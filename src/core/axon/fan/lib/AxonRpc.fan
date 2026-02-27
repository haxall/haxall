//
// Copyright (c) 2026, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//    27 Feb 2026  Brian Frank  Creation
//

using xeto
using haystack

**
** Support to marshall an Axon expression to serialize over a network
** for remote execution.
**
@NoDoc @Js
class AxonRpc
{

//////////////////////////////////////////////////////////////////////////
// Client Side
//////////////////////////////////////////////////////////////////////////

  ** Marshall an expression into a dict that can be serialized
  static Dict marshal(AxonContext cx, Expr expr)
  {
    vars := Str:Obj[:]
    vars.ordered = true
    vars["_expr"] = expr.toStr
    expr.visit |x| { marshalVisit(cx, vars, x) }
    return Etc.dictFromMap(vars)
  }

  ** Walk tree looking for Var nodes that are varaiables context (vs top funcs)
  private static Void marshalVisit(AxonContext cx, Str:Obj vars, Expr expr)
  {
    if (expr.type === ExprType.var)
    {
      var  := (Var)expr
      name := var.name
      val  := cx.getVar(name)
      vars.addNotNull(name, val)
    }
  }

//////////////////////////////////////////////////////////////////////////
// Server Side
//////////////////////////////////////////////////////////////////////////

  ** Evaluate the given 'rpc' dict that was constructed from `marshal` method.
  static Obj? eval(AxonContext cx, Dict rpc)
  {
    Str? expr := null
    rpc.each |v, n|
    {
      if (n == "_expr") expr = v
      else cx.def(n, v, Loc.remote)
    }
    if (expr == null) throw Err("Missing _expr in rpc dict")
    return cx.eval(expr)
  }

}

