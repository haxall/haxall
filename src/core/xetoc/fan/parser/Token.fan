//
// Copyright (c) 2022, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   13 Aug 2022  Brian Frank  Creation
//

**
** Token type
**
@Js
internal enum class Token
{

  id          ("name"),
  ref         ("ref"),
  scalar      ("scalar"),
  dot         ("."),
  colon       (":"),
  doubleColon ("::"),
  comma       (","),
  lt          ("<"),
  gt          (">"),
  lbrace      ("{"),
  rbrace      ("}"),
  lparen      ("("),
  rparen      (")"),
  lbracket    ("["),
  rbracket    ("]"),
  question    ("?"),
  amp         ("&"),
  pipe        ("|"),
  nl          ("newline"),
  comment     ("comment"),
  eof         ("eof");

  private new make(Str dis)
  {
    this.symbol = dis
    this.dis  = dis.size <= 2 ? "'${dis}' $name" : dis
  }

  const Str dis
  const Str symbol
  override Str toStr() { dis }
}

