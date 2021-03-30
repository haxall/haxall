//
// Copyright (c) 2018, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   11 Jun 2018  Brian Frank  Creation
//

using fandoc
using compilerDoc

**
** Documentation markdown/fandoc text
**
const class CFandoc : DocFandoc
{
  static const CFandoc none := CFandoc(CLoc.none, "")

  new make(CLoc loc, Str text) : super(loc, text) {}

  new wrap(DocFandoc d) : super.make(CLoc(d.loc.file, d.loc.line), d.text) {}

  Bool isEmpty() { text.isEmpty }

  override Str toStr() { text }

  CFandoc toSummary() { CFandoc(loc, summary) }

  Str summary()
  {
    // this logic isn't exactly like firstSentence because we clip at colon
    t := this.text
    if (t.isEmpty) return ""

    semicolon := t.index(";")
    if (semicolon != null) t = t[0..<semicolon]

    colon := t.index(":")
    while (colon != null && colon + 1 < t.size && !t[colon+1].isSpace)
      colon = t.index(":", colon+1)
    if (colon != null) t = t[0..<colon]

    period := t.index(".")
    while (period != null && period + 1 < t.size && !t[period+1].isSpace)
      period = t.index(".", period+1)
    if (period != null) t = t[0..<period]

    return t
  }
}

