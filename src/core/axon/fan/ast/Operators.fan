//
// Copyright (c) 2009, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   04 Aug 2009  Brian Frank  Creation
//

using xeto
using haystack

**************************************************************************
** UnaryOp
**************************************************************************

@Js
internal const abstract class UnaryOp : Expr
{
  new make(Expr operand) { this.operand = operand }

  override Loc loc() { operand.loc }

  const Expr operand

  override final Obj? eval(AxonContext cx)
  {
    try
      return doEval(cx)
    catch (EvalErr e)
      throw e
    catch (Err e)
      throw err(e.toStr, cx)
  }

  internal abstract Obj? doEval(AxonContext cx)

  override Void walk(|Str key, Obj? val| f)
  {
    f("operand", operand)
  }

  override Printer print(Printer out)
  {
    out.w(type.op).wc(' ').atomic(operand)
  }
}

**************************************************************************
** BinaryOp
**************************************************************************

@Js
internal const abstract class BinaryOp : Expr
{
  new make(Expr lhs, Expr rhs) { this.lhs = lhs; this.rhs = rhs }

  override Loc loc() { lhs.loc }

  const Expr lhs

  const Expr rhs

  override final Obj? eval(AxonContext cx)
  {
    try
      return doEval(cx)
    catch (EvalErr e)
      throw e
    catch (Err e)
      throw err(e.toStr, cx)
  }

  internal abstract Obj? doEval(AxonContext cx)

  override Void walk(|Str key, Obj? val| f)
  {
    f("lhs", lhs)
    f("rhs", rhs)
  }

  override Printer print(Printer out)
  {
    out.atomicStart.atomic(lhs).wc(' ').w(type.op).wc(' ').atomic(rhs).atomicEnd
  }
}

**************************************************************************
** Return
**************************************************************************

@Js
internal const class Return : Expr
{
  new make(Expr expr) { this.expr = expr }

  override ExprType type() { ExprType.returnExpr }

  override Loc loc() { expr.loc }

  const Expr expr

  override Obj? eval(AxonContext cx)
  {
    // need to use exception for flow control
    ReturnErr.putVal(expr.eval(cx))
    throw ReturnErr()
  }

  override Void walk(|Str key, Obj? val| f)
  {
    f("expr", expr)
  }

  override Printer print(Printer out) { out.w("return ").expr(expr) }
}

**************************************************************************
** Throw
**************************************************************************

@Js
internal const class Throw : Expr
{
  new make(Expr expr) { this.expr = expr }

  override ExprType type() { ExprType.throwExpr }

  override Loc loc() { expr.loc }

  const Expr expr

  override Obj? eval(AxonContext cx)
  {
    raw := expr.eval(cx)

    tags := Str:Obj[:]
    if (raw is Dict)
    {
      // if already a proper throw dict, then just throw it
      dict := (Dict)raw
      if (dict["err"] === Marker.val && dict["dis"] is Str)
        throw ThrowErr(cx, loc, dict)

      // map dict tags into our working map
      dict.each |v, n| { tags[n] = v }
      if (tags["dis"] == null) tags["dis"] = "null"
    }

    // ensure we have err marker and dis tags
    tags["err"] = Marker.val
    if (tags["dis"] == null)
      tags["dis"] = raw?.toStr ?: "null"

    throw ThrowErr(cx, loc, Etc.makeDict(tags))
  }

  override Void walk(|Str key, Obj? val| f)
  {
    f("expr", expr)
  }

  override Printer print(Printer out)
  {
    out.atomicStart.w("throw ").expr(expr).atomicEnd
  }
}

**************************************************************************
** Try/Catch
**************************************************************************

@Js
internal const class TryCatch : Expr
{
  new make(Expr tryExpr, Str? errVarName, Expr catchExpr)
  {
    this.tryExpr    = tryExpr
    this.errVarName = errVarName
    this.catchExpr  = catchExpr
  }

  override ExprType type() { ExprType.tryExpr }

  override Loc loc() { tryExpr.loc }

  const Expr tryExpr

  const Str? errVarName

  const Expr catchExpr

  override Obj? eval(AxonContext cx)
  {
    try
    {
      return tryExpr.eval(cx)
    }
    catch (ReturnErr e)
    {
      return ReturnErr.getVal
    }
    catch (Err e)
    {
      // if no error variable just evaluate catch block
      if (errVarName == null) return catchExpr.eval(cx)

      // extract exception as dict
      Dict? tags
      if (e is ThrowErr)
      {
        tags = Etc.dictSet(((ThrowErr)e).meta, "errTrace", e.traceToStr)
      }
      else
      {
        tags = Etc.makeDict(["err":Marker.val, "dis": e.toStr, "type": e.typeof.qname, "errTrace":e.traceToStr])
      }

      // evaluate catcher in new scope with errVarName variable
      cx.defOrAssign(errVarName, tags, catchExpr.loc)
      return catchExpr.eval(cx)
    }
  }

  override Void walk(|Str key, Obj? val| f)
  {
    f("tryExpr", tryExpr)
    if (errVarName != null) f("errVarName", errVarName)
    f("catchExpr", catchExpr)
  }

  override Printer print(Printer out)
  {
    out.atomicStart.w("try ")
    tryExpr.print(out)
    out.w(" catch ")
    if (errVarName != null) out.wc('(').w(errVarName).w(") ")
    catchExpr.print(out).atomicEnd
    return out
  }
}

