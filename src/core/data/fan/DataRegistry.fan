//
// Copyright (c) 2023, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   23 Apr 2023  Brian Frank  Creation
//

**
** Registry of libs installed on local machine
**
@NoDoc @Js
const mixin DataRegistry
{
  ** List all installed libs
  abstract DataRegistryLib[] list()

  ** Lookup installed lib
  abstract DataRegistryLib? get(Str qname, Bool checked := true)
}

**************************************************************************
** DataRegistryLib
**************************************************************************

**
** Registry entry of a single lib installed on local machine
**
@NoDoc @Js
const mixin DataRegistryLib
{
  ** Qualilfied name
  abstract Str qname()

  ** Has this library been loaded into memory
  abstract Bool isLoaded()

  ** Xetolib zip file location
  abstract File zip()

  ** Is the source available in working dir
  abstract Bool isSrc()

  ** Source dir if available in working dir
  abstract File? srcDir(Bool checked := true)
}

