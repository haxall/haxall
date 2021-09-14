//
// Copyright (c) 2019, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   18 Ma 2019  Brian Frank  Creation
//

using util
using haystack
using def

**
** Generate Haystack distribution zip
**
internal class GenDist : DefCompilerStep
{
  new make(DefCompiler c) : super(c) {}

  override Void run()
  {
    version := Pod.find("ph").version.toStr
    file := compiler.outDir + `haystack-defs-${version}.zip`
    zip := Zip.write(file.out)
    writeDocs(zip)
    writeSrc(zip)
    zip.close
    info("Dist [$file]")
  }

  private Void writeDocs(Zip zip)
  {
    compiler.outDir.list.each |file|
    {
      // skip zip itself
      if (file.ext == "zip") return

      // put defs.xxx in defs/, protos.xxx in protos/, everything else in docs
      dir := "doc"
      if (file.basename == "defs" || file.basename == "protos")
        dir = file.basename

      addToZip(zip, dir, file)
    }
  }

  private Void writeSrc(Zip zip)
  {
    srcDir := findSrcDir
    srcDir.list.each |file|
    {
      addToZip(zip, "src", file)
    }
  }

  private File findSrcDir()
  {
    // find source based on Env path
    envDir := ((PathEnv)Env.cur).path.find |dir| { dir.plus(`src/ph/`).exists }
    return envDir + `src/`
  }

  private Void addToZip(Zip zip, Str path, File file)
  {
    uri := "$path/$file.name"
    if (file.isDir)
    {
      info("  Zipping [$uri]")
      file.list.each |kid| { addToZip(zip, uri, kid) }
    }
    else
    {
      o := zip.writeNext(uri.toUri, file.modified)
      file.in.pipe(o)
      o.close
    }
  }

}

