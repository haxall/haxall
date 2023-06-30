//
// Copyright (c) 2023, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   17 Mar 2023  Brian Frank  Creation
//

**
** XetoContext is used to pass contextual state to XetoEnv operations.
**
@Js
mixin XetoContext
{
  ** Read a data record by id or return null
  @NoDoc abstract Dict? xetoReadById(Obj id)

  ** Read all the records that match given haytack filter
  @NoDoc abstract Obj? xetoReadAllEachWhile(Str filter, |Dict->Obj?| f)
}

