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
using haystack::Etc
using haystack::Marker

internal class ExportJson : ExportCmd
{
  override Str name() { "export-json" }

  override Str summary() { "Export xeto to JSON" }

  @Opt { help = "Generate only own declared meta/slots" }
  Bool own


}

