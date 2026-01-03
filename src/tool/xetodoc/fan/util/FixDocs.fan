//
// Copyright (c) 2026, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   3 Jan 2026  Brian Frank  Creation
//

using concurrent
using util
using xeto
using fandoc
using fandoc::Link

**
** FixDocs is a command line program to update Fandoc docs to Xetodocs.
**
class FixDocs : AbstractMain
{
  @Opt { help = "Preview mode only" }
  Bool preview

  @Arg { help = "Lib names, file names, or dir names to fix" }
  Str[]? targets

  override Int run()
  {
    if (targets == null || targets.isEmpty)
    {
      echo("No targets specified")
      return 1
    }

    targets.each |target| { fix(target) }
    return 0
  }

//////////////////////////////////////////////////////////////////////////
// Targets
//////////////////////////////////////////////////////////////////////////

  Void fix(Str target)
  {
    f := File(target.toUri, false)
    if (f.exists) return fixFile(f)

    lib := XetoEnv.cur.repo.latest(target, false)
    if (lib != null && lib.isSrc) return fixFile(lib.file)

    echo("ERROR: target not found: $target")
  }

  Void fixFile(File f)
  {
    if (f.isDir)
    {
      f.list.each |kid| { fixFile(kid) }
      return
    }

    if (f.ext == "xeto") return fixXeto(f)
  }

  Void rewrite(File f, Str[] lines)
  {
    if (preview)
    {
      echo(lines.join("\n"))
      return
    }
    else
    {
      //echo("TOOD: rewrite $f")
    }
  }

//////////////////////////////////////////////////////////////////////////
// Xeto source slash-slash comments
//////////////////////////////////////////////////////////////////////////

  Void fixXeto(File f)
  {
    echo("Fix [$f.osPath]")

    // process slash-slash comments from fandoc -> xeto flavored markdown
    oldLines := f.readAllLines
    newLines := Str[,] { it.capacity = oldLines.size }
    header := false
    for (i := 0; i<oldLines.size; ++i)
    {
      // look for // comment
      line := oldLines[i]
      ss := line.index("//")
      if (ss == null)
      {
        header = false
        newLines.add(line)
        continue
      }

      // if in header don't fix comments
      if (i == 0) header = true
      if (header) { newLines.add(line); continue }

      // if end of line, then process it as as single-line
      this.curLoc = FileLoc(f.osPath, i+1)
      if (!line.trimStart.startsWith("//"))
      {
        comment := slashSlashComment(line, ss)
        newLine := line[0..<ss] + "// " + fixSlashSlashDoc([comment]).first
        newLines.add(newLine)
        continue
      }

      // process block of comments
      block := Str[,]
      block.add(slashSlashComment(line, ss))
      prefix := line[0..ss+1]
      while (i+1 < oldLines.size && oldLines[i+1].startsWith(prefix))
      {
        i++
        block.add(slashSlashComment(oldLines[i], ss))
      }
      fixSlashSlashDoc(block).each |newLine|
      {
        newLines.add(prefix + " " + newLine)
      }
    }

    // rewrite the file
    rewrite(f, newLines)
  }

  Str slashSlashComment(Str line, Int ss)
  {
    // handle both "// xx" and "//xx"
    if (ss+2 < line.size && line[ss+2] == ' ')
      return line[ss+3..-1]
    else
      return line[ss+2..-1]
  }

  Str[] fixSlashSlashDoc(Str[] lines)
  {
    // fix line-by-line to maintain original formatting
    mode := AtomicInt()
    prevWasCode := AtomicBool()
    prevListStart := AtomicInt()
    return lines.map |line|
    {
      fixFandocLine(line, mode, prevWasCode, prevListStart)
    }
  }

//////////////////////////////////////////////////////////////////////////
// Fandoc Block
//////////////////////////////////////////////////////////////////////////

  Str? fixFandocLine(Str line, AtomicInt mode, AtomicBool prevWasCode, AtomicInt prevListStart)
  {
    // handle special modes
    if (mode.val == modePre)
    {
      if (line.trim == "<pre") { mode.val = modeNorm; return "```" }
      return line
    }

    // if previous was not code block and line starts with - or xx. then treat as list
    if (!prevWasCode.val)
    {
      listStart := listPreStartIndex(line)
      if (listStart != -1)
      {
        prevListStart.val = listStart
        return line[0..listStart] + " " + fixFandocInline(line[listStart+1..-1].trimStart)
      }
    }

    // need to handle indented lists vs pre code block
    prevWasCode.val = false
    if (line.startsWith("  "))
    {
      prevWasCode.val = true; return "  " + line
    }

    // normalize block level lines
    if (line.startsWith("---")) return line
    if (line.startsWith("> ")) return line
    if (line.startsWith("pre>")) { mode.val = modePre; return "```" }

    // process as in-line
    return fixFandocInline(line)
  }

  Int? listPreStartIndex(Str line)
  {
    // skip spaces
    i := 0
    while (i+1 < line.size && line[i].isSpace) ++i
    if (i+2 >= line.size) return -1

    // dash for unordered list
    if (line[i] == '-' && line[i+1] == ' ') return i

    // letter+digit + "."
    dot := line.index(".", i+1)
    if (dot != null)
    {
      num := line[i..<dot]
      if (num.size <= 3 && num.all { it.isAlphaNum }) return dot
    }

    return -1
  }

  static const Int modeNorm  := 0  // normal mode
  static const Int modePre   := 1  // pre> mode

//////////////////////////////////////////////////////////////////////////
// Fandoc Inline
//////////////////////////////////////////////////////////////////////////

  Str fixFandocInline(Str line)
  {
    try
    {
      buf := StrBuf(line.size)
      doc := FandocParser().parse(curLoc.toStr, line.in)
      fixFandocNode(doc, buf)
      return buf.toStr
    }
    catch (Err e)
    {
      echo("ERROR: $curLoc\n  $e")
    }
    return line
  }

  Void fixFandocNode(DocNode n, StrBuf buf)
  {
    switch (n.id)
    {
      case DocNodeId.text:     buf.add(n.toText)

      case DocNodeId.emphasis: fixFandocElem(n, buf, "*")
      case DocNodeId.strong:   fixFandocElem(n, buf, "**")
      case DocNodeId.code:     fixFandocElem(n, buf, "`")

      case DocNodeId.link:     fixFandocLink(n, buf)
      case DocNodeId.image:    fixFandocImage(n, buf)

      case DocNodeId.para:     fixFandocElem(n, buf)
      case DocNodeId.doc:      fixFandocElem(n, buf)
      default: throw Err("TODO: $n.id $n")
    }
  }

  Void fixFandocElem(DocElem n, StrBuf buf, Str? wrap := null)
  {
    if (wrap != null) buf.add(wrap)
    n.children.each |kid| { fixFandocNode(kid, buf) }
    if (wrap != null) buf.add(wrap)
  }

  Void fixFandocLink(Link n, StrBuf buf)
  {
    text := n.toText
    uri := n.uri
    if (text == uri)
      buf.add("[").add(uri).add("]")
    else
      buf.add("[").add(text).add("](").add(uri).add(")")
  }

  Void fixFandocImage(Image n, StrBuf buf)
  {
    text := n.toText
    uri := n.uri
    buf.add("![").add(text).add("](").add(uri).add(")")
  }

//////////////////////////////////////////////////////////////////////////
// Fields
//////////////////////////////////////////////////////////////////////////

  FileLoc curLoc := FileLoc.unknown
}

