//
// Copyright (c) 2015, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   2 Nov 2015  Brian Frank  Creation
//

using concurrent
using xeto
using haystack
using folio
using hxFolio


**************************************************************************
** FolioFlatFileTestImpl
**************************************************************************

class FolioFlatFileTestImpl : FolioTestImpl
{
  override Str name() { "flatfile" }

  override Folio open(FolioConfig c) { FolioFlatFile.open(c) }

  // don't support disMacro
  override Void verifyDictDis(Dict r, Str expect) {}

  // don't support disMacro
  override Void verifyIdDis(Ref id, Str expect) {}

  // don't support history API
  override Bool supportsHis() { false }
}

**************************************************************************
** HxFolioTestImpl
**************************************************************************

class HxFolioTestImpl : FolioTestImpl
{
  override Str name() { "hx" }

  override Folio open(FolioConfig c) { HxFolio.open(c) }
}

