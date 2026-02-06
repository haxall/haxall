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
class FixDocs : ConvertCmd
{
  override Str name() { "fix-docs" }

  override Str summary() { "Fix fandoc comments/chapters to xetodoc markdown" }

  @Opt { help = "Preview mode only" }
  Bool preview

  @Arg { help = "Lib names, file names, or dir names to fix" }
  Str[]? targets

  override Int run()
  {
    fixLinks = FixLinks.load

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

    curBase = f.parent.name + "::" + f.name

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
    FixFandoc(curBase, curLoc, lines, fixLinks).fix
  }

//////////////////////////////////////////////////////////////////////////
// Fields
//////////////////////////////////////////////////////////////////////////

  Str? curBase
  FileLoc curLoc := FileLoc.unknown
  FixLinks? fixLinks
}

