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
}

