//
// Copyright (c) 2026, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//    27 Feb 2026  Brian Frank  Creation
//

using xeto
using xetom::XetoUtil
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
    scope := cx.varsInScope
    acc := Str:Obj[:]
    acc.ordered = true
    acc["_expr"] = marshalExpr(expr)
    expr.visit |x| { marshalVisit(scope, acc, x) }
    return Etc.dictFromMap(acc)
  }

  ** Marshal the expression itself to a string with the rpc flag:
  **  - 'this.foo => _this_foo'
  private static Str marshalExpr(Expr expr)
  {
    out := Printer()
    out.rpc = true
    expr.print(out)
    return out.toStr
  }

  ** Walk tree looking for Var nodes that are varaiables context (vs top funcs)
  private static Void marshalVisit(Str:Obj? scope, Str:Obj acc, Expr expr)
  {
    // check for free variable, skip "this"
    if (expr.type === ExprType.var)
    {
      // get variable
      var  := (Var)expr
      name := var.name

      // this is handled specially
      if (name == "this") return

      // check if variable in scope (and special handling for null)
      val := scope[name]
      if (val == null && !scope.containsKey(name)) return

      // marshal the value
      marshalVar(acc, name, val)
      return
    }

    // check for "this.foo" and encode as "this_foo"
    thisGetKey := toThisGetVar(expr)
    if (thisGetKey != null)
    {
      name := ((DotCall)expr).funcName
      comp := scope["this"] as Comp ?: throw Err("'this' not bound to Comp")
      val  := comp.get(name)
      marshalVar(acc, thisGetKey, val)
    }
  }

  ** Marshal variable to our rpc dict, use None as sentinel for null
  private static Void marshalVar(Str:Obj acc, Str name, Obj? val)
  {
    if (val == null) val = None.val
    acc.add(name, XetoUtil.toHaystack(val))
  }

  ** Return if expr is a "this.foo" then flatten to "this_foo", else null
  internal static Str? toThisGetVar(Expr expr)
  {
    // only care about this.bar
    if (expr.type !== ExprType.dotCall) return null
    dot := (DotCall)expr

    // only care if bare field getter
    if (!dot.bareName) return null

    // only care if target is the "this" variable
    if (dot.args[0].type !== ExprType.var) return null
    var := (Var)dot.args[0]
    if (var.name != "this") return null

    // this is a match
    return "this_$dot.funcName"
  }

//////////////////////////////////////////////////////////////////////////
// Server Side
//////////////////////////////////////////////////////////////////////////

  ** Evaluate the given 'rpc' dict that was constructed from `marshal` method.
  static Obj? eval(AxonContext cx, Dict rpc)
  {
    Str? expr := null
    rpc.each |Obj? v, Str n|
    {
      if (n == "_expr") { expr = v; return }
      if (v === None.val) v = null
      cx.def(n, v, Loc.remote)
    }
    if (expr == null) throw Err("Missing _expr in rpc dict")
    return cx.eval(expr)
  }

}

