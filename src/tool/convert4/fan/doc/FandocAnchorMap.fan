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
** for all the common manuals (docHaystack, docHaxall, etc) and any pod.fandoc
** into a text file we can use for conversion tools.
**
const class FandocAnchorMap
{

//////////////////////////////////////////////////////////////////////////
// Load
//////////////////////////////////////////////////////////////////////////

  ** Load
  static FandocAnchorMap load(File? file := null)
  {
    if (file == null) file = `/work/stuff/convert4/anchor-map.txt`.toFile
    lines := file.readAllLines
    acc := Str:[Str:Str][:]
    [Str:Str]? cur
    lines.each |line|
    {
      if (line.trim.isEmpty) return
      if (line[0] != ' ')
      {
        cur = Str:Str[:]
        cur.ordered = true
        acc[line.trim] = cur
      }
      else
      {
        pair := line.trim.split('=')
        cur[pair.first] = pair.last
      }
    }

    x := make(acc)
    //x.dump
    return x
  }

  ** Constructor
  new make(Str:[Str:Str] map) { this.map = map }


  ** Map keyed by qname for old:new
  const Str:[Str:Str] map

  ** Given an pod name "docHaxall::Conns" and old id such "included"
  ** return the new text based is such as "included-connectors". Return
  ** null if not found.
  Str? get(Str qname, Str frag)
  {
    map[qname]?.get(frag)
  }

  ** Dump in same format we load
  Void dump(OutStream out := Env.cur.out)
  {
    map.keys.sort.each |qname|
    {
      out.printLine(qname)
      map[qname].each |v, n| { out.printLine(" $n=$v") }
    }
  }

//////////////////////////////////////////////////////////////////////////
// Generator
//////////////////////////////////////////////////////////////////////////

  ** Generate (must call from sf-misc)
  static Str:Str generate()
  {
    acc := Str:Str[:]
    Env.cur.path.each |pathDir|
    {
      (pathDir + `src/`).walk |x|
      {
        if (x.isDir && x.name.size > 4 && x.plus(`build.fan`).exists)
        {
          podName := x.name
          if (podName == "docXeto" || podName == "docOEM" || podName == "docCloud") return
          x.walk |f|
          {
            if (f.ext == "fandoc")
            {
              echo("$podName::$f.basename")
              genFile(acc, podName, f)
            }
          }
        }
      }
    }
    return acc
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
        echo("  $id=$to")
      }
    }
  }

}

