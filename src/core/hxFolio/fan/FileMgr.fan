//
// Copyright (c) 2024, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//  19 Dec 2024  Matthew Giannini Creation
//

using haystack
using folio

@NoDoc
const class FileMgr : HxFolioMgr, FolioFile
{
  new make(HxFolio folio) : super(folio)
  {
    this.file = LocalFolioFile(folio)
  }

  private const LocalFolioFile file

  override Dict create(Dict rec, |OutStream| f)
  {
    file.create(rec, f)
  }

  override Obj? read(Ref id, |InStream->Obj?| f)
  {
    file.read(id, f)
  }

  override Void write(Ref id, |OutStream| f)
  {
    file.write(id, f)
  }

  override Void clear(Ref id)
  {
    file.clear(id)
  }

  ** Callback when the file rec with the given id is deleted from folio
  @NoDoc Void onRemove(Ref id)
  {
    file.delete(id)
  }
}