//
// Copyright (c) 2026, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   10 Feb 2026  Brian Frank  Creation
//

using util
using haystack
using hxd

internal class ConvertDef : ConvertCmd
{
  override Str name() { "convert-def" }

  override Str summary() { "Convert 3.x def to Xeto type spec" }

  @Arg Str? defName

  override Int run()
  {
    // load defs ns
    DefNamespace? ns := null
    defc := Type.find("skyarcd::InstallDefCompiler", false)
    if (defc != null)
      ns = defc.method("bootAndCompile").call
    else
      ns = HxdBoot("temp", Env.cur.tempDir).init.defs
    echo("Loaded def ns [$ns]")

    // lookup def and tags
    def := ns.def(defName)
    tags := ns.tags(def)

    // build AST for it
    types := ADefType.fromDef(defName, def, tags)
    if (types == null || types.isEmpty)
    {
      echo("ERROR: cannot map to type: $defName")
      return 1
    }

    // output
    out := Env.cur.out
    types.each |type|
    {
      s := StrBuf()
      ConvertExtCmd.genType(s, type)

      out.printLine
      out.printLine(s.toStr)
    }

    return 0
  }
}

