//
// Copyright (c) 2024, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   30 Oct 2024  Brian Frank  Creation
//

using util
using xeto
using haystack
using defc
using xetom

internal abstract class ExportHaystack : ExportCmd
{
  @Opt { aliases=["e"]; help = "Generate inherited effective meta/slots (default is own)" }
  Bool effective

  override Int usage(OutStream out := Env.cur.out)
  {
    super.usage(out)
    out.printLine("  xeto $name ph::Rtu -effective    // output effective meta and slots")
    return 1
  }

  override Exporter initExporter(Namespace ns, OutStream out)
  {
    opts := Str:Obj[:]
    if (effective) opts["effective"] = Marker.val
    return GridExporter(ns, out, Etc.makeDict(opts), filetype)
  }

  override Str toFileName(ExportTarget t)
  {
    t.toStr + ".${filetype.fileExt}"
  }

  once DefNamespace defns()
  {
    // TODO: use defc until convert everything over to xeto
    DefCompiler().compileNamespace
  }

  abstract Filetype filetype()
}

**************************************************************************
** ExportTrio
**************************************************************************

internal class ExportTrio :  ExportHaystack
{
  override Str name() { "export-trio" }

  override Str summary() { "Export Xeto to Trio" }

  override Filetype filetype() { defns.filetype("trio") }
}

**************************************************************************
** ExportZinc
**************************************************************************

internal class ExportZinc :  ExportHaystack
{
  override Str name() { "export-zinc" }

  override Str summary() { "Export Xeto to Zinc" }

  override Filetype filetype() { defns.filetype("zinc") }
}

**************************************************************************
** ExportHayson
**************************************************************************

internal class ExportHayson :  ExportHaystack
{
  override Str name() { "export-hayson" }

  override Str summary() { "Export Xeto to Haystack JSON" }

  override Filetype filetype() { defns.filetype("json") }
}

