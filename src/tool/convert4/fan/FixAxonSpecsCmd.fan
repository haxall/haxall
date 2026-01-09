//
// Copyright (c) 2026, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   9 Jan 2026  Brian Frank  Creation
//

using util

**
** This utility will strip the params and leave the do block to handle
** the case of 4.0.4 -> 4.0.5.  But it does **not** fix the param defaults
** to move them into the spec, so its only works partially. The best solution
** is to rerun the ext conversion from trio.
**
internal class FixAxonSpecsCmd : ConvertCmd
{
  override Str name() { "fix-axon-specs" }

  override Str summary() { "Fix axon tag in func specs to remove params and store just body" }

  @Opt { help = "Just show files" }
  Bool showFiles

  @Opt { help = "Preview mode only" }
  Bool preview

  @Arg { help = "Dirs to run looking for *.xeto that contain 'axon:---'" }
  Str[]? dirs

  override Int run()
  {
    files := File[,]
    if (dirs == null) return usage
    dirs.each |dir| { findFiles(files, dir.toUri.plusSlash.toFile) }

    files.each |f|
    {
      try
        fixFile(f)
      catch (Err e)
        Console.cur.err("ERROR: cannot fix file [$f.osPath]", e)
    }
    return 0
  }

  Void fixFile(File f)
  {
    oldLines := f.readAllLines
    newLines := Str[,]
    fixCount := 0
    for (i := 0; i<oldLines.size; ++i)
    {
      line := oldLines[i]
      newLines.add(line)

      if (!line.trim.startsWith("<axon:---")) continue

      fixCount++

      // find axon
      s := i+1
      e := i+2
      while (!oldLines[e].contains("--->")) e++
      i = e-1
      src := oldLines[s..<e].join("\n")

      // fix it and insert re-written lines
      fixAxon(src).splitLines.each |x| { newLines.add(x) }
    }

    if (fixCount == 0) return

    echo("Fixed $fixCount funcs [$f.osPath]")

    if (showFiles) return

    if (preview)
    {
      echo(newLines.join("\n"))
    }
    else
    {
      f.out.print(newLines.join("\n")).close
    }
  }

  Str fixAxon(Str orig)
  {
    // find indent to keep keep do aligned
    indent := 8
    orig.splitLines.each |line|
    {
      if (line.trim.isEmpty) return
      lineIndent := 0
      while (lineIndent < line.size && line[lineIndent].isSpace) lineIndent++
      indent = indent.min(lineIndent)
    }

    // split on => operator
    arrow := orig.index("=>") ?: throw Err("Missing =>")
    body := Str.spaces(indent) + orig[arrow+2..-1].trim

    /*
    echo
    echo("########## indent=$indent")
    echo(orig)

    echo("----------")
    echo(body)
    */

    return body
  }

  Void findFiles(File[] acc, File f)
  {
    if (f.name == "lib.xeto") return
    if (f.ext == "xeto") acc.add(f)
    if (f.isDir) f.list.each |kid| { findFiles(acc, kid) }
  }
}

