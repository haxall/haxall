//
// Copyright (c) 2024, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   22 Sep 2024  Brian Frank  Creation
//

using markdown
using xml

**
** DocMarkdown is a block of text originally formatted in markdown
** and converted to normalized HTML at compilation time
**
@Js
const class DocMarkdown
{
  ** Empty string
  static const DocMarkdown empty := make("")

  ** Constructor for plain text
  static DocMarkdown makePlain(Str plain)
  {
    make("<p>$plain.toXml</p>")
  }

  ** Constructor
  new make(Str html, DocMarkdown? summary := null)
  {
    this.html = html
    this.summary = summary ?: this
  }

  ** Normalized HTML
  const Str html

  ** Is this the empty string
  Bool isEmpty() { html.isEmpty }

  ** Debug string
  override Str toStr() { html }

  ** Encode to JSON as string literal
  Obj encode() { html }

  ** Decode from JSON string literal
  static DocMarkdown decode(Obj? obj)
  {
    if (obj == null) return empty
    return DocMarkdown(obj.toStr, null)
  }

  ** Summary is first sentence of the text
  const DocMarkdown summary

}

