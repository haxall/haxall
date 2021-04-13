//
// Copyright (c) 2018, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   10 Oct 2018  Brian Frank  Creation
//   23 Jan 2019  Brian Frank  Redesign
//

using fandoc
using web
using haystack
using def

**
** Generate grid output in specified FileType
**
internal abstract class GenGrid : DefCompilerStep
{
  new make(DefCompiler c, Str format) : super(c)
  {
    this.format = format
  }

  const Str format

  override Void run()
  {
    c := compiler
    grid := toGrid(c)

    filetype := c.ns.filetype(format)

    // check if we have a callback or we are writing to disk
    uri := `${baseName}.${filetype.fileExt}`
    onFile := compiler.onDocFile
    opts := Etc.makeDict1("ns", c.ns)
    if (onFile != null)
    {
      info("Generating $filetype.dis $baseName.capitalize in-memory")
      buf := Buf()
      writeGrid(grid, filetype, buf.out)
      onFile(DocFile(uri, filetype.dis, buf))
    }
    else
    {
      file := c.initOutDir + uri
      info("Generating $filetype.dis $baseName.capitalize [$file.osPath]")
      writeGrid(grid, filetype, file.out)
    }
  }

  abstract Str baseName()

  abstract Grid toGrid(DefCompiler c)

  static Str[] formats()
  {
     ["zinc", "trio", "json", "turtle", "jsonld", "csv"]
  }

  private Void writeGrid(Grid grid, Filetype filetype, OutStream out)
  {
    c := compiler
    opts := filetype.ioOpts(c.ns, null, Etc.emptyDict, Etc.emptyDict)
    writer := filetype.writer(out, opts)
    writer.writeGrid(grid)
    out.close
  }
}

**************************************************************************
** GenDefsGrid
**************************************************************************

internal class GenDefsGrid : GenGrid
{
  new make(DefCompiler c, Str format) : super(c, format) {}

  override Str baseName() { "defs" }

  override Grid toGrid(DefCompiler c)
  {
    if (c.defsGrid == null) c.defsGrid = c.ns.toGrid
    return c.defsGrid
  }
}

**************************************************************************
** GenProtosGrid
**************************************************************************

internal class GenProtosGrid : GenGrid
{
  new make(DefCompiler c, Str format) : super(c, format) {}

  override Str baseName() { "protos" }

  override Grid toGrid(DefCompiler c)
  {
    if (c.protosGrid == null) c.protosGrid = buildProtosGrid(c)
    return c.protosGrid
  }

  private Grid buildProtosGrid(DefCompiler c)
  {
    // collect map of all tag names used across all protos
    allTags := Str:Str[:]
    c.index.protos.each |proto|
    {
      proto.dict.each |v, n| { allTags[n] = n }
    }

    // build grid where first column is 'proto' for display name
    if (allTags.containsKey("proto")) throw Err("There are protos with the 'proto' tag")
    gb := GridBuilder()
    gb.addCol("proto")
    allTags.keys.sort.each |n| { gb.addCol(n) }
    c.index.protos.each |proto|
    {
      cells := Obj?[,]
      cells.size = gb.numCols
      cells[0] = proto.dis
      proto.dict.each |v, n| { cells[gb.colNameToIndex(n)] = v }
      gb.addRow(cells)
    }
    return gb.toGrid
  }
}

