//
// Copyright (c) 2009, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   3 Oct 2009  Brian Frank  Creation
//  22 Feb 2016  Brian Frank  Refactor into axon pod
//

using haystack

**
** ExprToFilter is used to convert an Expr into a Filter.
**
@Js
internal class ExprToFilter
{
  new make(AxonContext cx) { this.cx = cx }

  ** Convert lazy expression to a Filter
  Filter? evalToFilter(Expr expr, Bool checked := true)
  {
    try
    {
      // don't map a single string literal unless its a keyword
      if (expr.type == ExprType.literal)
      {
        literal := ((Literal)expr).val
        if (literal is Str && !Token.isKeyword(literal))
          throw NotFilterErr("String literal")
      }

      return toFilter(expr)
    }
    catch (NotFilterErr e)
    {
      if (checked) throw expr.err("Expr is not a filter; $e.msg", cx)
      return null
    }
  }

  private Filter toFilter(Expr expr)
  {
    // special pass-thru
    if (expr.type === ExprType.filter)
      return ((FilterExpr)expr).filter

    // check if expr is a variable which references a Filter
    if (expr.type === ExprType.var)
    {
      var := cx.getVar(((Var)expr).name)
      if (var is Filter) return var
    }

    // check if this is call to to parseFilter or parseSearch
    callName := expr.asCallFuncName
    if (callName == "parseFilter" || callName == "parseSearch")
      return expr.eval(cx)

    // isA symbol
    if (expr.type === ExprType.literal && expr.eval(cx) is Symbol)
      return Filter.isSymbol(expr.eval(cx))

    // if 'foo' or 'foo->bar' (allow foo to be str literal)
    if (expr.type === ExprType.var ||
        expr.type === ExprType.literal ||
        expr.type === ExprType.trapCall)
      return Filter.has(toPath(expr))

    // if 'foo <op> bar'
    binary := expr as BinaryOp
    if (binary != null)
    {
      lhs := binary.lhs
      rhs := binary.rhs
      switch (expr.type)
      {
        case ExprType.eq:  return Filter.eq(toPath(lhs), toVal(rhs))
        case ExprType.ne:  return Filter.ne(toPath(lhs), toVal(rhs))
        case ExprType.lt:  return Filter.lt(toPath(lhs), toVal(rhs))
        case ExprType.le:  return Filter.le(toPath(lhs), toVal(rhs))
        case ExprType.ge:  return Filter.ge(toPath(lhs), toVal(rhs))
        case ExprType.gt:  return Filter.gt(toPath(lhs), toVal(rhs))
        case ExprType.and: return toFilter(lhs).and(toFilter(rhs))
        case ExprType.or:  return toFilter(lhs).or(toFilter(rhs))
      }
    }

    // if 'not foo'
    if (expr.type === ExprType.not)
    {
      operand := ((UnaryOp)expr).operand
      return Filter.missing(toPath(operand))
    }

    throw err("Not a filter expr: $expr")
  }

  private FilterPath toPath(Expr expr)
  {
    if (expr is Var) return FilterPath.makeName(((Var)expr).name)
    if (expr is TrapCall)
    {
      trap := (TrapCall)expr
      names := [trap.tagName]
      while (true)
      {
        expr = trap.args[0]
        if (expr is Var) { names.insert(0, ((Var)expr).name); break }
        if (expr is TrapCall) { trap = expr; names.insert(0, trap.tagName); continue }
        throw err("Not a tag path: $expr")
      }
      return FilterPath.makeNames(names)
    }
    if (expr is Literal)
    {
      literal := (Literal)expr
      if (literal.val is Str) return FilterPath.makeName(literal.val)
    }
    throw err("Not a tag path: $expr")
  }

  private Obj? toVal(Expr expr)
  {
    // evaluate the expression
    val := expr.eval(cx)

    // check for scalar type
    kind := Kind.fromVal(val, false)
    if (kind == null) throw err("Cannot use value type '${val?.typeof}' in filter")
    if (kind.isCollection)
    {
      if (kind == Kind.dict) throw err("Cannot use Dict in filter (try using '->' operator)")
      throw err("Cannot use $kind.name in filter")
    }
    return val
  }

  private NotFilterErr err(Str msg)
  {
    return NotFilterErr(msg)
  }

  private AxonContext cx
}

**************************************************************************
** NotFilterErr
**************************************************************************

@Js
internal const class NotFilterErr : Err
{
  new make(Str? msg) : super(msg) {}
}