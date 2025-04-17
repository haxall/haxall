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
    return DocMarkdown(doc.toStr).summary
  }


}

