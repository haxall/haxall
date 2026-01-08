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
  new make(Namespace ns, Str src, Dict funcMeta)
  {
    this.ns       = ns
    this.funcMeta = funcMeta
    this.src      = src
    this.lines    = src.splitLines
    this.objRef   = ns.sysLib.spec("Obj").id
  }

  Dict read()
  {
    // init tokenizer
    this.p = Parser(Loc("readAxon"), src.in)

    // (param1, param2, ...)
    p.consume(Token.lparen)
    params
    p.consume(Token.rparen)

    // hardcode return for now
    slots.add(Str:Obj["name":"returns", "type":objRef, "maybe":Marker.val])

    // parse the rest as the axon body
    parseBody

    return Etc.dict2("slots", Etc.makeMapsGrid(null, slots), "axon", body)
  }

//////////////////////////////////////////////////////////////////////////
// Signature
//////////////////////////////////////////////////////////////////////////

  private Void params()
  {
    if (p.cur !== Token.rparen)
    {
      param
      while (p.cur === Token.comma)
      {
        p.consume
        param
      }
    }
  }

  private Void param()
  {
    acc := Str:Obj[:]
    acc["name"] = p.consumeId("func parameter name")
    if (p.cur === Token.colon)
    {
      p.consume
      typeRef(acc)
    }

    if (acc["type"] == null)
    {
      acc["type"] = objRef
      acc["maybe"] = Marker.val
    }

    slots.add(acc)
  }

  private Void typeRef(Str:Obj acc)
  {
    if (p.cur === Token.typename)
    {
      acc["type"] = ns.unqualifiedType(p.curVal).id
      p.consume
    }

    if (p.cur === Token.question)
    {
      acc["maybe"] = Marker.val
      p.consume
    }
  }

//////////////////////////////////////////////////////////////////////////
// Body
//////////////////////////////////////////////////////////////////////////

  private Void parseBody()
  {
    // the tokenizer should be on "=>" right now after signature
    if (p.cur !== Token.fnEq) throw Err("Expecting => for top-level func")
    linei := p.curLine - 1
    curLine := lines[linei]

    // we assume that "=>" at end of this line is not
    // actually inside string literal or comment
    coli := curLine.indexr("=>") ?: throw Err(curLine)
    curLine = curLine[coli+2..-1].trim

    // put together everything after =>
    s := StrBuf()
    s.add(curLine)
    lines.eachRange(linei+1..-1) |line| { s.add("\n").add(line) }
    body = s.toStr
  }

//////////////////////////////////////////////////////////////////////////
// Fields
//////////////////////////////////////////////////////////////////////////

  const Namespace ns
  const Str src
  const Dict funcMeta
  const Ref objRef
  private Str[] lines
  private Parser? p
  private [Str:Obj][] slots := Str:Obj[,]
  private Str? body
}

