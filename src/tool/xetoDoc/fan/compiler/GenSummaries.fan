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
** Generate summaries for every top-level node indexed by qname
**
internal class GenSummaries : Step
{
  override Void run()
  {
    acc := Str:DocSummary[:]
    eachLib |lib|
    {
      // lib summary
      acc.add(lib.name, libSummary(lib))

      // types summary
      lib.types.each |x|
      {
        acc.add(x.qname, specSummary(x))
      }

      // globals ids
      lib.globals.each |x|
      {
        acc.add(x.qname, specSummary(x))
      }

      // instances summary
      lib.instances.each |x|
      {
        acc.add(x._id.id, instanceSummary(x))
      }
    }
    compiler.summaries = acc
  }

  DocSummary libSummary(Lib x)
  {
    link := id(x.name).link
    text := parse(x.meta["doc"])
    return DocSummary(link, text)
  }

  DocSummary specSummary(Spec x)
  {
    link := id(x.qname).link
    text := parse(x.meta["doc"])
    return DocSummary(link, text)
  }

  DocSummary instanceSummary(Dict x)
  {
    link := id(x._id.id).link
    text := parse(x["doc"])
    return DocSummary(link, text)
  }

  DocBlock parse(Obj? doc)
  {
    if (doc == null || doc == "") return DocBlock.empty
    return DocBlock(parseFirstSentence(doc.toStr))
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

