//
// Copyright (c) 2009, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   06 Jun 2009  Brian Frank  Creation
//   29 Aug 2009  Brian Frank  Repurpose from old rec/query/change model
//   13 Jan 2016  Brian Frank  Repurpose from Axon parser
//

**
** Stream based tokenizer for Haystack formats such as Zinc and Filters
**
@NoDoc @Js
class HaystackTokenizer
{

//////////////////////////////////////////////////////////////////////////
// Constructor
//////////////////////////////////////////////////////////////////////////

  new make(InStream in)
  {
    this.in  = in
    this.tok = HaystackToken.eof
    consume
    consume
  }

//////////////////////////////////////////////////////////////////////////
// Tokenizing
//////////////////////////////////////////////////////////////////////////

  ** Current token type
  HaystackToken tok

  ** Current token value based on type:
  **  - id: identifier string
  **  - literals: the literal value
  **  - keyword: value mapped by `keywords`
  **  - comment: comment line if keepComments set
  **  - ParseErr: the error message
  Obj? val

  ** One based line number for current token
  Int line := 1

  ** Tokenize and return slash-slash comments
  Bool keepComments

  ** Tokenize the map's keys as keyword tokens instead of identifiers
  [Str:Obj]? keywords

  ** Read the next token, store result in `tok` and `val`
  HaystackToken next()
  {
    // reset
    val = null

    // skip non-meaningful whitespace and comments
    startLine := line
    while (true)
    {
      // treat space, tab, non-breaking space as whitespace
      if (cur == ' ' || cur == '\t' || cur == 0xa0)  { consume; continue }

      // comments
      if (cur == '/')
      {
        if (peek == '/' && keepComments) return tok = parseComment
        if (peek == '/') { skipCommentSL; continue }
        if (peek == '*') { skipCommentML; continue }
      }

      break
    }

    // newlines
    if (cur == '\n' || cur == '\r')
    {
      if (cur == '\r' && peek == '\n') consume
      consume
      line++
      return tok = HaystackToken.nl
    }

    // handle various starting chars
    if (cur.isAlpha || (cur == '_' && (peek.isAlphaNum || peek == '_'))) return tok = id
    if (cur == '"')  return tok = str
    if (cur == '@')  return tok = ref
    if (cur == '^')  return tok = symbol
    if (cur.isDigit) return tok = num
    if (cur == '`')  return tok = uri
    if (cur == '-' && peek.isDigit) return tok = num

    // operator
    return tok = operator
  }

  ** Close
  Bool close() { in.close }

  ** Factory for value creation and interning
  @NoDoc HaystackFactory factory := HaystackFactory()

  ** Only parse number units that are unit symbol
  @NoDoc Bool strictUnit

//////////////////////////////////////////////////////////////////////////
// Token Productions
//////////////////////////////////////////////////////////////////////////

  private HaystackToken id()
  {
    s := StrBuf()
    while (cur.isAlphaNum || cur == '_')
    {
      s.addChar(cur)
      consume
    }
    id := factory.makeId(s.toStr)

    // check for keyword
    if (keywords != null && keywords[id] != null)
    {
      this.val = keywords[id]
      return HaystackToken.keyword
    }

    // normal id
    this.val = id
    return HaystackToken.id
  }

