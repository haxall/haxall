//
// Copyright (c) 2024, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//  12 Dec 2024  Matthew Giannini Creation
//

using haystack

**
** FolioFile provides APIs associated with storing files in folio. Folio itself
** only stores a rec with information about the file. Implementations will typically
** store the actual file contents to the local filesystem or cloud.
**
@NoDoc
const mixin FolioFile
{
  abstract FolioFuture create(Dict rec, |InStream| f)

  abstract Obj? read(Ref id, |InStream->Obj?| f)

  abstract Void write(Ref id, |OutStream| f)

  abstract FolioFuture delete(Ref id)
}
