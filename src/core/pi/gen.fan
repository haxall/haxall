#! /usr/bin/env fan
//
// Copyright (c) 2026, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   12 Jun 2023  Brian Frank  Creation
//   28 Jun 2025  Brian Frank  Redesign to pack icons into a text file
//

using concurrent
using util

**
** Command line tool to compile lucide icons to manifest text file
**
**  1. cd /work/stuff/lucide
**  2. git pull
**  3. core/pi/gen.fan
**
@NoDoc
class IconsCompiler
{

  File lucideSrcDir() { `/work/stuff/lucide/icons/`.toFile }

  File ionSrcDir() { Env.cur.workDir + `src/core/pi/gen/` }

  File ionGenFile() { Env.cur.workDir + `src/core/pi/res/icons.txt` }

  Int main()
  {
    loadLucide
    loadIon
    acc.sort |a, b| { a.name <=> b.name }
    check
    write(ionGenFile)
    return 0
  }

//////////////////////////////////////////////////////////////////////////
// Load Lucide
//////////////////////////////////////////////////////////////////////////

  Void loadLucide()
  {
    srcDir :=  lucideSrcDir
    if (!srcDir.exists) throw Err("Must checkout Lucide git repo to: $srcDir.osPath")

    srcFiles := srcDir.list.sortr
    srcFiles.each |f, i|
    {
      if (f.ext != "svg") return
      acc.addNotNull(loadLucideFile(f, srcFiles.get(i+1)))
    }
  }

  IconFile? loadLucideFile(File svg, File json)
  {
    if (json.ext != "json" || json.basename != svg.basename)
    {
      echo("WARN: $svg | $json")
      return null
    }

    name := lucideFixName(json.basename)

    Str:Obj meta := JsonInStream(json.in).readJson
    Str[] tags := meta.getChecked("tags")
    Str[] cats := meta.getChecked("categories")
    tags = tags.addAll(cats)

    // remove arrow-xxx icon tags names like <-|
    if (name.startsWith("arrow-")) tags = tags.findAll { !it.contains("|") }
    tags = tags.map |t->Str| { lucideFixTag(t) }.unique.sort

    return IconFile
    {
      it.name = name
      it.tags = tags
      it.svg  = stripSvg(it.name, svg.readAllLines)
    }
  }

  Str lucideFixName(Str n)
  {
    // rename lucide name which conflict with really common names
    if (n == "space") return "space-char"
    return n
  }

  Str lucideFixTag(Str n)
  {
    // replace dashed tags like climate-control with a space for search
    dash := n.index("-")
    if (dash != null && dash != 0 && n[dash-1].isAlpha)
      return n.replace("-", " ")

    return n
  }

//////////////////////////////////////////////////////////////////////////
// Load Icon
//////////////////////////////////////////////////////////////////////////

  Void loadIon()
  {
    srcDir := ionSrcDir
    if (!srcDir.exists) throw Err("Cannot find $srcDir.osPath")

    // read manifest lines into memory
    manifest := srcDir.plus(`manifest.txt`).readAllLines

    // find the header ---  --- ---- for names/alias/tags
    headerIndex := manifest.findIndex { it.startsWith("--") } ?: throw Err("Manifest missing header")
    manifest = manifest[headerIndex+1..-1]

    // load them
    manifest.each |line|
    {
      acc.addNotNull(loadIonFile(srcDir, line))
    }
  }

  IconFile? loadIonFile(File srcDir, Str line)
  {
    if (line.trim.isEmpty) return null
    toks  := line.split
    name  := toks[0]
    tags  := toks[1..-1]
    alias := null
    svg   := null

    first := tags.first
    if (first != null && first.startsWith("<") && first.endsWith(">"))
    {
      alias = first[1..-2]
      tags = tags[1..-1]
    }
    else
    {
      svgFile := srcDir.plus(`${name}.svg`)
      if (!svgFile.exists) { echo("WARN: Missing SVG file: $svgFile.osPath"); return null }
      svg = stripSvg(name, svgFile.readAllLines)
    }

    return IconFile { it.name = name; it.tags = tags; it.alias = alias; it.svg = svg }
  }

//////////////////////////////////////////////////////////////////////////
// Check
//////////////////////////////////////////////////////////////////////////

