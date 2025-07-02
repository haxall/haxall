//
// Copyright (c) 2009, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   06 Jun 2009  Brian Frank  Creation
//   29 Aug 2009  Brian Frank  Repurpose from old rec/query/change model
//

using xeto
using haystack

**
** Stream based tokenizer for Axon grammar.
**
@NoDoc @Js
class Tokenizer
{

//////////////////////////////////////////////////////////////////////////
// Constructor
//////////////////////////////////////////////////////////////////////////

  new make(Loc startLoc, InStream in)
  {
    this.startLoc = startLoc
    this.in  = in
    this.tok = Token.eof
    consume
    consume
  }

//////////////////////////////////////////////////////////////////////////
// Tokenizing
//////////////////////////////////////////////////////////////////////////

  **
  ** Read the next token, store result in `tok` and `val`
  **
  Token next()
  {
    // reset
    val = null

    // skip whitespace or comments
    startLine := line
    while (true)
    {
      if (cur == '\n')
      {
        ++line; consume
        while (cur == ' ') consume
        continue
      }
      // treat space, tab, non-breaking space as whitespace
      if (cur == ' ' || cur == '\t' || cur == 0xa0)  { consume; continue }
      if (cur == '\r') throw err("Carriage return characters disallowed")
      if (cur == '/')
      {
        if (peek == '/') { skipCommentSL; continue }
        if (peek == '*') { skipCommentML; continue }
      }
      break
    }

    // handle various starting chars
    if (cur == 'r' && peek == '"') return tok = rawStr
    if (cur.isAlpha) return tok = word
    if (cur == '"')  return tok = str
    if (cur == '@')  return tok = ref
    if (cur.isDigit) return tok = num
    if (cur == '^')  return tok = symbol
    if (cur == '`')  return tok = uri

    // symbol
    return tok = operator
  }

//////////////////////////////////////////////////////////////////////////
// Token Productions
//////////////////////////////////////////////////////////////////////////

  private Token word()
  {
    s := StrBuf()
    while (cur.isAlphaNum || cur == '_')
    {
      s.addChar(cur)
      consume
    }
    id := s.toStr
    val = id

    // capitalized identifier is type name
    if (id[0].isUpper) return Token.typename

    // check keywords
    keyword := Token.keywords[id]
    if (keyword != null) { val = null; return keyword }

    // normal identifier
    return Token.id
  }

  private Token num()
  {
    // hex number (no unit allowed)
    isHex := cur == '0' && peek == 'x'
    if (isHex)
    {
      consume
      consume
      s := StrBuf()
      while (true)
      {
        if (cur.isDigit(16)) { s.addChar(cur); consume; continue }
        if (cur == '_') { consume; continue }
        break
      }
      val = Number(Int.fromStr(s.toStr, 16).toFloat)
      return Token.val
    }

    // consume all the things that might be part of this number token
    s := StrBuf().addChar(cur);
    consume
    colons := 0; dashes := 0; unitIndex := 0; exp := false
    while (true)
    {
      if (!cur.isDigit)
      {
        if (exp && (cur == '+' || cur == '-')) { }
        else if (cur == '-') { dashes++ }
        else if (cur == ':' && peek.isDigit) { colons++ }
        else if ((exp || colons >= 1) && cur == '+') {}
        else if (cur == '.') { if (!peek.isDigit) break }
        else if ((cur == 'e' || cur == 'E') && (peek == '-' || peek == '+' || peek.isDigit)) { exp = true }
        else if (cur.isAlpha || cur == '%' || cur == '$' || cur > 128 || (cur == '/' && peek != '/')) { if (unitIndex == 0) unitIndex = s.size}
        else if (cur == '_') { if (unitIndex == 0 && peek.isDigit) { consume; continue } else { if (unitIndex == 0) unitIndex = s.size } }
        else { break }
      }
      s.addChar(cur)
      consume
    }

    // Date
    if (dashes == 2  && colons == 0)
    {
      val = Date.fromStr(s.toStr, false)
      if (val == null) throw err("Invalid date literal '$s'")
      return Token.val
    }

    // Month (convenience for 1-28/31 date range)
    if (dashes == 1  && colons == 0)
    {
      start := Date.fromStr("$s-01", false)
      if (start != null)
      {
        val = DateSpan.makeMonth(start.year, start.month)
        return Token.val
      }
    }

    // Time: we don't require hour to be two digits and
    // we don't require seconds
    if (dashes == 0 && colons >= 1)
    {
      if (s[1] == ':') s.insert(0, "0")
      if (colons == 1) s.add(":00")
      val = Time.fromStr(s.toStr, false)
      if (val == null) throw err("Invalid time literal '$s'")
      return Token.val
    }

    // parse as Number
    str := s.toStr
    if (unitIndex == 0)
    {
      float := Float.fromStr(str, false)
      if (float == null) throw err("Invalid number literal '$str'")
      val = Number(float, null)
    }
    else
    {
      floatStr := str[0..<unitIndex]
      unitStr := str[unitIndex..-1]
      float := Float.fromStr(floatStr, false)
      if (float == null) throw err("Invalid number literal '$str'")
      unit  := Number.loadUnit(unitStr, false)
      if (unit == null) throw err("Invalid unit name '$unitStr' [" + unitStr.toCode('"', true) + "]")
      val = Number(float, unit)
    }
    return Token.val
  }

