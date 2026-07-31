//
// Copyright (c) 2026, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   30 Jul 2026  Matthew Giannini  Creation
//

**
** A Folio manager
**
@NoDoc mixin FolioMgr
{
  ** Get the folio database
  abstract Folio db()

  ** Get the current [FolioContext] if one is installed
  FolioContext? folioCx() { FolioContext.curFolio(false) }
}