**************************************************************************
** If
**************************************************************************

@Js
internal const class If : Expr
{
  new make(Expr cond, Expr ifExpr, Expr elseExpr := Literal.nullVal )
  {
    this.cond     = cond
    this.ifExpr   = ifExpr
    this.elseExpr = elseExpr
  }

  override ExprType type() { ExprType.ifExpr }

  override Loc loc() { cond.loc }

  const Expr cond

  const Expr ifExpr

  const Expr elseExpr

  override Obj? eval(AxonContext cx)
  {
    if (cond.eval(cx))
      return ifExpr.eval(cx)
    else
      return elseExpr.eval(cx)
  }

  override Void walk(|Str key, Obj? val| f)
  {
    f("cond", cond)
    f("ifExpr", ifExpr)
    if (!elseExpr.isNull) f("elseExpr", elseExpr)
  }

  override Printer print(Printer out)
  {
    out.atomicStart.w("if (")
    cond.print(out)
    out.w(") ")
    ifExpr.print(out)
    if (!elseExpr.isNull)
    {
      out.w(" else ")
      elseExpr.print(out)
    }
    return out.atomicEnd
  }
}

**************************************************************************
** Assignment Operator: =
**************************************************************************

@Js
internal const class Assign : BinaryOp
{
  new make(Expr lhs, Expr rhs) : super(lhs, rhs) {}

  override ExprType type() { ExprType.assign }

  override Obj? doEval(AxonContext cx)
  {
    var := lhs as Var
    if (var != null) return cx.assign(var.name, rhs.eval(cx), lhs.loc)

    // treat FFI foo.bar = baz as field set
    if (cx.ffi != null && lhs.type == ExprType.dotCall)
    {
      dotCall := (DotCall)lhs
      target := dotCall.args.first.eval(cx)  // evaluate first arg as target object
      return cx.ffi.fieldSet(cx, target, dotCall.funcName, rhs)
    }

    throw err("Not assignable: " + summary(lhs), cx)
  }

  override Printer print(Printer out)
  {
    out.atomicStart.expr(lhs).wc(' ').w(type.op).wc(' ').expr(rhs).atomicEnd
  }
}

**************************************************************************
** Conditional Operators: not and or
**************************************************************************

@Js
internal const class Not : UnaryOp
{
  new make(Expr operand) : super(operand) {}
  override ExprType type() { ExprType.not }
  override Obj? doEval(AxonContext cx) { ((Bool)operand.eval(cx)).not }
}

@Js
internal const class And : BinaryOp
{
  new make(Expr lhs, Expr rhs) : super(lhs, rhs) {}
  override ExprType type() { ExprType.and }
  override Obj? doEval(AxonContext cx)
  {
    if (lhs.eval(cx))
      return (Bool)rhs.eval(cx)
    else
      return false
  }
}

@Js
internal const class Or : BinaryOp
{
  new make(Expr lhs, Expr rhs) : super(lhs, rhs) {}
  override ExprType type() { ExprType.or }
  override Obj? doEval(AxonContext cx)
  {
    if (lhs.eval(cx))
      return true
    else
      return (Bool)rhs.eval(cx)
  }
}

**************************************************************************
** Equality Operators: == !=
**************************************************************************

