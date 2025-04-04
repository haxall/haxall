//
// Copyright (c) 2023, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//    2 Apr 2024  Brian Frank  Reboot
//

using util
using xeto::LibNamespace
using haystack
using xetoEnv

internal class DumpCmd : ExportCmd
{
  override Str name() { "dump" }

  override Str summary() { "Debug dump" }

  @Opt { aliases=["e"]; help = "Generate inherited effective meta/slots (default is own)" }
  Bool effective

  override Exporter initExporter(LibNamespace ns, OutStream out)
  {
    opts := Str:Obj[:]
    if (effective) opts["effective"] = Marker.val
    return DumpExporter(ns, out, Etc.makeDict(opts))
  }

  override Str toFileName(ExportTarget t)
  {
    t.toStr + ".txt"
  }
}

