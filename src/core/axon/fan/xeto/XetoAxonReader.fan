//
// Copyright (c) 2026, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   8 Jan 2026  Brian Frank  Creation
//

using xeto
using xetom
using haystack
using concurrent

**
** XetoAxonReader implements XetoIO.readAxon
**
@Js @NoDoc
class XetoAxonReader
{
  new make(Namespace? ns, Str src, Dict opts)
  {
    this.ns     = ns
    this.opts   = opts
    this.src    = src
    this.lines  = src.splitLines
  }

  Dict read()
  {
    parseDoc
    parseSignature
    parseBody
    return Etc.dict3x("doc", doc, "slots", slots, "axon", body)
  }

//////////////////////////////////////////////////////////////////////////
// Doc
//////////////////////////////////////////////////////////////////////////

  private Void parseDoc()
  {
    // skip leading whitespace
    leading := true
    slashStar := 0
    for (i := 0; i<lines.size; ++i)
    {
      line := lines[i].trim

      // skip leading empty lines
      if (leading && line.isEmpty) continue
      leading = false

      // if we hit start of params with no comment, then done
      if (line.startsWith("(")) return

      // start of // lines
      if (line.startsWith("//"))
      {
        // find last one and then format
        s := i
        e := i
        for (; e<lines.size; ++e) if (!lines[e].trim.startsWith("//")) break
        this.doc = lines[s..<e].join("\n") |x->Str|
        {
          x = x.trimStart[2..-1]
          if (x.startsWith(" ")) x = x[1..-1]
          return x
        }
        return
      }

      // end of /* .... */
      if (line.contains("*/") && (slashStar == 1 || line.startsWith("/*")))
      {
        this.doc = lines[0..i].join("\n").trim[2..-3].trim
        return
      }

      // start of /* */
      if (line.startsWith("/*")) { slashStar++; continue }
    }
  }

//////////////////////////////////////////////////////////////////////////
// Signature
//////////////////////////////////////////////////////////////////////////

  private Void parseSignature()
  {
    // data structures
    slots := Str:Obj[,]
    returns := Str:Obj[:] { it.ordered = true }
    returns["name"] = "returns"

    // init tokenizer
    this.p = Parser(Loc("readAxon"), src.in)

    // (param1, param2, ...)
    p.consume(Token.lparen)
    params(slots)
    p.consume(Token.rparen)

    // : return
    if (p.cur === Token.colon)
    {
      p.consume
      typeAndMeta(returns, p.axonParam)
      slots.add(returns)
    }
    else
    {
      returns["type"] = objRef
      returns["maybe"] = Marker.val
      slots.add(returns)
    }

    // build up col names in order they were defined
    colNamesMap := Str:Str[:]
    colNamesMap.ordered = true
    slots.each |slot|
    {
      slot.each |v, n| { colNamesMap[n] = n }
    }
    colNames := colNamesMap.keys

    // turn into grid
    gb := GridBuilder()
    colNames.each |n| { gb.addCol(n) }
    slots.each |map|
    {
      cells := Obj?[,]
      cells.capacity = colNames.size
      colNames.each |n| { cells.add(map.get(n)) }
      gb.addRow(cells)
    }
    this.slots = gb.toGrid
  }

  private Void params([Str:Obj][] slots)
  {
    if (p.cur !== Token.rparen)
    {
      slots.add(param)
      while (p.cur === Token.comma)
      {
        p.consume
        slots.add(param)
      }
    }
  }

  private Str:Obj param()
  {
    acc := Str:Obj[:]
    acc.ordered = true
    acc["name"] = p.consumeId("func parameter name")
    if (p.cur === Token.colon)
    {
      p.consume

      // type or init expr
      expr := p.axonParam
      if (expr.type === ExprType.topName)
      {
        typeAndMeta(acc, expr)
      }
      else
      {
        paramDef(acc, expr)
      }
    }

    if (p.cur != Token.comma && p.cur != Token.rparen)
      paramDef(acc, p.expr)

    // default type to Obj?
    if (acc["type"] == null)
    {
      acc["type"] = objRef
      acc["maybe"] = Marker.val
    }
    return acc
  }

  private Void typeAndMeta(Str:Obj acc, TopName expr)
  {
    // if not qname then we need to resolve
    if (expr.lib == null)
    {
      acc["type"] = resolveTypeName(expr.name)
    }
    else
    {
      acc["type"] = Ref(expr.qname)
    }

    // maybe
    if (p.cur === Token.question)
    {
      acc["maybe"] = Marker.val
      p.consume
    }

    // maybe
    if (p.cur === Token.lt)
    {
      p.consume(Token.lt)
      metas(acc)
      p.consume(Token.gt)
    }
  }

  private Ref resolveTypeName(Str name)
  {
    if (ns == null) return Ref(name)
    types := ns.unqualifiedTypes(name)
    if (types.size == 1) return types.first.id
    if (types.size == 0) throw p.err("Unresolved type: $name")
    throw p.err("Ambiguous type name: $types")
  }

  private Void metas(Str:Obj acc)
  {
    if (p.cur !== Token.gt)
    {
      meta(acc)
      while (p.cur === Token.comma)
      {
        p.consume
        meta(acc)
      }
    }
  }

  private Void meta(Str:Obj acc)
  {
    name := p.consumeId("meta name")
    Obj val := Marker.val
    if (p.cur === Token.colon)
    {
      p.consume
      val = metaVal
    }

    acc[name] = val
  }

  private Obj? metaVal()
  {
    // TODO
    p.consumeVal
  }

  private Void paramDef(Str:Obj acc, Expr expr)
  {
    // we disabled parsing "<" before, so handle as special
    // case (seems like it would never happen in a default expr, but
    // who knows what kinds of things might be out there in the wild)
    if (p.cur === Token.lt) { p.consume; expr = Lt(expr, p.rangeExpr) }

    acc["axon"] = expr.toStr
  }

//////////////////////////////////////////////////////////////////////////
// Body
//////////////////////////////////////////////////////////////////////////

  private Void parseBody()
  {
    // the tokenizer should be on "=>" right now after signature
    if (p.cur !== Token.fnEq) throw p.err("Expecting => for top-level func")
    linei := p.curLine - 1
    curLine := lines[linei]

    // optional check for body
    if (opts.has("checkBody"))
    {
      p.consume(Token.fnEq)
      p.expr
    }

    // we assume that "=>" is not actually inside string literal or comment
    coli := curLine.index("=>") ?: throw p.err(curLine)
    curLine = curLine[coli+2..-1].trim

    // put together everything after =>
    s := StrBuf()
    s.add(curLine)
    lines.eachRange(linei+1..-1) |line| { s.add("\n").add(line) }
    body = s.toStr.trim
  }

//////////////////////////////////////////////////////////////////////////
// Fields
//////////////////////////////////////////////////////////////////////////

  static const Ref objRef := Ref("sys::Obj")

  const Namespace? ns
  const Str src
  const Dict opts
  private Str[] lines
  private Parser? p
  private Str? doc
  private Grid? slots
  private Str? body
}

