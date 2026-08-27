//
// Copyright (c) 2023, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   21 Apr 2023  Brian Frank  Creation
//

using util
using xeto
using xetom

**
** Output xetolib zip file
**
@Js
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
      // "xeto-meta.props" must be first
      writeMeta(zip, XetoUtil.xetoMetaPropsUri)

      // "xeto-build.props" must be before any source
      writeBuildVars(zip, XetoUtil.xetoBuildPropsUri)

      // rest of the files
      writeFiles(zip)
    }
    catch (Err e)
    {
      throw err("Cannot write xetolib zip '$zipFile': $e", FileLoc(srcDir), e)
    }
    finally
    {
      zip.close
    }
  }

  private Bool needToRun()
  {
    // we only output zip in build mode
    if (!compiler.isBuild) return false

    return true
  }

  private Void writeMeta(Zip zip, Uri path)
  {
    props := Str:Str[:]
    props.ordered = true
    props["name"]     = lib.name
    props["version"]  = lib.version.toStr
    props["maturity"] = lib.meta["maturity"]?.toStr ?: LibMaturity.stable.name
    props["depends"]  = depends.list.join(";")
    props["doc"]      = lib.meta.get("doc") as Str ?: ""
    if (lib.meta.has("hxSysOnly")) props.add("hxSysOnly", "true")

    zip.writeNext(path).writeProps(props).close
  }

  private Void writeBuildVars(Zip zip, Uri path)
  {
    vars := compiler.usedBuildVars
    if (vars.isEmpty) return

    zip.writeNext(path).writeProps(vars).close
  }

  private Void writeFiles(Zip zip)
  {
    lib.files.list.each |file|
    {
      entryOut := zip.writeNext(file.uri, file.modified ?: DateTime.now)
      file.read |in| { in.pipe(entryOut) }
      entryOut.close
    }
  }
}

