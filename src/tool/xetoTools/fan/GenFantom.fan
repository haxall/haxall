//
// Copyright (c) 2024, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   5 Feb 2024  Brian Frank  Creation
//

using util
using haystack::Dict
using xeto

internal class GenFantom : XetoCmd
{
  override Str name() { "gen-fantom" }

  override Str summary() { "Generate Xeto lib of interfaces for Fantom pods" }

//////////////////////////////////////////////////////////////////////////
// Run
//////////////////////////////////////////////////////////////////////////

  override Int run()
  {
    return 0
  }

//////////////////////////////////////////////////////////////////////////
// Fields
//////////////////////////////////////////////////////////////////////////

  private File? outDir          // output directory for generated fantom source files
}

