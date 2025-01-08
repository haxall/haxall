//
// Copyright (c) 2009, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   14 Sep 2009  Brian Frank  Creation
//

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

  override Loc loc() { func.loc }

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
**   foo().bar() => bar(foo())
**
@Js
internal const class DotCall : Call
{
  new make(Str funcName, Expr[] args)
    : super(Var(args.first.loc, funcName), args)
  {
    this.funcName= funcName
  }

  override ExprType type() { ExprType.dotCall }

  override const Str? funcName

  override Obj? eval(AxonContext cx)
  {
    // evaluate first arg as target object
    target := args.first.eval(cx)

    // check if we should dispatch as interface method
    /*
    if (target != null)
    {
      method := cx.xeto.interfaceMethodOn(target, funcName)
      if (method != null)
      {
        if (method.isStatic || method.isCtor) throw Err("Cannot call static method as instance: $method.qname")
        methodArgs := Obj?[,]
        methodArgs.capacity = args.size - 1
        args.eachRange(1..-1) |arg| { methodArgs.add(arg.eval(cx)) }
        return method.callOn(target, methodArgs)
      }
    }
    */

    // evaluate as global function, but wrap target as
    // literal to ensure it is evaluated exactly once
    callArgs := args.dup.set(0, Literal.wrap(target))
    return evalFunc(cx).callLazy(cx, callArgs, loc)
  }

  override Printer print(Printer out)
  {
    out.atomicStart.atomic(args[0]).wc('.').expr(func).wc('(')
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
}

**************************************************************************
** StaticCall
**************************************************************************

**
** StaticCall implements the dot operator on a spec name:
**   Foo.bar
**
@Js
internal const class StaticCall : Call
{
  new make(TypeRef typeRef, Str funcName, Expr[] args)
    : super(typeRef, args)
  {
    this.typeRef = typeRef
    this.funcName= funcName
  }

  override ExprType type() { ExprType.staticCall }

  const TypeRef typeRef

  override const Str? funcName

  override Obj? eval(AxonContext cx)
  {
    // now use reflection on Fantom type
    method := cx.xeto.interfaceMethod(typeRef.eval(cx), funcName)
    if (method == null) throw UnknownSlotErr("${typeRef}.${funcName}")
    if (!method.isStatic && !method.isCtor) throw Err("Cannot call instance method as static: $method.qname")
    return method.callList(evalArgs(cx))
  }

  override Printer print(Printer out)
  {
    out.atomicStart.atomic(typeRef).wc('.').w(funcName).wc('(')
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
** TrapCall is 'foo->bar' sugar for 'trap(foo, "bar")'
**
@Js
internal const class TrapCall : DotCall
{
  new make(Expr target, Str tagName)
    : super("trap", [target, Literal(tagName)])
  {
    this.tagName = tagName
  }

  override ExprType type() { ExprType.trapCall }

  const Str tagName

  override Printer print(Printer out)
  {
    out.expr(args[0]).w("->").w(tagName)
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

