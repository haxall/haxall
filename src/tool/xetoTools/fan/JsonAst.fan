//
// Copyright (c) 2023, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   24 Mar 2023  Brian Frank  Creation
//

using util
using xeto
using haystack::Etc

internal class JsonAst : XetoCmd
{
  override Str name() { "json-ast" }

  override Str summary() { "Compile xeto libs into JSON AST file" }

  @Opt { help = "Generate only own declared meta/slots" }
  Bool own

  @NoDoc @Opt { help = "Include file location in meta" }
  Bool fileloc

  @Opt { help = "Output file (default to stdout)" }
  File? out

  @Arg { help = "Specs to generate or \"all\" for all libs installed" }
  Str[]? specs

  override Int usage(OutStream out := Env.cur.out)
  {
    super.usage(out)
    out.printLine("Examples:")
    out.printLine("  xeto json-ast sys                 // one lib")
    out.printLine("  xeto json-ast sys ph ph.points    // multiple libs")
    out.printLine("  xeto json-ast ph::Rtu             // one spec")
    out.printLine("  xeto json-ast ph::Rtu -own        // declared meta/slots only")
    out.printLine("  xeto json-ast -out xeto.json all  // everything installed to output file")
    return 1
  }

//////////////////////////////////////////////////////////////////////////
// Run
//////////////////////////////////////////////////////////////////////////

  override Int run()
  {
    specs := toSpecs(this.specs)
    if (specs == null) return 1

    opts := Str:Obj[:]
    if (own) opts["own"] = env.marker
    if (fileloc) opts["fileloc"] = env.marker

    acc := Str:Dict[:]
    specs.each |spec|
    {
      acc[spec.qname] = env.genAst(spec, Etc.dictFromMap(opts))
    }
    root := Etc.dictFromMap(acc)

    withOut(this.out) |out|
    {
      env.print(root, out, Etc.dict1("json", env.marker))
    }
    return 0
  }

}

