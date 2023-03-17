//
// Copyright (c) 2023, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   17 Mar 2023  Brian Frank  Creation
//

**
** DataContext is used to pass contextual state to DataEnv operations.
**
@Js
mixin DataContext
{
  ** Read a data record by id or return null
  @NoDoc abstract DataDict? dataReadById(Obj id)

  ** Read all the records that match given haytack filter
  @NoDoc abstract Obj? dataReadAllEachWhile(Str filter, |DataDict->Obj?| f)
}

