//
// Copyright (c) 2024, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   22 Sep 2024  Brian Frank  Creation
//

using markdown

**
** DocMarkdown is a block of text formatted in markdown.
**
@Js
const class DocMarkdown
{
  ** Empty string
  static const DocMarkdown empty := make("")

  ** Constructor
  new make(Str text) { this.text = text }

  ** Raw markdown text
  const Str text

  ** Debug string
  override Str toStr() { text }

  ** Get the summary first sentence of this text
  DocMarkdown summary()
  {
    summary := parseFirstSentence(text)
    if (summary.size == text.size) return this
    return make(summary)
  }

  ** Encode to JSON as string literal
  Obj encode()
  {
    text
  }

  ** Decode from JSON string literal
  static DocMarkdown decode(Obj? obj)
  {
    if (obj == null) return empty
    return DocMarkdown(obj.toStr)
  }

  ** Return this text as HTML
  Str html()
  {
    doc := Parser.builder.build.parse(text)
    return HtmlRenderer.builder.build.render(doc)
  }

  static Str parseFirstSentence(Str t)
  {
    // this logic isn't exactly like firstSentence because we clip at colon
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

