//
// Copyright (c) 2024, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   22 Sep 2024  Brian Frank  Creation
//

using util
using xeto
using xetoEnv

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
  }

  private DocSummary genSummary(PageEntry entry)
  {
    link := entry.link
    text := parse(entry.meta["doc"] as Str ?: "")
    return DocSummary(link, text, null, entry.summaryType)
  }

  DocMarkdown parse(Obj? doc)
  {
    if (doc == null || doc == "") return DocMarkdown.empty
    return DocMarkdown(parseFirstSentence(doc.toStr))
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

