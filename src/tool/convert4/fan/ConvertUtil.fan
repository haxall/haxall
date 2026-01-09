//
// Copyright (c) 2026, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   9 Jan 2026  Brian Frank  Creation
//

using util

const class ConvertUtil
{
   ** Find min indentation in block of code
   static Int indentation(Str src)
   {
    indent := -1
    src.splitLines.each |line|
    {
      if (line.trim.isEmpty) return
      lineIndent := 0
      while (lineIndent < line.size && line[lineIndent].isSpace) lineIndent++
      indent = indent < 0 ? lineIndent : indent.min(lineIndent)
    }
    return indent
  }

  ** Find min indentatation and move every line to the left that many spaces
  static Str removeIndentation(Str src)
  {
    indent := indentation(src)
    if (indent <= 0) return src
    return src.splitLines.map |s->Str|
    {
      if (s.trimToNull == null) return ""
      else return s[indent..-1]
    }.join("\n")
  }
}

