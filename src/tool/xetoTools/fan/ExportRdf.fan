//
// Copyright (c) 2023, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//    8 Aug 2024  Brian Frank  Reboot
//

using util
using xeto::LibNamespace
using haystack
using xetoEnv

internal class ExportRdf : ExportCmd
{
  override Str name() { "export-rdf" }

  override Str summary() { "Export Xeto to RDF" }

  override Exporter initExporter(LibNamespace ns, OutStream out)
  {
    opts := Str:Obj[:]
    return RdfExporter(ns, out, Etc.makeDict(opts))
  }

  override Str toFileName(ExportTarget t)
  {
    t.toStr + ".ttl"
  }
}

