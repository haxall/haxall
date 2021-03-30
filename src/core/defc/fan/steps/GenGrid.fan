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
internal class GenGrid : DefCompilerStep
{
  new make(DefCompiler c, Str format) : super(c)
  {
    this.format = format
  }

  const Str format

  override Void run()
  {
    c := compiler
    if (c.grid == null) c.grid = c.ns.toGrid

    filetype := c.ns.filetype(format)

    // check if we have a callback or we are writing to disk
    uri := `defs.${filetype.fileExt}`
    onFile := compiler.onDocFile
    opts := Etc.makeDict1("ns", c.ns)
    if (onFile != null)
    {
      info("Generating $filetype.dis in-memory")
      buf := Buf()
      writeGrid(filetype, buf.out)
      onFile(DocFile(uri, filetype.dis, buf))
    }
    else
    {
      file := c.initOutDir + uri
      info("Generating $filetype.dis [$file.osPath]")
      writeGrid(filetype, file.out)
    }
  }

  static Str[] formats()
  {
     ["zinc", "trio", "json", "turtle", "jsonld", "csv"]
  }

  private Void writeGrid(Filetype filetype, OutStream out)
  {
    c := compiler
    opts := filetype.ioOpts(c.ns, null, Etc.emptyDict, Etc.emptyDict)
    writer := filetype.writer(out, opts)
    writer.writeGrid(c.grid)
    out.close
  }
}