//
// Copyright (c) 2009, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   06 Jun 2009  Brian Frank  Creation
//   28 Dec 2009  Brian Frank  DataReader => ZincReader
//

using xeto

**
** Read Haystack data in [Zinc]`docHaystack::Zinc` format.
**
@Js
class ZincReader : GridReader
{

//////////////////////////////////////////////////////////////////////////
// Constructor
//////////////////////////////////////////////////////////////////////////

  ** Wrap input stream
  new make(InStream in)
  {
    this.tokenizer = HaystackTokenizer(in)
    this.cur = this.peek = HaystackToken.eof
    consume
    consume
  }

  ** Wrap tokenizer
  @NoDoc internal new makeTokenizer(HaystackTokenizer tokenizer)
  {
    this.tokenizer = tokenizer
    this.cur = this.peek = HaystackToken.eof
    consume
    consume
  }

//////////////////////////////////////////////////////////////////////////
// Public
//////////////////////////////////////////////////////////////////////////

  ** Close the underlying stream.
  Bool close() { tokenizer.close }

  ** Read a value and auto close stream
  Obj? readVal(Bool close := true)
  {
    try
    {
      Obj? val
      if (cur === HaystackToken.id && curVal == "ver")
        val = parseGrid
      else
        val = parseVal
      verify(HaystackToken.eof)
      return val
    }
    finally
    {
      if (close) this.close
    }
  }

  ** Convenience for `readVal` as Grid
  override Grid readGrid() { readVal(true) }

  ** Read a list of grids separated by blank line from stream.
  @NoDoc Grid[] readGrids()
  {
    // this is old 2.1 construct
    acc := Grid[,]
    while (cur === HaystackToken.id)
      acc.add(parseGrid)
    return acc
  }

  ** Read a set of tags as 'name:val' pairs separated by space or comma.
  @NoDoc Dict readTags() { parseDict(true) }

//////////////////////////////////////////////////////////////////////////
// Utils
//////////////////////////////////////////////////////////////////////////

  private Obj? parseVal()
  {
    // if its an id
    if (cur === HaystackToken.id)
    {
      // consume identifier
      id := (Str)curVal
      consume

      // check for coord or xstr
      if (cur === HaystackToken.lparen)
      {
        if (peek === HaystackToken.num)
          return parseCoord(id)
        else
          return parseXStr(id)
      }

      // check for keyword
      switch (id)
      {
        case "T":    return true
        case "F":    return false
        case "N":    return null
        case "M":    return Marker.val
        case "NA":   return NA.val
        case "R":    return Remove.val
        case "NaN":  return Number.nan
        case "INF":  return Number.posInf
      }

      throw err("Unexpected identifier $id.toCode")
    }

    // literals
    if (cur.literal) return parseLiteral

    // -INF
    if (cur === HaystackToken.minus && peekVal == "INF")
    {
      consume
      consume
      return Number.negInf
    }

    // nested collections
    if (cur === HaystackToken.lbracket) return parseList
    if (cur === HaystackToken.lbrace) return parseDict(true)
    if (cur === HaystackToken.lt2) return parseGrid

    // give up
    throw err("Unexpected token: $curToStr")
  }

  private Obj? parseLiteral()
  {
    val := curVal
    if (cur === HaystackToken.ref && peek === HaystackToken.str)
    {
      val = tokenizer.factory.makeRef(((Ref)val).id, peekVal)
      consume
    }
    consume
    return val
  }

  private Obj? parseCoord(Str id)
  {
    if (id != "C") throw err("Expecting 'C' for coord, not $id.toCode")
    consume(HaystackToken.lparen)
    lat := consumeNum
    consume(HaystackToken.comma)
    lng := consumeNum
    consume(HaystackToken.rparen)
    return Coord(lat.toFloat, lng.toFloat)
  }

  private Obj? parseXStr(Str id)
  {
    if (!id[0].isUpper) throw err("Invalid XStr type $id.toCode")
    consume(HaystackToken.lparen)
    if (ver < 3 && id == "Bin") return parseBinObsolete
    val := consumeStr
    consume(HaystackToken.rparen)
    return XStr.decode(id, val)
  }

  private Bin parseBinObsolete()
  {
    s := StrBuf()
    while (cur !== HaystackToken.rparen && cur !== HaystackToken.eof)
    {
      s.add(curVal ?: cur.dis)
      consume
    }
    consume(HaystackToken.rparen)
    return Bin(s.toStr)
  }

  private Obj? parseList()
  {
    acc := Obj?[,]
    consume(HaystackToken.lbracket)
    while (cur !== HaystackToken.rbracket && cur !== HaystackToken.eof)
    {
      val := parseVal
      acc.add(val)
      if (cur !== HaystackToken.comma) break
      consume
    }
    consume(HaystackToken.rbracket)
    return Kind.toInferredList(acc)
  }

