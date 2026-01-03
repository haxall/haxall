//
// Copyright (c) 2026, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   3 Jan 2026  Brian Frank  Creation
//

using util
using xeto
using fandoc
using fandoc::Link

**
** FixFandoc converts a blocks of fandoc lines into xeto flavored markdown.
** We use a line-by-line approach that attempts to maintain the original
** formatting as close as possible.
**
class FixFandoc
{

  new make(FileLoc loc, Str[] lines)
  {
    this.loc   = loc
    this.lines = lines
    this.types = FandocParser().parseLineTypes(lines)
  }

  Str[] fix()
  {
    lines.map |line, i|
    {
      linei = i
      return fixLine(line, types[i])
    }
  }

//////////////////////////////////////////////////////////////////////////
// Block Lines
//////////////////////////////////////////////////////////////////////////

  private Str fixLine(Str line, LineType type)
  {
    // if in pre> mode
    curIndent := indent(line)
    if (mode === FixFandocMode.preBlock)
    {
      if (type === LineType.preEnd)
      {
        mode = FixFandocMode.norm
        return "```"
      }
      return line
    }

    // if in indented pre mode
    if (mode === FixFandocMode.preIndent)
    {
      if (curIndent >= modeIndent) return "  " + line
    }

    // if in list mode
    if (mode === FixFandocMode.list && type === LineType.normal)
    {
      if (curIndent >= modeIndent) return line
    }

    // reset mode back to normal
    mode = FixFandocMode.norm
    modeIndent = 0

    // process by line type
    switch (type)
    {
      case LineType.blank:      return ""
      case LineType.ul:         return fixList(line, curIndent)
      case LineType.ol:         return fixList(line, curIndent)
      case LineType.h1:         return fixHeading(line, "#")
      case LineType.h2:         return fixHeading(line, "##")
      case LineType.h3:         return fixHeading(line, "###")
      case LineType.h4:         return fixHeading(line, "####")
      case LineType.blockquote: return line
      case LineType.hr:         return line
      case LineType.preStart:   return fixPreStart
      case LineType.normal:     return fixNorm(line, curIndent)
      default:                  throw Err(type.name)
    }
  }

  private Str fixHeading(Str line, Str prefix)
  {
    // TODO
    return line
  }

  private Str fixList(Str line, Int curIndent)
  {
    mode = FixFandocMode.list
    modeIndent = curIndent
    return line
  }

  private Str fixPreStart()
  {
    mode = FixFandocMode.preBlock
    return "```"
  }

  private Str fixNorm(Str line, Int curIndent)
  {
    if (curIndent >= 2)
    {
      mode = FixFandocMode.preIndent
      modeIndent = curIndent
      return "  " + line
    }
    else
    {
      return fixInline(line)
    }
  }

//////////////////////////////////////////////////////////////////////////
// Inline
//////////////////////////////////////////////////////////////////////////

  private Str fixInline(Str line)
  {
    loc := FileLoc(this.loc.file, this.loc.line + this.linei)
    try
    {
      buf := StrBuf(line.size)
      doc := FandocParser().parse(loc.toStr, line.in)
      fixNode(doc, buf)
      return buf.toStr
    }
    catch (Err e)
    {
      echo("ERROR: $loc\n  $e")
    }
    return line
  }

  private Void fixNode(DocNode n, StrBuf buf)
  {
    switch (n.id)
    {
      case DocNodeId.text:     buf.add(n.toText)

      case DocNodeId.emphasis: fixElem(n, buf, "*")
      case DocNodeId.strong:   fixElem(n, buf, "**")
      case DocNodeId.code:     fixElem(n, buf, "`")

      case DocNodeId.link:     fixLink(n, buf)
      case DocNodeId.image:    fixImage(n, buf)

      case DocNodeId.para:     fixElem(n, buf)
      case DocNodeId.doc:      fixElem(n, buf)
      default: throw Err("TODO: $n.id $n")
    }
  }

  private Void fixElem(DocElem n, StrBuf buf, Str? wrap := null)
  {
    if (wrap != null) buf.add(wrap)
    n.children.each |kid| { fixNode(kid, buf) }
    if (wrap != null) buf.add(wrap)
  }

  private Void fixLink(Link n, StrBuf buf)
  {
    text := n.toText
    uri := n.uri
    if (text == uri)
      buf.add("[").add(uri).add("]")
    else
      buf.add("[").add(text).add("](").add(uri).add(")")
  }

  private Void fixImage(Image n, StrBuf buf)
  {
    text := n.toText
    uri := n.uri
    buf.add("![").add(text).add("](").add(uri).add(")")
  }

//////////////////////////////////////////////////////////////////////////
// Utils
//////////////////////////////////////////////////////////////////////////

  private static Int indent(Str line)
  {
    i := 0
    while (i < line.size && line[i].isSpace) ++i
    return i
  }

//////////////////////////////////////////////////////////////////////////
// Fields
//////////////////////////////////////////////////////////////////////////

  private FileLoc loc
  private Str[] lines
  private LineType[] types
  private Int linei
  private FixFandocMode mode := FixFandocMode.norm
  private Int modeIndent
}

**************************************************************************
** FixFandocMode
**************************************************************************

internal enum class FixFandocMode { norm, list, preIndent, preBlock }

