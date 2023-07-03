//
// Copyright (c) 2022, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   13 Aug 2022  Brian Frank  Creation
//

**
** Tokenizer generates Tokens from an input stream
**
@Js
internal class Tokenizer
{

//////////////////////////////////////////////////////////////////////////
// Constructor
//////////////////////////////////////////////////////////////////////////

  new make(InStream in)
  {
    this.in  = in
    this.tok = Token.eof
    consume
    consume
  }

//////////////////////////////////////////////////////////////////////////
// Tokenizing
//////////////////////////////////////////////////////////////////////////

  ** Current token type
  Token tok

  ** Current token value based on type:
  **  - id: identifier string
  **  - literals: the literal value
  **  - comment: comment line if keepComments set
  **  - ParseErr: the error message
  Obj? val

  ** One based line number for current token
  Int line := 1

  ** One based column number for current token
  Int col := 1

  ** Tokenize and return slash-slash comments
  Bool keepComments := true

  ** Read the next token, store result in `tok` and `val`
  Token next()
  {
    // reset
    val = null

    // skip non-meaningful whitespace and comments
    while (true)
    {
      // treat space, tab, non-breaking space as whitespace
      if (cur == ' ' || cur == '\t' || cur == 0xa0)  { consume; continue }

      // comments
      if (cur == '/')
      {
        if (peek == '/' && keepComments) { lockLoc; return tok = parseComment }
        if (peek == '/') { skipCommentSL; continue }
        if (peek == '*') { skipCommentML; continue }
      }

      break
    }

    // lock in location
    lockLoc

    // newlines
    if (cur == '\n' || cur == '\r')
    {
      if (cur == '\r' && peek == '\n') consume
      consume
      return tok = Token.nl
    }

    // handle various starting chars
    if (cur.isAlpha) return tok = id
    if (cur == '"')  return tok = str
    if (cur == '@')  return tok = ref
    if (cur.isDigit) return tok = num
    if (cur == '-' && peek.isDigit) return tok = num

    // operator
    return tok = operator
  }

  ** Lock in location of start of token
  private Void lockLoc()
  {
    this.line = curLine
    this.col  = curCol
  }

  ** Close
  Bool close() { in.close }

//////////////////////////////////////////////////////////////////////////
// Token Productions
//////////////////////////////////////////////////////////////////////////

  private Token id()
  {
    s := StrBuf()
    while (cur.isAlphaNum || cur == '_')
    {
      s.addChar(cur)
      consume
    }
    id := s.toStr

    // normal id
    this.val = id
    return Token.id
  }

  private Token str()
  {
    consume // opening quote
    isTriple := cur == '"' && peek == '"'
    if (isTriple) { consume; consume }
    s := StrBuf()
    while (true)
    {
      ch := cur
      if (ch == '"')
      {
        consume
        if (isTriple)
        {
          if (cur != '"' || peek != '"')
          {
            s.addChar('"')
            continue
          }
          consume
          consume
        }
        break
      }
      if (ch == 0) throw err("Unexpected end of string literal")
      if (ch == '\\') { s.addChar(escape); continue }
      consume
      s.addChar(ch)
    }
    this.val = s.toStr
    return Token.scalar
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

  private Token ref()
  {
    consume // opening "@"
    this.val = refName
    return Token.ref
  }

  private AName refName()
  {
    // this code duplicates Parser.parseTypeRefName but for refs

    // handle simple name as common case
    name := refSection
    if (cur != '.' && !(cur == ':' && peek == ':')) return ASimpleName(null, name)

    // handle qualified and dotted names
    path := Str[,]
    path.add(name)
    while (cur == '.')
    {
      consume
      path.add(refSection)
    }

    // if no "::" then this is a unqualified dotted path
    if (!(cur == ':' && peek == ':')) return APathName(null, path)
    consume
    consume

    // qualified name
    lib := path.join(".")
    name = refSection
    if (cur != '.') return ASimpleName(lib, name)

    // qualified dotted path
    path.clear
    path.add(name)
    while (cur == '.')
    {
      consume
      path.add(refSection)
    }

    return APathName(lib, path)
  }

  private Str refSection()
  {
    s := StrBuf()
    while (isRefChar(cur, peek))
    {
      s.addChar(cur)
      consume
    }
    return s.toStr
  }

  private static Bool isRefChar(Int cur, Int peek)
  {
    if (cur.isAlphaNum) return true
    if (cur == '_' || cur == '~') return true
    if (cur == ':' || cur == '-') return peek.isAlphaNum || peek == '_' || peek == '~'
    return false
  }

  private Token num()
  {
    s := StrBuf()
    while (isNum(cur))
    {
      s.addChar(cur)
      consume
    }
    this.val = s.toStr
    return Token.scalar
  }

  private static Bool isNum(Int c)
  {
    c.isAlphaNum || c == '-' || c == '.' || c == '$' || c == ':' || c == '/' || c == '%' || c > 128
  }

  ** Parse a symbol token (typically into an operator).
  private Token operator()
  {
    c := cur
    consume
    switch (c)
    {
      case ',':  return Token.comma
      case ':':
        if (cur == ':') { consume; return Token.doubleColon }
        return Token.colon
      case '[':  return Token.lbracket
      case ']':  return Token.rbracket
      case '{':  return Token.lbrace
      case '}':  return Token.rbrace
      case '<':  return Token.lt
      case '>':  return Token.gt
      case '.':  return Token.dot
      case '?':  return Token.question
      case '&':  return Token.amp
      case '|':  return Token.pipe
      case 0:    return Token.eof
    }

    if (c == 0) return Token.eof

    throw err("Unexpected symbol: " + c.toChar.toCode('\'') + " (0x" + c.toHex + ")")
  }

//////////////////////////////////////////////////////////////////////////
// Comments
//////////////////////////////////////////////////////////////////////////

  ** Parse single line comment when keeping comments
  private Token parseComment()
  {
    s := StrBuf()
    consume  // first slash
    consume  // next slash
    if (cur == ' ') consume // first space
    while (true)
    {
      if (cur == '\n' || cur == 0) break
      s.addChar(cur)
      consume
    }
    this.val = s.toStr
    return Token.comment
  }

  ** Skip a single line // comment
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

  ** Skip a multi line /* comment.  Note unlike C/Java,
  ** slash/star comments can be nested.
  private Void skipCommentML()
  {
    consume   // first slash
    consume   // next slash
    depth := 1
    while (true)
    {
      if (cur == '*' && peek == '/') { consume; consume; depth--; if (depth <= 0) break }
      if (cur == '/' && peek == '*') { consume; consume; depth++; continue }
      if (cur == 0) break
      consume
    }
  }

//////////////////////////////////////////////////////////////////////////
// Error Handling
//////////////////////////////////////////////////////////////////////////

  ParseErr err(Str msg)
  {
    this.val = msg
    return ParseErr(msg)
  }

//////////////////////////////////////////////////////////////////////////
// Char Reads
//////////////////////////////////////////////////////////////////////////

  private Void consume()
  {
    cur     = peek
    curLine = peekLine
    curCol  = peekCol

    peek = in.readChar ?: 0
    if (peek == '\n') { peekLine++; peekCol = 0 }
    else { peekCol++ }
  }

//////////////////////////////////////////////////////////////////////////
// Fields
//////////////////////////////////////////////////////////////////////////

  private InStream in       // underlying stream
  private Int cur           // current char
  private Int peek          // next char
  private Int peekLine := 1
  private Int peekCol
  private Int curLine
  private Int curCol
}

