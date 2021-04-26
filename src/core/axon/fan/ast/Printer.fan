//
// Copyright (c) 2019, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   5 Aug 2019  Brian Frank  Creation
//

using haystack

**
** Printer is used to encode/pretty print the Axon AST.  Expr printing
** is required to return Axon source code which can be re-parsed into the
** equivalent AST.  This enables Expr.toStr to marshal exprs over network.
**
@NoDoc @Js
class Printer
{
  This w(Obj v)
  {
    checkNewline
    buf.add(v)
    return this
  }

  This wc(Int c)
  {
    checkNewline
    buf.addChar(c)
    return this
  }

  This nl()
  {
    if (isNewline) return this
    isNewline = true
    buf.addChar('\n')
    return this
  }

  This eos()
  {
    if (isNewline) return this
    buf.addChar(';'); return this
  }

  This indent() { indentation++; return this }

  This unindent() { indentation--; return this }

  This val(Obj? val) { w(Etc.toAxon(val)) }

  This comma() { w(", ") }

  This expr(Expr expr) { expr.print(this) }

  This atomic(Expr expr)
  {
    ++atomicLevel
    expr.print(this)
    --atomicLevel
    return this
  }

  This atomicStart()
  {
    if (atomicLevel > 0) wc('(')
    return this
  }

  This atomicEnd()
  {
    if (atomicLevel > 0) wc(')')
    return this
  }

  override Str toStr() { buf.toStr }

  private Void checkNewline()
  {
    if (!isNewline) return
    buf.add(Str.spaces(indentation*2))
    isNewline = false
  }

  private Int indentation := 0
  private Bool isNewline
  private StrBuf buf := StrBuf()
  private Int atomicLevel
}