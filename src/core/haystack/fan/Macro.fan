//
// Copyright (c) 2012, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   30 Oct 2012  Brian Frank  Hurricane Sandy!
//

using xeto

**
** Macro is used to process macro strings for `Etc.macro`.
**
@NoDoc @Js
class Macro
{
  new make(Str pattern, Dict scope := Etc.dict0)
  {
    this.pattern = pattern
    this.scope = scope
  }

  Str[] vars()
  {
    this.varNames = Str[,]
    apply
    return this.varNames.unique
  }

  Str applyChecked(|Str->Str|? resolve := null)
  {
    this.checked = true
    return apply(resolve)
  }

  Str apply(|Str->Str|? resolve := null)
  {
    resBuf.clear
    size := pattern.size
    for (i:=0; i<size; ++i)
    {
      // next char in pattern
      c := pattern[i]

      // inside an expression
      if (mode != norm)
      {
        // check if end of expression, in which case evaluate
        if (isEndOfExpr(c))
        {
          resBuf.add(eval(exprBuf.toStr, resolve))
          doContinue := mode != exprSimple
          mode = norm
          if (doContinue) continue
        }
        else
        {
          // just keep building up expression
          exprBuf.addChar(c)
          continue
        }
      }

      // check for $xxx or ${xxx}
      if (c == '$')
      {
        // $<xxx> | ${xxx} | $xxx
        next := (i+1 < size) ? pattern[i+1] : '?'
        if (next == '{') { mode = exprBraces; ++i }
        else if (next == '<') { mode = exprLocale; ++i; }
        else mode = exprSimple

        exprBuf.clear
        continue
      }

      // just normal char
      resBuf.addChar(c)
    }

    // trailing expression
    if (mode != norm)
    {
      expr := exprBuf.toStr
      if (mode == exprSimple) resBuf.add(eval(expr, resolve))
      else if (mode == exprLocale) resBuf.add("\$<").add(expr)
      else resBuf.add("\${").add(expr)
    }

    return resBuf.toStr
  }

  private Str eval(Str expr, |Str->Str|? resolve)
  {
    try
    {
      // $<pod::key>
      if (mode == exprLocale)
      {
        colons := expr.index("::")
        return Pod.find(expr[0..<colons]).locale(expr[colons+2..-1], null) ?: throw Err()
      }

      // add to varNames list if computing vars()
      if (varNames != null && !expr.isEmpty) varNames.add(expr)

      // assume tag name from scope
      val := resolve == null ? scope[expr] : resolve(expr)
      if (val is Ref) return refToDis(val)
      return val.toStr
    }
    catch (Err e)
    {
      if (checked) throw e
      if (mode == exprSimple) return "\$$expr"
      if (mode == exprLocale) return "\$<$expr>"
      return "\${$expr}"
    }
  }

  private Bool isEndOfExpr(Int ch)
  {
    if (mode == exprBraces) return ch == '}'
    if (mode == exprLocale) return ch == '>'
    return !(ch < simpleEndChars.size && simpleEndChars[ch])
  }

  static const Int norm       := 0
  static const Int exprSimple := 1
  static const Int exprBraces := 2
  static const Int exprLocale := 3

  static const Bool[] simpleEndChars
  static
  {
    map := Bool[,]
    map.fill(false, 128)
    for (i:='a'; i<='z'; ++i) map[i] = true
    for (i:='A'; i<='Z'; ++i) map[i] = true
    for (i:='0'; i<='9'; ++i) map[i] = true
    map['_'] = true
    simpleEndChars = map
  }

  virtual Str refToDis(Ref ref) { ref.dis }

  const Str pattern                   // pattern string of macro
  const Dict scope                    // variable scope
  private Int mode                    // norm, exprSimple, exprBraces
  private StrBuf resBuf := StrBuf()   // result buffer
  private StrBuf exprBuf := StrBuf()  // expression buffer
  private Str[]? varNames             // only if calling vars()
  private Bool checked                // flag to
}

