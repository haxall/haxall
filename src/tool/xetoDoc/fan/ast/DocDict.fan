//
// Copyright (c) 2024, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   22 Sep 2024  Brian Frank  Creation
//

using haystack

**
** DocDict is base class for dict values: meta, instances, and nested dict values
**
@Js
abstract const class DocDict : DocNode
{
  ** Constructor
  new make(Dict dict) { this.dict = dict }

  ** Metadata dict
  const Dict dict
}

