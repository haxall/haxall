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

internal class ExportJsonSchema : ExportCmd
{
  override Str name() { "export-json-schema" }

  override Str summary() { "Export Xeto Specs to JSON Schema" }

  @Opt { help = "Output format -- must be either 'json' or 'yaml'" }
  Str? outputFormat

  override Int usage(OutStream out := Env.cur.out)
  {
    super.usage(out)
    out.printLine("  xeto $name ph::Rtu")
    return 1
  }

  override Exporter initExporter(Namespace ns, OutStream out)
  {
    return JsonSchemaExporter(ns, out, makeOpts())
  }

  private Dict makeOpts()
  {
    if (outputFormat == null)
      return Etc.dict1("format", "yaml")

    else if (outputFormat == "yaml")
      return Etc.dict1("format", "yaml")

    else if (outputFormat == "json")
      return Etc.dict1("format", "json")

    else
      throw Err("$outputFormat is an invalid output format")
  }

  override Str toFileName(ExportTarget t)
  {
    t.toStr + ".json"
  }
}

