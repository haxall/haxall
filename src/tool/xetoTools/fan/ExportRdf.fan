//
// Copyright (c) 2023, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//    8 Aug 2024  Brian Frank  Reboot
//

using util
using xeto
using xetom
using haystack

internal class ExportRdf : ExportCmd
{
  @Opt { help = "Export native instances without schema and ontology triples" }
  Bool instancesOnly

  @Opt { help = "Export schema and ontology triples without native instances" }
  Bool schemaOnly

  override Str cmdName() { "export-rdf" }

  override Str summary() { "Export Xeto to RDF" }

  override Str[] supportLibs() { ["sys.rdf"] }

  override Exporter initExporter(Namespace ns, OutStream out)
  {
    opts := Str:Obj[:]
    if (instancesOnly) opts["instancesOnly"] = Marker.val
    if (schemaOnly) opts["schemaOnly"] = Marker.val
    return RdfExporter(ns, out, Etc.makeDict(opts))
  }

  override Str toFileName(ExportTarget t)
  {
    t.toStr + ".ttl"
  }
}