  private HaystackToken num()
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
      this.val = factory.makeNumber(Int.fromStr(s.toStr, 16).toFloat, null)
      return HaystackToken.num
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
        else if (cur.isAlpha || cur == '%' || cur == '$' || cur == '/' || cur > 128) { if (unitIndex == 0) unitIndex = s.size}
        else if (cur == '_') { if (unitIndex == 0 && peek.isDigit) { consume; continue } else { if (unitIndex == 0) unitIndex = s.size } }
        else { break }
      }
      s.addChar(cur)
      consume
    }

    // Date
    if (dashes == 2  && colons == 0)
    {
      this.val = factory.makeDate(s.toStr)
      if (this.val == null) throw err("Invalid Date literal '$s'")
      return HaystackToken.date
    }

    // Time: we don't require hour to be two digits and
    // we don't require seconds
    if (dashes == 0 && colons >= 1)
    {
      if (s[1] == ':') s.insert(0, "0")
      if (colons == 1) s.add(":00")
      this.val = factory.makeTime(s.toStr)
      if (this.val == null) throw err("Invalid Time literal '$s'")
      return HaystackToken.time
    }

    // DateTime
    if (dashes >= 2)
    {
      // xxx timezone
      if (cur != ' ' || !peek.isUpper)
      {
        if (s[-1] == 'Z') s.add(" UTC")
        else throw err("Expecting timezone")
      }
      else
      {
        consume; s.addChar(' ')
        while (cur.isAlphaNum || cur == '_' || cur == '-' || cur == '+')
        {
          s.addChar(cur); consume
        }
      }
      this.val = factory.makeDateTime(s.toStr)
      if (this.val == null) throw err("Invalid DateTime literal '$s'")
      return HaystackToken.dateTime
    }

    // parse as Number
    str := s.toStr
    if (unitIndex == 0)
    {
      float := Float.fromStr(str, false)
      if (float == null) throw err("Invalid Number literal '$str'")
      this.val = Number(float, null)
    }
    else
    {
      floatStr := str[0..<unitIndex]
      unitStr := str[unitIndex..-1]
      float := Float.fromStr(floatStr, false)
      if (float == null) throw err("Invalid Number literal '$floatStr'")
      unit  := Number.loadUnit(unitStr, false)
      if (unit == null) throw err("Invalid unit name '$unitStr' [" + unitStr.toCode('"', true) + "]")
      if (strictUnit && unitStr != unit.symbol) throw err("Must use normalized unit key '$unit.symbol'")
      this.val = factory.makeNumber(float, unit)
    }
    return HaystackToken.num
  }

  private HaystackToken str()
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
      if (ch == 0) throw err("Unexpected end of str")
      if (ch == '\\') { s.addChar(escape); continue }
      consume
      s.addChar(ch)
    }
    this.val = factory.makeStr(s.toStr)
    return HaystackToken.str
  }

  private HaystackToken ref()
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
    if (s.isEmpty) throw err("Invalid empty Ref")
    this.val = factory.makeRef(s.toStr, null)
    return HaystackToken.ref
  }

  private HaystackToken symbol()
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
    if (s.isEmpty) throw err("Invalid empty Symbol")
    this.val = factory.makeSymbol(s.toStr)
    return HaystackToken.symbol
  }

  private HaystackToken uri()
  {
    consume // opening backtick
    s := StrBuf()
    while (true)
    {
      ch := cur
      if (ch == '`') { consume; break }
      if (ch == 0 || ch == '\n') throw err("Unexpected end of uri")
      if (ch == '\\')
      {
        switch (peek)
        {
          case ':': case '/': case '?': case '#':
          case '[': case ']': case '@': case '\\':
          case '&': case '=': case ';':
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
    this.val = factory.makeUri(s.toStr)
    return HaystackToken.uri
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

    // check for \uxxxx or \u{x}
    if (cur == 'u')
    {
      consume
      if (cur == '{')
      {
        consume
        ch := 0
        numDigits := 0
        while (cur != '}')
        {
          i := cur.fromDigit(16)
          numDigits++
          if (i == null) throw err("Invalid hex value for \\u{x}")
          ch = ch.shiftl(4).or(i)
          consume
        }
        if (numDigits == 0 || numDigits > 6) throw err("Invalid number of hex digits for \\u{x}")
        consume
        return ch
      }
      else
      {
        n3 := cur.fromDigit(16); consume
        n2 := cur.fromDigit(16); consume
        n1 := cur.fromDigit(16); consume
        n0 := cur.fromDigit(16); consume
        if (n3 == null || n2 == null || n1 == null || n0 == null) throw err("Invalid hex value for \\uxxxx")
        return n3.shiftl(12).or(n2.shiftl(8)).or(n1.shiftl(4)).or(n0)
      }
    }

    throw err("Invalid escape sequence")
  }

  ** Parse a symbol token (typically into an operator).
  private HaystackToken operator()
  {
    c := cur
    consume
    switch (c)
    {
      case ',':
        return HaystackToken.comma
      case ':':
        if (cur == ':') { consume; return HaystackToken.colon2 }
        return HaystackToken.colon
      case ';':
        return HaystackToken.semicolon
      case '[':
        return HaystackToken.lbracket
      case ']':
        return HaystackToken.rbracket
      case '{':
        return HaystackToken.lbrace
      case '}':
        return HaystackToken.rbrace
      case '(':
        return HaystackToken.lparen
      case ')':
        return HaystackToken.rparen
      case '<':
        if (cur == '<') { consume; return HaystackToken.lt2 }
        if (cur == '=') { consume; return HaystackToken.ltEq }
        return HaystackToken.lt
      case '>':
        if (cur == '>') { consume; return HaystackToken.gt2 }
        if (cur == '=') { consume; return HaystackToken.gtEq }
        return HaystackToken.gt
      case '-':
        if (cur == '>') { consume; return HaystackToken.arrow }
        return HaystackToken.minus
      case '=':
        if (cur == '=') { consume; return HaystackToken.eq }
        if (cur == '>') { consume; return HaystackToken.fnArrow }
        return HaystackToken.assign
      case '!':
        if (cur == '=') { consume; return HaystackToken.notEq }
        return HaystackToken.bang
      case '/':
        return HaystackToken.slash
      case '.':
        return HaystackToken.dot
      case '?':
        return HaystackToken.question
      case '&':
        return HaystackToken.amp
      case '|':
        return HaystackToken.pipe
      case 0:
        return HaystackToken.eof
    }

    if (c == 0) return HaystackToken.eof

    throw err("Unexpected symbol: " + c.toChar.toCode('\'') + " (0x" + c.toHex + ")")
  }

//////////////////////////////////////////////////////////////////////////
// Comments
//////////////////////////////////////////////////////////////////////////

  ** Parse single line comment when keeping comments
  private HaystackToken parseComment()
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
    return HaystackToken.comment
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
      if (cur == '\n') ++line
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
    return ParseErr("$msg [line $line]")
  }

//////////////////////////////////////////////////////////////////////////
// Char Reads
//////////////////////////////////////////////////////////////////////////

  private Void consume()
  {
    cur  = peek
    peek = in.readChar ?: 0
  }

//////////////////////////////////////////////////////////////////////////
// Fields
//////////////////////////////////////////////////////////////////////////

  private InStream in  // underlying stream
  private Int cur      // current char
  private Int peek     // next char
}

**************************************************************************
** HaystackParser
**************************************************************************

@NoDoc @Js
abstract class HaystackParser
{
  new make(Str s)
  {
    this.input = s
    this.tokenizer = HaystackTokenizer(s.in)
    this.cur = this.peek = HaystackToken.eof
    consume
    consume
  }

  Bool isKeyword(Str n)
  {
    cur === HaystackToken.id && curVal == n
  }

  Void verify(HaystackToken expected)
  {
    if (cur != expected) throw err("Expected $expected not $curToStr")
  }

  Str curToStr()
  {
    curVal != null ? "$cur $curVal.toStr.toCode" : cur.toStr
  }

  Void consume(HaystackToken? expected := null)
  {
    if (expected != null) verify(expected)
    cur      = peek
    curVal   = peekVal
    peek     = tokenizer.next
    peekVal  = tokenizer.val
  }

  ParseErr err(Str msg) { throw ParseErr(msg) }

  const Str input
  HaystackTokenizer tokenizer
  HaystackToken cur    // current token
  Obj? curVal          // current token value
  HaystackToken peek   // next token
  Obj? peekVal         // next token value
}


**************************************************************************
** HaystackFactory (used for text readers, not BrioReader)
**************************************************************************

@Js
@NoDoc
class HaystackFactory
{
  virtual Str makeId(Str s) { s }
  virtual Str makeStr(Str s) { s }
  virtual Uri makeUri(Str s) { Uri(s) }
  virtual Ref makeRef(Str s, Str? dis) { Ref.makeImpl(s, dis) }
  virtual Symbol makeSymbol(Str s) { Symbol.fromStr(s) }
  virtual Time? makeTime(Str s) { Time(s, false) }
  virtual Date? makeDate(Str s) { Date(s, false) }
  virtual DateTime? makeDateTime(Str s) { DateTime(s, false) }
  virtual Number makeNumber(Float f, Unit? unit) { Number(f, unit) }
}

**************************************************************************
** FreeFormParser
**************************************************************************

** Parse free-form input string to tags.  Tags are formatted "name:value"
** and may be separated by space or comma.  Most Zinc/Trio syntax may be used
** for values (or value may be omitted for marker).  If the string is not
** properly tokenized then fallback to a single "name: string" tag.
@NoDoc @Js
class FreeFormParser : HaystackParser
{
  new make(Namespace ns, Str s) : super(s) { this.ns = ns }

  const Namespace ns

  Dict parse()
  {
    postProcess(parseRaw)
  }

  private Str:Obj? parseRaw()
  {
    // first try to parse strictly from tokens
    try
    {
      while (cur != HaystackToken.eof) tag
      return acc
    }
    catch (Err e) {}

    // fallback to parse as simple "name" or "name:val"
    colon := input.index(":")
    if (colon == null) return acc.set(input, Marker.val)
    name := input[0..<colon].trim
    val  := input[colon+1..-1].trim
    return acc.set(name, val)
  }

  private Void tag()
  {
    // name
    verify(HaystackToken.id)
    name := curVal
    consume

    // check for ": val"
    Obj? val := Marker.val
    if (cur == HaystackToken.colon)
    {
      consume
      val = curToVal
      consume
    }

    // optional comma
    if (cur == HaystackToken.comma) consume

    acc[name] = val
  }

  private Obj curToVal()
  {
    if (cur.literal) return curVal
    if (cur == HaystackToken.id)
    {
      switch (curVal.toStr)
      {
        case "true":  return true
        case "false": return false
        case "NA":    return NA.val
        default:      return curVal
      }
    }
    throw err("Not value: $cur")
  }

  private Dict postProcess(Str:Obj? acc)
  {
    Etc.makeDict(acc.map |v, n| { norm(n, v) })
  }

  private Obj? norm(Str name, Obj? val)
  {
    tag := ns.def(name, false)
    if (tag != null && val == Marker.val)
      return ns.defToKind(tag).defVal
    else
      return val
  }

  private Str:Obj? acc := [:] { ordered = true }
}

**************************************************************************
** HaystackToken
**************************************************************************

@NoDoc @Js
enum class HaystackToken
{

//////////////////////////////////////////////////////////////////////////
// Enum
//////////////////////////////////////////////////////////////////////////

  // identifer/literals
  id  ("identifier"),
  keyword  ("keyword"),
  num ("Number", true),
  str ("Str", true),
  ref ("Ref", true),
  symbol ("Symbol", true),
  uri ("Uri", true),
  date ("Date", true),
  time ("Time", true),
  dateTime ("DateTime", true),

  // operators
  dot           ("."),
  colon         (":"),
  colon2        ("::"),
  comma         (","),
  semicolon     (";"),
  minus         ("-"),
  eq            ("=="),
  notEq         ("!="),
  lt            ("<"),
  lt2           ("<<"),
  ltEq          ("<="),
  gt            (">"),
  gt2           (">>"),
  gtEq          (">="),
  lbrace        ("{"),
  rbrace        ("}"),
  lparen        ("("),
  rparen        (")"),
  lbracket      ("["),
  rbracket      ("]"),
  arrow         ("->"),
  fnArrow       ("=>"),
  slash         ("/"),
  assign        ("="),
  bang          ("!"),
  question      ("?"),
  amp           ("&"),
  pipe          ("|"),
  nl            ("newline"),

  // misc
  comment("comment"),
  eof("eof");

//////////////////////////////////////////////////////////////////////////
// Constructor
//////////////////////////////////////////////////////////////////////////

  private new make(Str dis, Bool literal := false)
  {
    this.dis  = dis
    this.literal = literal
  }

//////////////////////////////////////////////////////////////////////////
// Identity
//////////////////////////////////////////////////////////////////////////

  ** Get string used to display token to user in error messages
  const Str dis

  ** Does token represent a literal value such as string or date
  const Bool literal

  ** Symbol
  override Str toStr() { dis }

}

