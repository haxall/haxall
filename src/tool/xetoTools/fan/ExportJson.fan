//
// Copyright (c) 2023, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   24 Mar 2023  Brian Frank  Creation
//    7 Aug 2024  Brian Frank  Reboot
//

using util
using xeto
using haystack
using xetom

internal class ExportJson : ExportCmd
{
  override Str cmdName() { "export-json" }

  override Str summary() { "Export Xeto Instances to JSON" }

  @Opt { aliases=["e"]; help = "Generate inherited effective meta/slots (default is own)" }
  Bool effective

  @Opt { help = "Box scalar instance values: none, auto, or all (default is none)" }
  Str box := "none"

  override Int usage(OutStream out := Env.cur.out)
  {
    super.usage(out)
    out.printLine("  xeto $cmdName ph::Rtu -effective    // output effective meta and slots")
    out.printLine("  xeto $cmdName acme.lib -box auto    // box instance scalars that lose their type")
    return 1
  }

  override Exporter initExporter(Namespace ns, OutStream out)
  {
    if (JsonBoxMode.fromStr(box, false) == null) throw Err("Invalid box mode: $box")
    opts := Str:Obj[:]
    if (effective) opts["effective"] = Marker.val
    if (box != "none") opts["box"] = box
    return JsonExporter(ns, out, Etc.makeDict(opts))
  }

  override Str toFileName(ExportTarget t)
  {
    t.toStr + ".json"
  }
}

