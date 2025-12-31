//
// Copyright (c) 2025, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   31 Dec 2025  Brian Frank  New Years Eve!
//

using util
using markdown

**
** DocChapterIndexParser parses index.md into their ordered summary
** We expect index.md to be a specific format of bullet lists:
**
**   # Section Title
**   - [Foo](Foo.md): foo summary
**   - [Bar](Bar.md): bar summary
**
internal class DocChapterIndexParser
{
  new make(DocCompiler c, DocSummary[] origs, FileLoc loc)
  {
    this.compiler = c
    this.origs    = origs
    this.loc      = loc
    this.textRend = TextRenderer()
  }

  DocSummary[] parse(Str markdown)
  {
    try
    {
      return doParse(markdown)
    }
    catch (Err e)
    {
      err("Cannot parseLibIndex", e)
      return origs
    }
  }

  private DocSummary[] doParse(Str markdown)
  {
    // parse markdown into document
    doc := DocMarkdown(markdown).parse

    DocTag[]? tags := null
    acc := DocSummary[,]
    doc.eachChild |node|
    {
      if (node is Heading)
      {
        text := textRend.render(node)
        echo("TODO: heading $text")
        //tags = [DocTag.intern(text)]
      }
      else if (node is ListBlock)
      {
        node.eachChild |ListItem item|
        {
          acc.addNotNull(parseItem(item.firstChild))
        }
      }
    }

    return acc
  }

  private DocSummary? parseItem(Node para)
  {
    // get the link as first node
    link := para.firstChild as Link

    // parse [link]: summary
    text := textRend.render(para)
    colon := text.index(":")
    if (colon != null) text = text[colon+1..-1].trim
    text = text.capitalize

    // if no link report warning
    if (link == null) return warn("Invalid lib index item: $text")

    // find the chapter in originals
    chapterName := link.destination
    if (chapterName.endsWith(".md")) chapterName = chapterName[0..-4]
    orig := origs.find |x| { x.link.uri.name == chapterName }
    if (orig == null) return warn("Unknown chapter name: $chapterName")

    // create new one
    return DocSummary(orig.link, DocMarkdown(text))
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
  private DocSummary[] origs
  private TextRenderer textRend
}

