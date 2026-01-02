//
// Copyright (c) 2026, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   2 Jan 2026  Brian Frank  Creation
//

using util
using markdown

**
** DocMarkdownParser is used to parse Xetodoc markdown, resolve
** all link shortcuts, and then output normalized HTML.
**
internal class DocMarkdownParser
{
  new make(DocCompiler c, FileLoc loc)
  {
    this.compiler = c
    this.loc      = loc
  }

  ** Parse into DocMarkdown with summary
  DocMarkdown parse(Str markdown)
  {
    html := parseToHtml(markdown, true)

    summary := null
    sentence := parseFirstSentence(markdown)
    if (sentence.size != markdown.size)
      summary = DocMarkdown(parseToHtml(sentence, false), null)

    return DocMarkdown(html, summary)
  }

  ** Parse into markdown DOM
  Node parseNode(Str markdown)
  {
    Parser.builder.build.parse(markdown)
  }

  ** Parse markdown to HTML
  Str parseToHtml(Str markdown, Bool logWarns)
  {
    Xetodoc.toHtml(markdown, null)
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

  private Void err(Str msg, Err e)
  {
    compiler.err(msg, loc, e)
  }

  private Obj? warn(Str msg)
  {
    compiler.warn(msg, loc)
    return null
  }

  private DocCompiler compiler
  private FileLoc loc
}

