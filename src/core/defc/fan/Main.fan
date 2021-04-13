//
// Copyright (c) 2018, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   11 Jun 2018  Brian Frank  Creation
//

using util

**
** Main routine
**
class Main : AbstractMain
{
  @Opt { help = "Print version info"; aliases = ["v"] }
  Bool version

  @Opt { help = "Output directory" }
  File dir := Env.cur.workDir + `doc-def/`

  @Opt { help = "Comma separated outputs: html, csv, zinc, trio, json, turtle, dist" }
  Str output := "html"

  @Opt { help = "Generate protos output file in addition to defs file" }
  Bool protos

  @Arg { help = "List of input pod names or directories (defaults to ph pods)" }
  Str[]? inputs

  override Int run()
  {
    if (version) return printVersion(Env.cur.out)

    c := DefCompiler()
    c.outDir = dir

    if (inputs != null)
    {
      c.inputs = inputs.flatMap |x->CompilerInput[]|
      {
        pod := Pod.find(x, false)
        if (pod != null) return [CompilerInput.makePodName(x)]

        dir := File(x.toUri, false)
        if (dir.exists) return CompilerInput.scanDir(dir)

        throw Err("Unknown input pod or dir: $x")
      }
    }

    if (output.isEmpty) output = "html"

    try
    {
      c.compileMain(output.split(','), protos)
      return 0
    }
    catch (CompilerErr e)
    {
      c.log.err("Compile failed [$c.errs.size errors]")
      return 1
    }
  }

  override Int usage(OutStream out := Env.cur.out)
  {
    r := super.usage(out)
    out.printLine("Examples:")
    out.printLine("  defc                           // generate html from ph pods")
    out.printLine("  defc -output turtle            // generate defs.ttl from ph pods")
    out.printLine("  defc -output turtle,zinc       // generate defs.ttl + defs.zinc from ph pods")
    out.printLine("  defc -output turtle,html       // generate defs.ttl + HTML docs from ph pods")
    out.printLine("  defc -output turtle /src-dir   // generate defs.ttl from source directory")
    return r
  }

  private Int printVersion(OutStream out)
  {
    out.printLine
    out.printLine("Project Haystack Def Compiler")
    out.printLine("Copyright (c) 2018-2021, SkyFoundry LLC")
    out.printLine("Licensed under the Academic Free License version 3.0")
    out.printLine
    out.printLine("defc.version:     " + typeof.pod.version)
    out.printLine("java.version:     " + Env.cur.vars["java.version"])
    out.printLine("java.vm.name:     " + Env.cur.vars["java.vm.name"])
    out.printLine("java.home:        " + Env.cur.vars["java.home"])
    out.printLine("fan.version:      " + Pod.find("sys").version)
    out.printLine("fan.platform:     " + Env.cur.platform)
    out.printLine("fan.homeDir:      " + Env.cur.homeDir.osPath)
    out.printLine("fan.workDir:      " + Env.cur.workDir.osPath)
    out.printLine
    out.flush
    return 1
  }

}