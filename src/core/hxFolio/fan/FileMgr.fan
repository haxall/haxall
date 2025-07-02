//
// Copyright (c) 2024, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//  19 Dec 2024  Matthew Giannini Creation
//

using xeto
using folio

@NoDoc
const class FileMgr : HxFolioMgr, FolioFile
{
  new make(HxFolio folio) : super(folio)
  {
    this.file = LocalFolioFile(folio)
  }

  private const MFolioFile file

  override File? get(Ref id, Bool checked := true) { file.get(id, checked) }
}