@Js
internal const class Eq : BinaryOp
{
  new make(Expr lhs, Expr rhs) : super(lhs, rhs) {}
  override ExprType type() { ExprType.eq }
  override Obj? doEval(AxonContext cx) { eq(cx) }
  internal Bool eq(AxonContext cx)
  {
    a := lhs.eval(cx); at := a?.typeof
    b := rhs.eval(cx); bt := b?.typeof
    if (at === Number# && bt === Number#) return evalNumber(a, b)
    return a == b
  }
  private Bool evalNumber(Number a, Number b)
  {
    if (a.toFloat.compare(b.toFloat) != 0) return false
    if (a.unit === b.unit) return true
    if (a.unit == null || b.unit == null) return true
    return false
  }
}

@Js
internal const class Ne : Eq
{
  new make(Expr lhs, Expr rhs) : super(lhs, rhs) {}
  override ExprType type() { ExprType.ne }
  override Obj? doEval(AxonContext cx) { !eq(cx) }
}

**************************************************************************
** Comparison Operators:  < <= <=> => >
**************************************************************************

@Js
internal const abstract class Compare : BinaryOp
{
  new make(Expr lhs, Expr rhs) : super(lhs, rhs) {}
  override final Obj? doEval(AxonContext cx)
  {
    // evaluate lhs and rhs
    a := lhs.eval(cx)
    b := rhs.eval(cx)

    // null is handled by Fantom compare opcodes
    if (a == null || b == null) return cmp(a, b)

    // check for matching non-collection kinds
    ak := Kind.fromType(a.typeof, false)
    bk := Kind.fromType(b.typeof, false)
    if (ak != null && ak === bk && !ak.isCollection)
      return cmp(a, b)

    // consider non-comparable
    adis := ak?.name ?: a.typeof.toStr
    bdis := bk?.name ?: b.typeof.toStr
    throw err("Cannot compare types: $adis $type.op $bdis", cx)
  }

  abstract Obj? cmp(Obj? a, Obj? b)
}

@Js
internal const class Lt : Compare
{
  new make(Expr lhs, Expr rhs) : super(lhs, rhs) {}
  override ExprType type() { ExprType.lt }
  override Obj? cmp(Obj? a, Obj? b) { a < b }
}

@Js
internal const class Le : Compare
{
  new make(Expr lhs, Expr rhs) : super(lhs, rhs) {}
  override ExprType type() { ExprType.le }
  override Obj? cmp(Obj? a, Obj? b) { a <= b }
}

@Js
internal const class Ge : Compare
{
  new make(Expr lhs, Expr rhs) : super(lhs, rhs) {}
  override ExprType type() { ExprType.ge }
  override Obj? cmp(Obj? a, Obj? b) { a >= b }
}

@Js
internal const class Gt : Compare
{
  new make(Expr lhs, Expr rhs) : super(lhs, rhs) {}
  override ExprType type() { ExprType.gt }
  override Obj? cmp(Obj? a, Obj? b) { a > b }
}

@Js
internal const class Cmp : Compare
{
  new make(Expr lhs, Expr rhs) : super(lhs, rhs) {}
  override ExprType type() { ExprType.cmp }
  override Obj? cmp(Obj? a, Obj? b)
  {
    r := a <=> b
    if (r < 0) return Number.negOne
    if (r > 0) return Number.one
    return Number.zero
  }
}

**************************************************************************
** Math Operators: + - * /
**************************************************************************

@Js
internal const class Neg : UnaryOp
{
  new make(Expr operand) : super(operand) {}
  override ExprType type() { ExprType.neg }
  override Expr foldConst()
  {
    if (operand.isConst && operand.constVal is Number)
      return Literal(((Number)operand.constVal).negate)
    else
      return super.foldConst
  }
  override Obj? doEval(AxonContext cx)
  {
    a := operand.eval(cx)
    if (a == null) return null
    if (a is Number) return ((Number)a).negate
    if (a === NA.val) return NA.val
    throw err("Unsupported operation neg on $a.typeof", cx)
  }
}

@Js
internal const abstract class BinaryMath : BinaryOp
{
  new make(Expr lhs, Expr rhs) : super(lhs, rhs) {}

  override Obj? doEval(AxonContext cx)
  {
    a := lhs.eval(cx); at := a?.typeof
    b := rhs.eval(cx); bt := b?.typeof

    // if either side is Str and other side is not,
    // then coerce both sides to a Str (including null and NA)
    if (at != bt)
    {
      if (at === Str# || (bt === Str# && at !== Uri#))
      {
        a = a == null ? "null" : a.toStr; at = Str#
        b = b == null ? "null" : b.toStr; bt = Str#
      }
    }

    // at this point if we didn't coerce to Str, then:
    // anything against null evaluates to null
    if (a == null || b == null) return null

    // anything against NA evaluates to NA
    if (a === NA.val || b === NA.val) return NA.val


    if (at === Number#)    return evalNumber(a, b, cx)
    if (at === Str#)       return evalStr(a, b, cx)
    if (at === Date#)      return evalDate(a, b, cx)
    if (at === DateTime#)  return evalDateTime(a, b, cx)
    if (at === Time#)      return evalTime(a, b, cx)
    if (at === DateSpan#)  return evalDateSpan(a, b, cx)
    if (at === Uri#)       return evalUri(a, b, cx)
    throw err("Unsupported operation $at $type $bt", cx)
  }

  abstract Obj? evalNumber(Number a, Number b, AxonContext cx)
  virtual Obj? evalStr(Str a, Str b, AxonContext cx) { throw err("Unsupported $type on Str", cx) }
  virtual Obj? evalDate(Date a, Obj b, AxonContext cx) { throw err("Unsupported $type on Date", cx) }
  virtual Obj? evalDateTime(DateTime a, Obj b, AxonContext cx) { throw err("Unsupported $type on DateTime", cx) }
  virtual Obj? evalTime(Time a, Obj b, AxonContext cx) { throw err("Unsupported $type on Time", cx) }
  virtual Obj? evalDateSpan(DateSpan a, Obj b, AxonContext cx) { throw err("Unsupported $type on DateSpan", cx) }
  virtual Obj? evalUri(Uri a, Obj b, AxonContext cx) { throw err("Unsupported $type on Uri", cx) }
}

@Js
internal const class Add : BinaryMath
{
  new make(Expr lhs, Expr rhs) : super(lhs, rhs) {}
  override ExprType type() { ExprType.add }
  override Obj? evalNumber(Number a, Number b, AxonContext cx) { a + b }
  override Obj? evalStr(Str a, Str b, AxonContext cx) { a + b }
  override Obj? evalDate(Date a, Obj b, AxonContext cx)
  {
    if (b is Number) return a.plus(((Number)b).toDuration)
    throw err("Unsupported operation: Date + $b.typeof", cx)
  }
  override Obj? evalDateTime(DateTime a, Obj b, AxonContext cx)
  {
    if (b is Number) return a.plus(((Number)b).toDuration)
    throw err("Unsupported operation: DateTime + $b.typeof", cx)
  }
  override Obj? evalDateSpan(DateSpan a, Obj b, AxonContext cx)
  {
    if (b is Number) return a.plus(((Number)b).toDuration)
    throw err("Unsupported operation: DateSpan + $b.typeof", cx)
  }
  override Obj? evalTime(Time a, Obj b, AxonContext cx)
  {
    if (b is Number) return a.plus(((Number)b).toDuration)
    throw err("Unsupported operation: Time + $b.typeof", cx)
  }
  override Obj? evalUri(Uri a, Obj b, AxonContext cx)
  {
    if (b is Str) return a.plus(b.toStr.toUri)
    if (b is Uri) return a.plus(b)
    throw err("Unsupported operation: Uri + $b.typeof", cx)
  }
}

@Js
internal const class Sub : BinaryMath
{
  new make(Expr lhs, Expr rhs) : super(lhs, rhs) {}
  override ExprType type() { ExprType.sub }
  override Obj? evalNumber(Number a, Number b, AxonContext cx) { a - b }
  override Obj? evalDate(Date a, Obj b, AxonContext cx)
  {
    if (b is Number) return a.plus(((Number)b).negate.toDuration)
    if (b is Date) return Number.makeDuration(a.minusDate(b), Unit("day"))
    throw err("Unsupported operation: Date - $b.typeof", cx)
  }
  override Obj? evalDateTime(DateTime a, Obj b, AxonContext cx)
  {
    if (b is Number)   return a.plus(((Number)b).negate.toDuration)
    if (b is DateTime) return Number.makeDuration(a.minusDateTime(b))
    throw err("Unsupported operation: DateTime - $b.typeof", cx)
  }
  override Obj? evalTime(Time a, Obj b, AxonContext cx)
  {
    if (b is Number) return a.minus(((Number)b).toDuration)
    throw err("Unsupported operation: Time - $b.typeof", cx)
  }
  override Obj? evalDateSpan(DateSpan a, Obj b, AxonContext cx)
  {
    if (b is Number) return a.minus(((Number)b).toDuration)
    throw err("Unsupported operation: DateSpan - $b.typeof", cx)
  }
}

@Js
internal const class Mul : BinaryMath
{
  new make(Expr lhs, Expr rhs) : super(lhs, rhs) {}
  override ExprType type() { ExprType.mul }
  override Obj? evalNumber(Number a, Number b, AxonContext cx) { a * b }
}

@Js
internal const class Div : BinaryMath
{
  new make(Expr lhs, Expr rhs) : super(lhs, rhs) {}
  override ExprType type() { ExprType.div }
  override Obj? evalNumber(Number a, Number b, AxonContext cx) { a / b }
}

