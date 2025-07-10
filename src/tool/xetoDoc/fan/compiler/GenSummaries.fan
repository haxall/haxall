//
// Copyright (c) 2024, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   22 Sep 2024  Brian Frank  Creation
//

using util
using markdown
using markdown::Link
using xeto
using xetom

**
** Generate summaries for every page
**
internal class GenSummaries : Step
{
  override Void run()
  {
    eachPage |entry|
    {
      entry.summaryRef = genSummary(entry)
    }

    eachLib |entry|
    {
      parseLibIndex(entry)
    }
  }

  private DocSummary genSummary(PageEntry entry)
  {
    link := entry.link
    text := parse(entry.meta["doc"] as Str ?: "")
    return DocSummary(link, text, null, entry.summaryType)
  }

  private DocMarkdown parse(Obj? doc)
  {
    if (doc == null || doc == "") return DocMarkdown.empty
    return DocMarkdown(doc.toStr).summary
  }

  private Void parseLibIndex(PageEntry entry)
  {
    if (entry.mdIndex == null) return

    lib := entry.lib
    loc := FileLoc("$entry.key index.md")
    try
    {
      //
      // we expect index.md to be a specific format of bullet lists:
      //
      // # Section Title
      // - [Foo](Foo.md): foo summary
      // - [Bar](Bar.md): bar summary
      //
      doc := entry.mdIndex.parse
      DocTag[]? tags := null
      order := 0
      doc.eachChild |node|
      {
        if (node is Heading)
        {
          text := textRend.render(node)
          tags = [DocTag.intern(text)]
        }
        else if (node is ListBlock)
        {
          node.eachChild |ListItem item|
          {
            parseLibIndexItem(lib, tags, item.firstChild, loc, order++)
          }
        }
      }
    }
    catch (Err e)
    {
      err("Cannot parseLibIndex", loc, e)
    }
  }

  private Void parseLibIndexItem(Lib lib, DocTag[]? tags, Node para, FileLoc loc, Int order)
  {
    // get the link as first node
    link := para.firstChild as Link

    // parse [link]: summary
    text := textRend.render(para)
    colon := text.index(":")
    if (colon != null) text = text[colon+1..-1].trim
    text = text.capitalize

    // if no link report warning
    if (link == null) return compiler.warn("Invalid lib index item: $text", loc)

    // find the chapter
    chapterName := link.destination
    if (chapterName.endsWith(".md")) chapterName = chapterName[0..-4]
    chapter := this.chapter(lib, chapterName)
    if (chapter == null) return compiler.warn("Unknown chapter name: $chapterName", loc)

    // set chapter summary
    chapter.summaryRef = DocSummary(chapter.summary.link, DocMarkdown(text), tags)
    chapter.order = order
  }

  private TextRenderer textRend := TextRenderer()
}