  private Token rawStr()
  {
    consume // opening 'r'
    consume // opening quote
    s := StrBuf()
    while (true)
    {
      ch := cur
      if (ch == '"') { consume; break }
      if (ch == 0 || ch == '\n') throw err("Unexpected end of str")
      consume
      s.addChar(ch)
    }
    val = s.toStr
    return Token.val
  }

  private Token str()
  {
    consume // opening quote
    if (cur == '"' && peek == '"')
      return strTripleQuote

    s := StrBuf()
    while (true)
    {
      ch := cur
      if (ch == '"') { consume; break }
      if (ch == '$') throw err("String interpolation not supported yet")
      if (ch == 0 || ch == '\n') throw err("Unexpected end of str")
      if (ch == '\\') { s.addChar(escape); continue }
      consume
      s.addChar(ch)
    }
    val = s.toStr
    return Token.val
  }

  private Token strTripleQuote()
  {
    consume // opening quotes (first already consumed by str)
    consume
    s := StrBuf()
    startCol := this.col
    while (true)
    {
      ch := cur
      if (ch == '$') throw err("String interpolation not supported yet")
      if (ch == 0) throw err("Unexpected end of str")
      if (ch == '\\') { s.addChar(escape); continue }
      if (ch == '"')
      {
        if (col < startCol) throw err("Leading space in multi-line string must be $startCol")
        consume
        if (cur == '"' && peek == '"') { consume; consume; break }
      }

      if (col >= startCol)
      {
        if (ch != '"') consume
        s.addChar(ch)
      }
      else if (ch == '\n')
      {
        consume
        s.addChar(ch)
      }
      else
      {
        if (ch != ' ') throw err("Leading space in multi-line string must be $startCol [$ch.toChar.toCode]")
        consume
      }
    }
    val = s.toStr
    return Token.val
  }

  private Token ref()
  {
    consume // @
    s := StrBuf()
    while (true)
    {
      ch := cur
      if (Ref.isIdChar(ch))
      {
        consume
        s.addChar(ch)
      }
      else
      {
        break
      }
    }
    if (s.isEmpty) throw err("Invalid empty ref")
    val = Ref(s.toStr)
    return Token.val
  }

  private Token symbol()
  {
    consume // ^
    s := StrBuf()
    while (true)
    {
      ch := cur
      if (Ref.isIdChar(ch))
      {
        consume
        s.addChar(ch)
      }
      else
      {
        break
      }
    }
    if (s.isEmpty) throw err("Invalid empty symbol")
    val = Symbol(s.toStr)
    return Token.val
  }

  private Token uri()
  {
    consume // opening backtick
    s := StrBuf()
    while (true)
    {
      ch := cur
      if (ch == '`') { consume; break }
      if (ch == '$') throw err("String interpolation not supported yet")
      if (ch == 0 || ch == '\n') throw err("Unexpected end of uri")
      if (ch == '\\')
      {
        switch (peek)
        {
          case ':': case '/': case '?': case '#':
          case '[': case ']': case '@': case '\\':
          case '&': case '=': case ';': case '$':
            s.addChar(ch)
            s.addChar(peek)
            consume
            consume
          default:
            s.addChar(escape)
        }
      }
      else
      {
        consume
        s.addChar(ch)
      }
    }
    val = Uri.fromStr(s.toStr)
    return Token.val
  }

