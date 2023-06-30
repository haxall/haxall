//
// Copyright (c) 2023, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   28 Apr 2023  Brian Frank  Creation
//

using util
using data
using xetoImpl

internal class JsonPragma : XetoCmd
{
  override Str name() { "json-pragma" }

  override Str summary() { "Parse lib.xeto pragma metadata into a JSON file" }

  @Opt { help = "Output file (default to stdout)" }
  File? out

  @Arg { help = "The lib.xeto meta file" }
  File? file

  override Int usage(OutStream out := Env.cur.out)
  {
    super.usage(out)
    out.printLine("Examples:")
    out.printLine("  xeto json-pragma src/ph.points/lib.xeto")
    out.printLine("  xeto json-pragma src/ph.points/lib.xeto -out lib.json")
    return 1
  }

//////////////////////////////////////////////////////////////////////////
// Run
//////////////////////////////////////////////////////////////////////////

  override Int run()
  {
    if (file == null)
    {
      echo("Must specify input file")
      return 1
    }

    json := env.parsePragma(file, null)

    withOut(this.out) |out|
    {
      env.print(json, out, env.dict1("json", env.marker))
    }
    return 0
  }

}