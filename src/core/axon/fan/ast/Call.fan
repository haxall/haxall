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
  new make(Expr target, Expr?[] args)
  {
    this.target = target
    this.args   = args
  }

  override ExprType type() { ExprType.call }

  override Loc loc() { target.loc }

  const Expr target

  const Expr?[] args  // null args indicate "_" partials

  virtual Str? targetFuncName()
  {
    if (target is Var) return ((Var)target).name
    return null
  }

  override Obj? eval(AxonContext cx)
  {
    evalTarget(cx).callLazy(cx, args, loc)
  }

  Fn evalTarget(AxonContext cx) { target.evalToFunc(cx) }

  Obj?[] evalArgs(AxonContext cx)
  {
    args.map |arg| { arg.eval(cx) }
  }

  override Void walk(|Str key, Obj? val| f)
  {
    f("target", target)
    f("args",   args)
  }

  override Printer print(Printer out)
  {
    out.atomicStart.atomic(target).wc('(')
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

  const Str funcName

  override Str? targetFuncName() { funcName }

  override Printer print(Printer out)
  {
    out.atomicStart.atomic(args[0]).wc('.').expr(target).wc('(')
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

  const Str funcName

  override Str? targetFuncName() { funcName }

  override Obj? eval(AxonContext cx)
  {
    // check that slot is defined on Xeto type for security purposes
    type := typeRef.eval(cx)
    slot := type.slot(funcName, false) ?: throw UnknownSlotErr("${type.name}.${funcName}")

    // now use reflection on Fantom type
    method := type.fantomType.method(funcName)
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
  new make(Expr target, Expr?[] args, Int numPartials)
    : super(target, args)
  {
    this.target = target
    this.args   = args
    this.params = FnParam.makeNum(numPartials)
  }

  override ExprType type() { ExprType.partialCall }

  override Obj? eval(AxonContext cx)
  {
    partial := 0
    Expr boundTarget := bind(target, cx)
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

