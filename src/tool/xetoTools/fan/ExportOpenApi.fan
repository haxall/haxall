//
// Copyright (c) 2023, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   10 Dec 2025  Mike Jarmy  Creation
//

using util
using xeto
using haystack
using xetom

internal class ExportOpenApi : ExportCmd
{
  override Str cmdName() { "export-openapi" }

  override Str summary() { "Export Xeto Funcs to OpenApi" }

  @Opt { help = "Output format: json or yaml" }
  Str? outFormat := "yaml"

  override Int usage(OutStream out := Env.cur.out)
  {
    super.usage(out)
    out.printLine("  xeto $cmdName ph::Rtu")
    return 1
  }

  override Exporter initExporter(Namespace ns, OutStream out)
  {
    return OpenApiExporter(ns, out, makeOpts())
  }

  private Dict makeOpts()
  {
    if (outFormat == null)
      return Etc.dict1("format", "yaml")

    else if (outFormat == "yaml")
      return Etc.dict1("format", "yaml")

    else if (outFormat == "json")
      return Etc.dict1("format", "json")

    else
      throw Err("$outFormat is an invalid output format")
  }

  override Str toFileName(ExportTarget t)
  {
    t.toStr + ".json"
  }
}

