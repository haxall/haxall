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
** AxonSigParser is used to parse a 3.1 style top-level signature as
** parameters or defcomp cells into its params/cells and axon body.
**
class AxonSigParser : Parser
{
  new make(Str src) : super(Loc("convert4"), src.in) { this.src = src }

  ** Original source
  const Str src

  ** Parsed cells
  AParam[] params := [,]

  ** Parsed axon body
  Str body := "null"

  ** Parse source and return output  in cells, body fields
  This parseCompDef()
  {
    // defcomp keyword
    consume(Token.defcompKeyword)

    // cells as "name: {meta}"
    while (cur !== Token.doKeyword && cur !== Token.endKeyword)
    {
      params.add(parseCell)
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
    eos
    return AParam(name, AType.obj, meta)
  }
}

