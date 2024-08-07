//
// Copyright (c) 2023, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   24 Mar 2023  Brian Frank  Creation
//    7 Aug 2024  Brian Frank  Reboot
//

using util
using xeto::LibNamespace
using haystack
using xetoEnv

internal class ExportJson : ExportCmd
{
  override Str name() { "export-json" }

  override Str summary() { "Export xeto to JSON" }

  @Opt { help = "Generate only own declared meta/slots" }
  Bool own


  override Exporter initExporter(LibNamespace ns, OutStream out)
  {
    opts := Etc.dict0
    return JsonExporter(ns, out, opts)
  }

  override Str toFileName(ExportTarget t)
  {
    t.toStr + ".json"
  }
}

