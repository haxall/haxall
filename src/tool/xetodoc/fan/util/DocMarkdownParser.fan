//
// Copyright (c) 2026, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   31 Dec 2025  Brian Frank  New Years Eve!
//

using util
using markdown

**
** DocMarkdownParser is used to parse Xetodoc markdown, resolve
** all link shortcuts, and then output normalized HTML.
**
internal class DocMarkdownParser
{
  ** Constructor
  new make(DocCompiler c, FileLoc loc)
  {
    this.compiler = c
    this.loc      = loc
  }

//////////////////////////////////////////////////////////////////////////
// DocMarkdown
//////////////////////////////////////////////////////////////////////////

  ** Parse into DocMarkdown with summary
  DocMarkdown parseDocMarkdown(Str markdown)
  {
    // parse the whole thing
    html := parseToHtml(markdown, true)

    // check if we should parse just first sentence as summary
    summary := null
    sentence := parseFirstSentence(markdown)
    if (sentence.size != markdown.size)
      summary = DocMarkdown(parseToHtml(sentence, false), null)

    return DocMarkdown(html, summary)
  }

  private Str parseToHtml(Str markdown, Bool logWarns)
  {
    Xetodoc.toHtml(markdown, null)
  }

  static Str parseFirstSentence(Str s)
  {
    // this logic isn't exactly like firstSentence because we clip at colon
    if (s.isEmpty) return ""

    semicolon := s.index(";")
    if (semicolon != null) s = s[0..<semicolon]

    colon := s.index(":")
    while (colon != null && colon + 1 < s.size && !s[colon+1].isSpace)
      colon = s.index(":", colon+1)
    if (colon != null) s = s[0..<colon]

    period := s.index(".")
    while (period != null && period + 1 < s.size && !s[period+1].isSpace)
      period = s.index(".", period+1)
    if (period != null) s = s[0..<period]

    return s
  }

//////////////////////////////////////////////////////////////////////////
// Chapter Summaries
//////////////////////////////////////////////////////////////////////////

  **
  ** Parse index.md into its ordered summary, we expect specific format:
  **
  **   # Section Title
  **   - [Foo](Foo.md): foo summary
  **   - [Bar](Bar.md): bar summary
  **
  DocSummary[] parseChapterIndex(DocSummary[] origs, Str? mdIndex)
  {
    try
    {
      if (mdIndex != null) return doParseChapterIndex(origs, mdIndex)
    }
    catch (Err e)
    {
      err("Cannot parseLibIndex", e)
    }
    return missingChapterIndex(origs)
  }

  private DocSummary[] missingChapterIndex(DocSummary[] origs)
  {
    // if missing index (or error), then set summaries to empty string
    origs.map |x->DocSummary| { DocSummary(x.link, DocMarkdown.empty, x.tags) }
  }

  private DocSummary[] doParseChapterIndex(DocSummary[] origs, Str mdIndex)
  {
    // parse markdown into document
    doc := DocMarkdownParser(compiler, loc).parseNode(mdIndex)

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
          acc.addNotNull(parseChapterItem(origs, item.firstChild))
        }
      }
    }

    return acc
  }

  private DocSummary? parseChapterItem(DocSummary[] origs, Node para)
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

  private once TextRenderer textRend() { TextRenderer() }

//////////////////////////////////////////////////////////////////////////
// Utils
//////////////////////////////////////////////////////////////////////////

  private Node parseNode(Str markdown)
  {
    Parser.builder.build.parse(markdown)
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

//////////////////////////////////////////////////////////////////////////
// Fields
//////////////////////////////////////////////////////////////////////////

  private DocCompiler compiler
  private FileLoc loc
}

