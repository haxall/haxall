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
  static Str convertFandocFile(Str base, File fandocFile, FixLinks? fixLinks)
  {
    oldLines := fandocFile.readAllLines

    comment := Str[,]
    while (oldLines.first.startsWith("**"))
    {
      line := oldLines.removeAt(0).trimStart
      while (!line.isEmpty && line[0] == '*') line = line[1..-1]
      line = line.trim
      if (!line.isEmpty) comment.add(line)
    }

    newLines := make(base, FileLoc(fandocFile), oldLines, fixLinks).fix

    vimeoLine := comment.find |line| { line.startsWith("vimeo") }
    if (vimeoLine != null)
    {
      // create line to show vimeo video
      id := vimeoLine.split(':').last
      if (id.contains("/")) id = id.split('/').last
      videoLink := "![Video](video://vimeo/${id})"

      // find heading
      idx := newLines.findIndex { it.startsWith("#") } ?: 1
      newLines.insertAll(idx, [videoLink, ""])
    }

    if (!comment.isEmpty)
    {
      comment.insert(0, "<!--")
      comment.add("-->")
      newLines.insertAll(0, comment)
    }

    return newLines.join("\n")
  }

  new make(Str base, FileLoc loc, Str[] lines, FixLinks? fixLinks)
  {
    this.base     = base
    this.loc      = loc
    this.lines    = lines
    this.types    = FandocParser().parseLineTypes(lines)
    this.fixLinks = fixLinks
  }

  Str[] fix()
  {
    acc := Str[,]
    acc.capacity = lines.size

    lastCodeIndent := false
    for (i := 0; i<lines.size; ++i)
    {
      linei = i
      line := lines[i]
      type := types[i]

      // check for headers which apply line above (we assume
      // all headings are two lines as they are in docHaxall, etc)
      if (i+1 < types.size && types[i+1].isHeading)
      {
        acc.add(fixHeading(line, types[i+1].headingLevel))
        i++
      }
      else
      {
        // ensure code indentation is preceded/followed by blank line
        newLine := fixLine(line, type)
        newIsCodeIndent := mode == FixFandocMode.preIndent
        if (newIsCodeIndent && !isBlank(acc.last) && !lastCodeIndent) acc.add("")
        if (lastCodeIndent && !newIsCodeIndent && !isBlank(newLine)) acc.add("")
        lastCodeIndent = newIsCodeIndent

        acc.add(newLine)
      }
    }

    return acc
  }

  private Bool isBlank(Str? line) { line?.trimToNull == null }

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
      case LineType.ul:         return fixList(line, curIndent, "-")
      case LineType.ol:         return fixList(line, curIndent, ".")
      case LineType.blockquote: return line
      case LineType.hr:         return line
      case LineType.preStart:   return fixPreStart
      case LineType.normal:     return fixNorm(line, curIndent)
      default:                  throw Err("$type.name: $line")
    }
  }

  private Str fixHeading(Str line, Int level)
  {
    // strip [#anchor] - we now use title itself like github
    i := line.index("[#")
    if (i != null) line = line[0..<i].trim

    // in chapters have been using h2 *** as top-level headings;
    // but we want to fix that to be h1
    level = (level - 1).clamp(1, 4)

    // assume line is plain text
    s := StrBuf()
    level.times { s.addChar('#') }
    s.add(" ").add(line.trim)
    return s.toStr
  }

  private Str fixList(Str line, Int curIndent, Str sep)
  {
    mode = FixFandocMode.list
    modeIndent = curIndent

    i := line.index(sep) ?: throw Err("Missing sep $sep - $line")
    prefix := line[0..i]
    rest := line[i+1..-1].trimStart

    rest = fixInline(rest)
    return prefix + " " + rest
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
      parser := FandocParser()
      parser.parseHeader = false
      doc := parser.parse(loc.toStr, line.in)
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
      case DocNodeId.doc:      fixElem(n, buf)

      case DocNodeId.text:     buf.add(n.toText)

      case DocNodeId.emphasis: fixElem(n, buf, "*")
      case DocNodeId.strong:   fixElem(n, buf, "**")
      case DocNodeId.code:     fixElem(n, buf, "`")

      case DocNodeId.link:     fixLink(n, buf)
      case DocNodeId.image:    fixImage(n, buf)

      case DocNodeId.para:
        a := ((Para)n).admonition
        if (a != null) buf.add(a).add(": ") // this will occur on lines starting with TODO:
        fixElem(n, buf)

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

    if (fixLinks != null) uri = fixLinks.fix(base, uri)

    if (text == n.uri)
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

  private Str base
  private FileLoc loc
  private Str[] lines
  private LineType[] types
  private Int linei
  private FixFandocMode mode := FixFandocMode.norm
  private Int modeIndent
  private FixLinks? fixLinks
}

**************************************************************************
** FixFandocMode
**************************************************************************

internal enum class FixFandocMode { norm, list, preIndent, preBlock }

