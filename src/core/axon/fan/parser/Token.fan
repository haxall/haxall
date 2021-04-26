//
// Copyright (c) 2009, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   29 Aug 2009  Brian Frank  Creation
//

**
** Token types for Axon grammar.
**
@NoDoc @Js
enum class Token
{

//////////////////////////////////////////////////////////////////////////
// Enum
//////////////////////////////////////////////////////////////////////////

  // identifer/literals
  id  ("identifier"),
  val ("value"),

  // operators
  colon         (":"),
  doubleColon   ("::"),
  dot           ("."),
  semicolon     (";"),
  comma         (","),
  plus          ("+"),
  minus         ("-"),
  star          ("*"),
  slash         ("/"),
  bang          ("!"),
  caret         ("^"),
  assign        ("="),
  fnEq          ("=>"),
  eq            ("=="),
  notEq         ("!="),
  lt            ("<"),
  ltEq          ("<="),
  gt            (">"),
  gtEq          (">="),
  cmp           ("<=>"),
  lbrace        ("{"),
  rbrace        ("}"),
  lparen        ("("),
  rparen        (")"),
  lbracket      ("["),
  rbracket      ("]"),
  pipe          ("|"),
  underbar      ("_"),
  arrow         ("->"),
  dotDot        (".."),

  // keywords
  andKeyword,
  catchKeyword,
  defcompKeyword,
  deflinksKeyword,
  doKeyword,
  elseKeyword,
  endKeyword,
  falseKeyword,
  ifKeyword,
  notKeyword,
  nullKeyword,
  orKeyword,
  returnKeyword,
  throwKeyword,
  trueKeyword,
  tryKeyword,

  // misc
  eof("eof");

//////////////////////////////////////////////////////////////////////////
// Constructor
//////////////////////////////////////////////////////////////////////////

  **
  ** Construct with symbol str, or null symbol for keyword.
  **
  private new make(Str? symbol := null)
  {
    if (symbol == null)
    {
      if (!name.endsWith("Keyword")) throw Err(name)
      this.symbol  = name[0..-8]
      this.keyword = true
    }
    else
    {
      this.symbol  = symbol
      this.keyword = false
    }
  }

//////////////////////////////////////////////////////////////////////////
// Methods
//////////////////////////////////////////////////////////////////////////

  override Str toStr() { return symbol }

//////////////////////////////////////////////////////////////////////////
// Keyword Lookup
//////////////////////////////////////////////////////////////////////////

  ** Return if given string is a keyword
  static Bool isKeyword(Str val) { keywords[val] != null }

  ** Get a map of the keywords
  const static Str:Token keywords
  static
  {
    map := Str:Token[:]
    vals.each |tok|
    {
      if (tok.keyword) map[tok.symbol] = tok
    }
    keywords = map
  }

//////////////////////////////////////////////////////////////////////////
// Fields
//////////////////////////////////////////////////////////////////////////

  ** Get string used to display token to user in error messages
  const Str symbol

  ** Is this a keyword token such as "null"
  const Bool keyword
}