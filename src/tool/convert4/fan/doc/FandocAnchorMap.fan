//
// Copyright (c) 2026, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   5 Jan 2026  Brian Frank  Creation
//

using util
using xeto
using markdown

**
** FandocAnchorMap is a one-time utility to generate a section anchor map
** for all the common manuals (docHaystack, docHaxall, etc) into a text
** file we can use for conversion tools.
**
class FandocAnchorMap
{

//////////////////////////////////////////////////////////////////////////
// Generator
//////////////////////////////////////////////////////////////////////////

  ** Generate (must call from sf-misc)
  static Void gen()
  {
    acc := Str:Str[:]
    Env.cur.path.each |pathDir|
    {
      (pathDir + `src/`).walk |x|
      {
        if (x.isDir && x.name.size > 4 && x.name.startsWith("doc") &&
            x.name[3].isUpper && x.plus(`build.fan`).exists)
        {
          podName := x.name
          if (podName == "docXeto" || podName == "docOEM" || podName == "docCloud") return
          x.walk |f| { if (f.ext == "fandoc") genFile(acc, podName, f) }
        }
      }
    }

    keys := acc.keys.sort
    keys.each |k| { echo("$k=" + acc[k]) }
  }

  static Void genFile(Str:Str acc, Str podName, File f)
  {
    qname := podName + "::" + f.basename
    lines := f.readAllLines
    header := true
    proc := HeadingProcessor()
    lines.each |line, i|
    {
      if (header)
      {
        if (line.trim.isEmpty) header = false
        else return
      }

      if (line.startsWith("##") || line.startsWith("**") ||
          line.startsWith("==") || line.startsWith("--"))
      {
        if (i - 1 < 0) return
        prev := lines[i-1].trim
        if (prev.isEmpty) return

        x := prev.index("[#")
        if (x == null) return
        id := prev[x+2..-2]

        text := prev[0..<x].trim
        key := qname + "#" + id

        to := proc.toAnchor(text)

        acc[key] = to
      }
    }
  }

}