  private Int escape()
  {
    // consume slash
    consume

    // check basics
    switch (cur)
    {
      case 'b':   consume; return '\b'
      case 'f':   consume; return '\f'
      case 'n':   consume; return '\n'
      case 'r':   consume; return '\r'
      case 't':   consume; return '\t'
      case '"':   consume; return '"'
      case '$':   consume; return '$'
      case '\'':  consume; return '\''
      case '`':   consume; return '`'
      case '\\':  consume; return '\\'
    }

    // check for uxxxx
    if (cur == 'u')
    {
      consume
      n3 := cur.fromDigit(16); consume
      n2 := cur.fromDigit(16); consume
      n1 := cur.fromDigit(16); consume
      n0 := cur.fromDigit(16); consume
      if (n3 == null || n2 == null || n1 == null || n0 == null) throw err("Invalid hex value for \\uxxxx")
      return n3.shiftl(12).or(n2.shiftl(8)).or(n1.shiftl(4)).or(n0)
    }

    throw err("Invalid escape sequence")
  }

  **
  ** Parse a symbol token (typically into an operator).
  **
  private Token operator()
  {
    c := cur
    consume
    switch (c)
    {
      case 0: return Token.eof
      case '\r':
        throw err("Carriage return \\r not allowed in source")
      case '!':
        if (cur == '=') { consume; return Token.notEq }
        return Token.bang
      case '&':
        return Token.amp
      case '(':
        return Token.lparen
      case ')':
        return Token.rparen
      case '*':
        return Token.star
      case '+':
        return Token.plus
      case ',':
        return Token.comma
      case '-':
        if (cur == '>') { consume; return Token.arrow }
        return Token.minus
      case '.':
        if (cur == '.') { consume; return Token.dotDot }
        return Token.dot
      case '/':
        return Token.slash
      case ':':
        if (cur == ':') { consume; return Token.doubleColon }
        return Token.colon
      case ';':
        return Token.semicolon
      case '<':
        if (cur == '=')
        {
          consume;
          if (cur == '>') { consume; return Token.cmp }
          return Token.ltEq
        }
        return Token.lt
      case '=':
        if (cur == '=') { consume; return Token.eq }
        if (cur == '>') { consume; return Token.fnEq }
        return Token.assign
      case '>':
        if (cur == '=') { consume; return Token.gtEq }
        return Token.gt
      case '?':
        return Token.question
      case '[':
        return Token.lbracket
      case ']':
        return Token.rbracket
      case '{':
        return Token.lbrace
      case '|':
        return Token.pipe
      case '}':
        return Token.rbrace
      case '^':
        return Token.caret
      case '_':
        return Token.underbar
    }

    if (c == 0) return Token.eof

    throw err("Unexpected symbol: " + c.toChar + " (0x" + c.toHex + ")")
  }

//////////////////////////////////////////////////////////////////////////
// Comments
//////////////////////////////////////////////////////////////////////////

  **
  ** Skip a single line // comment
  **
  private Void skipCommentSL()
  {
    consume  // first slash
    consume  // next slash
    while (true)
    {
      if (cur == '\n' || cur == 0) break
      consume
    }
  }

  **
  ** Skip a multi line /* comment.  Note unlike C/Java,
  ** slash/star comments can be nested.
  **
  private Void skipCommentML()
  {
    consume   // first slash
    consume   // next slash
    depth := 1
    while (true)
    {
      if (cur == '*' && peek == '/') { consume; consume; depth--; if (depth <= 0) break }
      if (cur == '/' && peek == '*') { consume; consume; depth++; continue }
      if (cur == '\n') ++line
      if (cur == 0) break
      consume
    }
  }

//////////////////////////////////////////////////////////////////////////
// Error Handling
//////////////////////////////////////////////////////////////////////////

  SyntaxErr err(Str msg) { SyntaxErr(msg, curLoc) }

  Loc curLoc() { Loc(startLoc.file, startLoc.line + line) }

//////////////////////////////////////////////////////////////////////////
// Char Reads
//////////////////////////////////////////////////////////////////////////

  private Void consume()
  {
    if (cur == '\n') col = 0; else col++
    cur  = peek
    peek = in.readChar ?: 0
  }

//////////////////////////////////////////////////////////////////////////
// Fields
//////////////////////////////////////////////////////////////////////////

  Loc startLoc         // location immediately before first line
  Token tok            // current token type
  Obj? val             // token literal or identifier
  Int line := 1        // current line number (one based)
  Int col := -2        // current column index (zero based)
  private InStream in  // underlying stream
  private Int cur      // current char
  private Int peek     // next char
}

