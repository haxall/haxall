//
// Copyright (c) 2026, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   9 Jan 2026  Brian Frank  Creation
//

using xeto
using haystack
using axon

**
** AxonConvertParser is used to parse a 3.1 style top-level signature as
** parameters or defcomp cells into its params/cells and axon body.
**
class AxonConvertParser : Parser
{
  new make(Str src) : super(Loc("convert4"), src.in) { this.src = src }

  ** Original source
  const Str src

  ** Parsed params/cells
  AParam[] aparams := [,]

  ** Parsed axon body
  Str body := "null"

  ** 3.1 style signature that includes params or can be defcomp
  This parseSig()
  {
    if (cur === Token.defcompKeyword)
    {
      return parseSigCompDef
    }
    else
    {
      return parseSigParams
    }
  }

  This parseSigParams()
  {
    if (cur !== Token.lparen) throw err("Expecting '(...) =>' top-level function")
    consume(Token.lparen)
    params().each |x| { aparams.add(AParam(x)) }
    if (cur !== Token.fnEq) throw err("Expecting '(...) =>' top-level function")

    // the tokenizer should be on "=>" right now after signature
    if (cur !== Token.fnEq) throw err("Expecting => for top-level func")
    linei := curLine - 1
    lines := src.splitLines
    curLine := lines[linei]

    // we assume that "=>" is not actually inside string literal or comment
    coli := curLine.index("=>") ?: throw err(curLine)
    curLine = curLine[coli+2..-1].trim

    // put together everything after =>
    s := StrBuf()
    s.add(curLine)
    lines.eachRange(linei+1..-1) |line| { s.add("\n").add(line) }
    body = s.toStr.trim
    return this
  }

  This parseSigCompDef()
  {
    // defcomp keyword
    consume(Token.defcompKeyword)

    // cells as "name: {meta}"
    while (cur !== Token.doKeyword && cur !== Token.endKeyword)
    {
      aparams.add(parseCell)
    }

    // source body if we have do block
    if (cur === Token.doKeyword)
    {
      // find rest of source from current line to end
      curLineIndex := curLoc.line - 1
      lines := src.splitLines[curLineIndex..-1]
      body = lines.join("\n").trimEnd

      // now strip last end keyword
      if (!body.endsWith("end")) throw err("Missing closing end")
      body = body[0..-4].trimEnd

      // remove indention
      body = ConvertUtil.removeIndentation(body)

    }

    return this
  }

  private AParam parseCell()
  {
    name := consumeIdOrKeyword("Expecting cell name")
    consume(Token.colon)
    meta := constDict
    if (meta.has("name")) throw err("Comp cell meta cannot define 'name' tag")
    type := ConvertUtil.cellToType(name, meta)
    meta = ConvertUtil.mapDefcompCellMeta(meta)
    eos
    return AParam(name, type, meta)
  }
}