  private Obj? parseDict(Bool allowComma)
  {
    acc := Str:Obj?[:]
    if (allowComma) acc.ordered = true

    braces := cur === HaystackToken.lbrace
    if (braces) consume(HaystackToken.lbrace)
    while (cur === HaystackToken.id)
    {
      // tag name
      id := (Str)curVal
      if (!id[0].isLower && id[0] != '_') throw err("Invalid dict tag name: $id.toCode")
      consume

      // tag value
      Obj? val := Marker.val
      if (cur === HaystackToken.colon)
      {
        consume
        val = parseVal
      }

      acc[id] = val

      if (allowComma && cur == HaystackToken.comma) consume
    }
    if (braces) consume(HaystackToken.rbrace)

    return Etc.makeDict(acc)
  }

  private Obj? parseGrid()
  {
    nested := cur === HaystackToken.lt2
    if (nested)
    {
      consume(HaystackToken.lt2)
      if (cur === HaystackToken.nl) consume(HaystackToken.nl)
    }

    // ver:"3.0"
    if (cur !== HaystackToken.id || curVal != "ver")
      throw err("Expecting grid 'ver' identifier, not $curToStr")
    consume
    consume(HaystackToken.colon)
    this.ver = checkVersion(consumeStr)

    // grid meta
    gb := GridBuilder()
    if (cur === HaystackToken.id)
      gb.setMeta(parseDict(false))
    consume(HaystackToken.nl)

    // column definitions
    while (cur === HaystackToken.id)
    {
      name := consumeTagName
      meta := Etc.dict0
      if (cur === HaystackToken.id)
        meta = parseDict(false)
      gb.addCol(name, meta)
      if (cur !== HaystackToken.comma) break
      consume(HaystackToken.comma)
    }
    numCols := gb.numCols
    if (numCols == 0) throw err("No columns defined")
    consume(HaystackToken.nl)

    // grid rows
    while (true)
    {
      if (cur === HaystackToken.nl) break
      if (cur === HaystackToken.eof) break
      if (nested && cur === HaystackToken.gt2) break

      // read cells
      cells := Obj?[,]
      cells.capacity = numCols
      for (i := 0; i<numCols; ++i)
      {
        if (cur === HaystackToken.comma || cur === HaystackToken.nl || cur == HaystackToken.eof)
          cells.add(null)
        else
          cells.add(parseVal)
        if (i+1 < numCols) consume(HaystackToken.comma)
      }
      gb.addRow(cells)

      // newline or end
      if (nested && cur === HaystackToken.gt2) break
      if (cur === HaystackToken.eof) break
      consume(HaystackToken.nl)
    }

    if (cur === HaystackToken.nl) consume
    if (nested) consume(HaystackToken.gt2)
    return gb.toGrid
  }

  private Int checkVersion(Str s)
  {
    if (s == "3.0") return 3
    if (s == "2.0") return 2
    throw err("Unsupported version $s.toCode")
  }

//////////////////////////////////////////////////////////////////////////
// Char Reads
//////////////////////////////////////////////////////////////////////////

  private Str consumeTagName()
  {
    verify(HaystackToken.id)
    id := (Str)curVal
    if (!id[0].isLower && id[0] != '_') throw err("Invalid dict tag name: $id.toCode")
    consume
    return id
  }

  private Number consumeNum()
  {
    val := curVal
    consume(HaystackToken.num)
    return val
  }

  private Str consumeStr()
  {
    val := curVal
    consume(HaystackToken.str)
    return val
  }

  private Void verify(HaystackToken expected)
  {
    if (cur != expected) throw err("Expected $expected not $curToStr")
  }

  private Str curToStr()
  {
    curVal != null ? "$cur $curVal.toStr.toCode" : cur.toStr
  }

  private Void consume(HaystackToken? expected := null)
  {
    if (expected != null) verify(expected)

    cur      = peek
    curVal   = peekVal
    curLine  = peekLine

    peek     = tokenizer.next
    peekVal  = tokenizer.val
    peekLine = tokenizer.line
  }

  private ParseErr err(Str msg) { ParseErr("$msg [line $curLine]") }

//////////////////////////////////////////////////////////////////////////
// Fields
//////////////////////////////////////////////////////////////////////////

  private HaystackTokenizer tokenizer
  private Bool isTop := true
  private Int ver := 3

  private HaystackToken cur    // current token
  private Obj? curVal          // current token value
  private Int curLine          // current token line number

  private HaystackToken peek   // next token
  private Obj? peekVal         // next token value
  private Int peekLine         // next token line number
}

