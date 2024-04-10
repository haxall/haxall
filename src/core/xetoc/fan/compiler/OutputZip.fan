//
// Copyright (c) 2023, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   21 Apr 2023  Brian Frank  Creation
//

using util
using xeto

**
** Output xetolib zip file
**
internal class OutputZip : Step
{
  override Void run()
  {
    if (!needToRun) return

    srcDir  := compiler.input
    zipFile := compiler.build

    zipFile.parent.create
    zip := Zip.write(zipFile.out)
    try
    {
      writeMeta(zip, "/meta.props")
      writeToZip(zip, "", srcDir)
    }
    finally zip.close
  }

  private Bool needToRun()
  {
    // we only output zip in build mode
    if (!compiler.isBuild) return false

    // for now skip this step in JS runtime
    if (Env.cur.runtime == "js") return false

    return true
  }

  private Void writeMeta(Zip zip, Str path)
  {
    meta := Str:Str[:]
    meta.ordered = true
    meta["name"]    = lib.name
    meta["version"] = lib.version.toStr
    meta["depends"] = depends.list.join(";")
    meta["doc"]     = lib.meta.getStr("doc") ?: ""
    zip.writeNext(path.toUri).writeProps(meta).close
  }

  private Void writeToZip(Zip zip, Str path, File file)
  {
    // skip hidden files, etc
    if (!includeInZip(file)) return

    // if directory recurse
    if (file.isDir)
    {
      dirList(file).each |kid| { writeToZip(zip, path + kid.name, kid) }
      return
    }

    // write file contents
    try
    {
      out := zip.writeNext(path.toUri, file.modified)
      file.in.pipe(out)
      out.close
    }
    catch (Err e)
    {
     throw err("Cannot write file into zip '$path': $e", FileLoc(file), e)
    }
  }

  private Bool includeInZip(File file)
  {
    if (file.name.startsWith(".")) return false
    return true
  }
}

