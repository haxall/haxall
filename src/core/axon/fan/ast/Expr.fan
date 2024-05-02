//
// Copyright (c) 2009, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   14 Sep 2009  Brian Frank  Creation
//

using haystack

**
** Expr is the base class for Axon AST nodes.  All expressions
** are immutable classes safe to share between threads once parsed.
**
@Js
const abstract class Expr
{

  ** Get type enum
  @NoDoc abstract ExprType type()

  ** Location of this expression in source code or 'Loc.unknown'.
  abstract Loc loc()

  ** Evaluate this expression.
  abstract Obj? eval(AxonContext cx)

  ** Encode the AST into a tree of dicts.  See `parseAst()`.
  Dict encode()
  {
    acc := Str:Obj?[:] { ordered = true }
    acc["type"] = type.encode
    walk |k, v| { acc[k] = encodeNorm(v) }
    return Etc.makeDict(acc)
  }

  private Obj? encodeNorm(Obj? v)
  {
    if (v is Expr) return ((Expr)v).encode
    if (v is List) return ((List)v).map |x| { encodeNorm(x) }
    if (v is FnParam) return ((FnParam)v).encode
    return v
  }

  ** Walk through the AST tree to encode into dict/maps
  @NoDoc abstract Void walk(|Str key, Obj? val| f)

  ** Print this expr which must parse back to same expr
  @NoDoc abstract Printer print(Printer out)

  ** Print to string
  override Str toStr()
  {
    out := Printer()
    print(out)
    return out.toStr
  }

  ** Evaluate this expression to a function.
  @NoDoc Fn evalToFunc(AxonContext cx)
  {
    t := eval(cx)
    fn := t as Fn
    if (fn == null)
    {
      // if t is a func record in database, get as func
      if (t is Dict)
      {
        dict := (Dict)t
        name := dict["name"] as Str
        if (dict.has("func") && name != null)
          fn = cx.findTop(name, false)
      }
      if (fn == null)
      {
        var := this as Var
        if (var != null)
        {
          fn = cx.findTop(var.name, false)
          if (fn != null) throw err("Local variable $var.name.toCode is hiding function", cx)
          else throw err("Local variable $var.name.toCode is not assigned to a function: " + summary(t), cx)
        }
        throw err("Target does not eval to func: " + summary(t), cx)
      }
    }
    return fn
  }

  ** Evaluate this expression to a filter.
  @NoDoc Filter? evalToFilter(AxonContext cx, Bool checked := true)
  {
    ExprToFilter(cx).evalToFilter(this, checked)
  }

  ** Get summary string
  @NoDoc static Str summary(Obj? obj)
  {
    // specials
    if (obj == null) return "null"
    if (obj is Block) return "Block"
    if (obj is Fn) return "Func " + ((Fn)obj).sig

    // grid
    if (obj is Grid)
    {
      grid := (Grid)obj
      size := "?"
      try { size = grid.size.toStr } catch {}
      return obj.typeof.name + " ${grid.cols.size}x$size"
    }

    // list
    if (obj is List)
    {
      list := (List)obj
      s := StrBuf()
      s.add("[")
      for (i:=0; i<list.size; ++i)
      {
        if (i > 0) s.add(", ")
        str := summary(list[i])
        if (s.size + str.size > 58) { s.add("..."); break }
        s.add(str)
      }
      s.add("]")
      return s.toStr
    }

    // dict
    if (obj is Dict)
    {
      dict := (Dict)obj
      s := StrBuf()
      s.add("{")
      try
      {
        dict.each |v, n|
        {
          if (s.size > 1) s.add(", ")
          if (s.size + n.size > 50) throw Err()
          s.add(n)
          if (v == Marker.val) return
          s.add(":")
          str := summary(v)
          if (s.size + str.size > 50) throw Err()
          s.add(str)
        }
      }
      catch (Err e) { s.add("...") }
      s.add("}")
      return s.toStr
    }

    // scalars
    kind := Kind.fromVal(obj, false)
    if (kind != null) { return kind.valToStr(obj) }

    // fallback
    str := obj.toStr
    if (str.size > 60) str = str[0..60] + "..."
    return "$str is $obj.typeof.name"
  }

  ** Return EvalErr with this expression's location.
  @NoDoc EvalErr err(Str msg, AxonContext cx) { EvalErr(msg, cx, loc) }

  ** Perform constant folding if we can, otherwise return this
  @NoDoc virtual Expr foldConst() { this }

  ** Return if this is a constant literal
  @NoDoc virtual Bool isConst() { false }

  ** Return constant literal or raise exception otherwise
  @NoDoc virtual Obj? constVal() { throw Err("Not const: $type") }

//////////////////////////////////////////////////////////////////////////
// Conveniences
//////////////////////////////////////////////////////////////////////////

  ** Is this the null literal
  @NoDoc Bool isNull()   { type === ExprType.literal && ((Literal)this).val == null }

  ** Is this the marker literal
  @NoDoc Bool isMarker() { type === ExprType.literal && ((Literal)this).val === Marker.val }

  ** If this expr is a call return the unqualified func name being called, otherwise null
  @NoDoc Str? asCallFuncName()
  {
    if (type === ExprType.dotCall) return ((DotCall)this).funcName
    if (type === ExprType.call)
    {
      target := ((Call)this).func as Var
      if (target != null)
      {
        name := target.name
        colon := name.indexr(":")
        if (colon != null) name = name[colon+1..-1]
        return name
      }
    }
    return null
  }

}

