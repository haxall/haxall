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
internal class DocMarkdownParser : LinkResolver
{

//////////////////////////////////////////////////////////////////////////
// Construction
//////////////////////////////////////////////////////////////////////////

  ** Constructor
  new make(DocCompiler c, DocLinker linker)
  {
    this.compiler = c
    this.linker = linker
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
    sentence := DocUtil.parseFirstSentence(markdown)
    if (sentence.size != markdown.size)
      summary = DocMarkdown(parseToHtml(sentence, false), null)

    return DocMarkdown(html, summary)
  }

  private Str parseToHtml(Str markdown, Bool logWarn)
  {
    this.logWarn = logWarn
    return Xetodoc.toHtml(markdown, this)
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
    doc := parseNode(mdIndex)

    DocTag[]? tags := null
    acc := DocSummary[,]
    doc.eachChild |node|
    {
      if (node is Heading)
      {
        text := textRend.render(node)
        acc.add(DocSummary(DocLink.empty, DocMarkdown(text), [DocTags.heading]))
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
// Link Resolution
//////////////////////////////////////////////////////////////////////////

  override Void resolve(LinkNode linkNode)
  {
    // we only process Link nodes, not Image/Video nodes
    link := linkNode as Link
    if (link == null) return

    orig := link.destination
    try
    {
      // try with standard linker
      res := linker.resolve(orig)

      // if not found then output warning
      if (res == null) return warn("unresolved link [$orig]", loc(link.loc))

      // update link node
      uri := res.uri
      if (link.shortcut) link.setText(res.dis)
      if (compiler.mode.isHtml) uri = DocUtil.htmlUri(linker.uri, uri)
      link.destination = uri.toStr
    }
    catch (Err e)
    {
      warn("link err: $e.toStr [$orig]")
    }
  }

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

  private Obj? warn(Str msg, FileLoc loc := this.loc)
  {
    if (logWarn) compiler.warn(msg, loc)
    return null
  }

  private FileLoc loc(FileLoc? markdownLoc := null)
  {
    linker.loc(markdownLoc)
  }

//////////////////////////////////////////////////////////////////////////
// Fields
//////////////////////////////////////////////////////////////////////////

  private DocCompiler compiler
  private Bool logWarn := true
  private DocLinker linker
}

