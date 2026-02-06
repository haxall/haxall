//
// Copyright (c) 2026, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   6 Feb 2026  Brian Frank  Creation
//

using concurrent
using util
using xeto
using fandoc
using fandoc::Link

**
** FixManual converts Fantom manual pod to markdown xeto lib.
**
** NOTE: this comamnd does **not** fix the links. We do that in a new
** step for easier diff review
**
class FixManual : ConvertCmd
{
  override Str name() { "fix-manual" }

  override Str summary() { "Convert fantom manual pod to markdown xeto lib" }

  @Opt { help = "Output directory that contains src/xeto/{libName}" }
  File? workDir

  @Arg { help = "Pod name to convert" }
  Str? podName

  @Arg { help = "Xeto lib name" }
  Str? libName

  override Int run()
  {
    // find pod directory
    pod := Pod.find(podName)

    // destination directory
    if (workDir != null)
      workDir = workDir.uri.plusSlash.toFile
    else
      this.workDir = Env.cur.workDir
    xetoDir := workDir + `src/xeto/$libName/`

    // generate lib.xeto
    genLibXeto(pod, xetoDir)

    // generate index
    genIndex(pod, xetoDir)

    // generate every chapter
    pod.files.each |f|
    {
      if (f.ext == "fandoc") genChapter(pod, f, xetoDir)
    }

    return 0
  }

  private Void genLibXeto(Pod pod, File dir)
  {
    config := AConfig.load

    // generate lib.xeto
    header := config.genHeader

    // generate body
    body := config.genMacro(config.templateLibXeto) |name|
    {
      if (name == "doc") return pod.meta["pod.summary"]
      if (name == "depends") return """{\n    { lib: "sys" }\n  }"""
      return ""
    }

    // write out
    file := dir + `lib.xeto`
    file.out.print(header+"\n\n"+body).close
    echo("Generate lib.xeto [$file.osPath]")
  }

  private Void genIndex(Pod pod, File dir)
  {
    fog := pod.file(`/doc/index.fog`).readObj as Obj[]
    buf := StrBuf()
    fog.each |x|
    {
      if (x is Str)
      {
        buf.add("\n# $x\n\n")
      }
      else
      {
        list := (Obj[])x
        name := list[0]
        doc  := list[1]
        buf.add("- [$name](${name}.md): $doc\n")
      }
    }
    src := buf.toStr.trim
    file := dir.plus(`index.md`)
    echo("Generate lib.xeto [$file.osPath]")
    file.out.print(src).close
  }

  private Void genChapter(Pod pod, File src, File dir)
  {
    // don't fix links
    base := pod.name + "::" + src.basename
    markdown := FixFandoc.convertFandocFile(base, src, fixLinks)
    dst := dir + `${src.basename}.md`
    echo("Generate chapter [$dst.osPath]")
    dst.out.print(markdown).close
  }

  once FixLinks fixLinks() { FixLinks.load }

}

