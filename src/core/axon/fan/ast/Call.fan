//
// Copyright (c) 2009, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   14 Sep 2009  Brian Frank  Creation
//

using concurrent
using util
using xeto
using haystack

**
** Call is used to invoke a function.
**
@Js
internal const class Call : Expr
{
  new make(Expr func, Expr?[] args)
  {
    this.func = func
    this.args = args
  }

  override ExprType type() { ExprType.call }

  override FileLoc loc() { func.loc }

  const Expr func

  const Expr?[] args  // null args indicate "_" partials

  virtual Str? funcName()
  {
    if (func is Var) return ((Var)func).name
    return null
  }

  override Obj? eval(AxonContext cx)
  {
    evalFunc(cx).callLazy(cx, args, loc)
  }

  Fn evalFunc(AxonContext cx) { func.evalToFunc(cx) }

  Obj?[] evalArgs(AxonContext cx)
  {
    args.map |arg| { arg.eval(cx) }
  }

  override Void walk(|Str key, Obj? val| f)
  {
    f("func", func)
    f("args", args)
  }

  ** A bare name in call position is a func, not a variable
  override Void doFreeVars(Str:Str acc)
  {
    if (func.type !== ExprType.var) func.doFreeVars(acc)
    args.each |arg| { arg?.doFreeVars(acc) }
  }

  override Printer print(Printer out)
  {
    out.atomicStart.atomic(func).wc('(')
    args.each |arg, i|
    {
      if (i > 0) out.comma
      if (arg == null) out.wc('_')
      else arg.print(out)
    }
    out.wc(')').atomicEnd
    return out
  }
}

**************************************************************************
** DotCall
**************************************************************************

**
** DotCall implements the dot operator:
**
**     foo().bar() => bar(foo())
**
** If nullSafe, then 'foo()?.bar()' returns null when target is null.
**
@Js
internal const class DotCall : Call
{
  new make(Str funcName, Expr[] args, Bool bareName, Bool nullSafe := false)
    : super(Var(args.first.loc, funcName), args)
  {
    this.funcName = funcName
    this.bareName = bareName
    this.nullSafe = nullSafe
  }

  override ExprType type() { ExprType.dotCall }

  override const Str? funcName

  const Bool bareName  // no parens

  const Bool nullSafe  // "?." operator

  override Obj? eval(AxonContext cx)
  {
    // evaluate first arg as target object
    target := args.first.eval(cx)
    if (target == null && nullSafe) return null

    // if FFI is installed it is always dispatched as OO method
    if (target != null && cx.ffi != null)
    {
      return cx.ffi.callDot(cx, target, funcName, args[1..-1])
    }

    // evaluate as global function, but wrap target as
    // literal to ensure it is evaluated exactly once
    callArgs := args.dup.set(0, Literal.wrap(target))
    return evalFunc(cx).callLazy(cx, callArgs, loc)
  }

  override Printer print(Printer out)
  {
    // in RPC mode encode "this.foo" to "this_foo"
    if (out.rpc)
    {
      thisGet := AxonRpc.toThisGetVar(this)
      if (thisGet != null) return out.w(thisGet)
    }

    out.atomicStart.atomic(args[0]).w(nullSafe ? "?." : ".").expr(func).wc('(')
    args.each |arg, i|
    {
      if (i == 0) return
      if (i > 1) out.comma
      if (arg == null) out.wc('_')
      else arg.print(out)
    }
    out.wc(')').atomicEnd
    return out
  }

  override Void walk(|Str key, Obj? val| f)
  {
    super.walk(f)
    if (nullSafe) f("nullSafe", Marker.val)
  }
}

**************************************************************************
** StaticCall
**************************************************************************

**
** StaticCall implements the dot operator on a spec name:
**
**     Foo.bar
**
@Js
internal const class StaticCall : Call
{
  new make(TopName target, Str funcName, Expr[] args)
    : super(target, args)
  {
    this.target = target
    this.funcName= funcName
  }

  override ExprType type() { ExprType.staticCall }

  const TopName target

  override const Str? funcName

  const AtomicRef cache := AtomicRef(null)

  override Obj? eval(AxonContext cx)
  {
    // static calls route to FFI if installed
    ffi := cx.ffi
    if (ffi == null)
    {
      // constructor call on type name such as Str(...)
      if (funcName == "<init>") throw typeCallErr(cx, target.name)
      throw UnsupportedErr("Static call: ${target}.$funcName")
    }
    return ffi.callStatic(cx, target, funcName, args, cache)
  }

  override Printer print(Printer out)
  {
    out.atomicStart.atomic(target).wc('.').w(funcName).wc('(')
    args.each |arg, i|
    {
      if (i > 1) out.comma
      arg.print(out)
    }
    out.wc(')').atomicEnd
    return out
  }
}

**************************************************************************
** TrapCall
**************************************************************************

**
** TrapCall is `foo->bar` sugar for `trap(foo, "bar")`
**
@Js
internal const class TrapCall : DotCall
{
  new make(Expr target, Str tagName, Bool nullSafe := false)
    : super("trap", [target, Literal(tagName)], false, nullSafe)
  {
    this.tagName = tagName
  }

  override ExprType type() { ExprType.trapCall }

  const Str tagName

  override Printer print(Printer out)
  {
    out.expr(args[0]).w(nullSafe ? "?->" : "->").w(tagName)
  }
}

**************************************************************************
** PartialCall
**************************************************************************

**
** PartialCall
**
@Js
internal const class PartialCall : Call
{
  // null args are the _ partial params
  new make(Expr func, Expr?[] args, Int numPartials)
    : super(func, args)
  {
    this.func   = func
    this.args   = args
    this.params = FnParam.makeNum(numPartials)
  }

  override ExprType type() { ExprType.partialCall }

  override Obj? eval(AxonContext cx)
  {
    partial := 0
    Expr boundTarget := bind(func, cx)
    Expr[] boundArgs := args.map |arg->Expr|
    {
      // if partial, then use partial func param, otherwise
      // evaluate the arg and bind it as a literal
      arg == null ? Var(loc, params[partial++].name) : bind(arg, cx)
    }
    call := Call(boundTarget, boundArgs)
    return Fn(loc, toStr, params, call)
  }

  private Literal bind(Expr expr, AxonContext cx)
  {
    val := expr.eval(cx)
    if (val == null) return Literal.nullVal
    if (val.isImmutable) return Literal(val)
    return UnsafeLiteral(val)
  }

  const FnParam[] params

}