  Void check()
  {
    // first check unique names
    byName := Str:IconFile[:]
    acc.each |x|
    {
      if (byName[x.name] != null) echo("WARNING: duplicate icon names: $x.name")
      else byName[x.name] = x
    }

    // check alias match an icon with svg
    acc.each |x|
    {
      if (x.alias == null) return
      match := byName[x.alias]
      if (match == null) echo("WARNING: alias not found: $x.name => $x.alias")
      else if (match.svg == null) echo("WARNING: alias to non-svg icon: $x.name => $x.alias")
    }

    // check all names and tags
    acc.each |x|
    {
      if (!isValidIconName(x.name)) echo("WARNING: invalid icon name: $x.name")
      x.tags.each |tag|
      {
        if (!isValidTagName(tag)) echo("WARNING: icon '$x.name' has invalid tag name: $tag")
      }
    }
  }

  Bool isValidIconName(Str n)
  {
    if (n.isEmpty) return false
    if (!n[0].isLower) return false
    return n.all |c| { c.isLower || c.isDigit || c == '-' }
  }

  Bool isValidTagName(Str n)
  {
    // Lucide uses tags with spaces and even emijos
    if (n.isEmpty) return false
    if (n.startsWith("#") || n.contains(",") || n.contains("|")) return false
    if (n.any { it.isUpper }) return false
    return true
  }

//////////////////////////////////////////////////////////////////////////
// Write
//////////////////////////////////////////////////////////////////////////

 Void write(File f)
 {
   if (!f.parent.exists) throw Err("Expecting write target dir to exist: $f.parent.osPath")

   // first generate all tags to index
   tagToIndex := Str:Int[:]
   acc.each |x|
   {
     x.tags.each |t| { tagToIndex[t] = 0 }
   }
   tags := tagToIndex.keys.sort
   tags.each |t, i| { tagToIndex[t] = i }

   // write tags
   s := StrBuf()
   s.add("# icons 1.0\n")
   s.add("# tags\n")
   tags.each |t| { s.add(t).add("\n") }

   // write svg icons
   s.add("# svg\n")
   iconToIndex := Str:Int[:]
   acc.each |x|
   {
     if (x.svg == null) return
     iconToIndex[x.name] = iconToIndex.size
     tagIndices := x.tags.map |t->Int| { tagToIndex.getChecked(t) }
     s.add(x.name).add("|").add(tagIndices.join(",")).add("|").add(x.svg).add("\n")
   }

   // write alias icons
   s.add("# alias\n")
   acc.each |x|
   {
     if (x.alias == null) return
     svgIndex := iconToIndex.getChecked(x.alias)
     tagIndices := x.tags.map |t->Int| { tagToIndex.getChecked(t) }
     s.add(x.name).add("|").add(tagIndices.join(",")).add("|").add(svgIndex).add("\n")
   }

   // write
   f.out.print(s.toStr).close
 }

//////////////////////////////////////////////////////////////////////////
// Utils
//////////////////////////////////////////////////////////////////////////

  Str stripSvg(Str name, Str[] lines)
  {
    // we require the same start element format
    while (lines[-1].trim.isEmpty) lines.removeAt(-1)

    n := 0
    match(name, lines[n++], Str<|<svg|>)
    match(name, lines[n++], Str<|  xmlns="http://www.w3.org/2000/svg"|>)
    match(name, lines[n++], Str<|  width="24"|>)
    match(name, lines[n++], Str<|  height="24"|>)
    match(name, lines[n++], Str<|  viewBox="0 0 24 24"|>)
    match(name, lines[n++], Str<|  fill="none"|>)
    match(name, lines[n++], Str<|  stroke="currentColor"|>)
    match(name, lines[n++], Str<|  stroke-width="2"|>)
    match(name, lines[n++], Str<|  stroke-linecap="round"|>)
    match(name, lines[n++], Str<|  stroke-linejoin="round"|>)
    match(name, lines[n++], Str<|>|>)

    match(name, lines[-1], Str<|</svg>|>)

    lines = lines[n..-2].map { it.trim.replace("\"", "'") }

    s := StrBuf()
    lines.each |line| { s.add(line.trim) }
    return s.toStr
  }

  Void match(Str name, Str line, Str expect)
  {
    if (line == expect) return
    echo("### WARN: invalid svg format for '$name'")
    echo("    $line.toCode")
    echo("    $expect.toCode")
  }

//////////////////////////////////////////////////////////////////////////
// Fields
//////////////////////////////////////////////////////////////////////////

  IconFile[] acc := [,]
}

**************************************************************************
** IconFile
**************************************************************************

class IconFile
{
  new make(|This| f) { f(this) }
  const Str name
  const Str[] tags
  const Str? alias
  const Str? svg
}

