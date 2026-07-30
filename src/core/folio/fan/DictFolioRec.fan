//
// Copyright (c) 2026, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   30 Jul 2026  Matthew Giannini  Creation
//

using xeto

**
** DictFolioRec is a simple FolioRec wrapper around a Dict for stores
** which do not support watches.
**
@NoDoc const class DictFolioRec : FolioRec
{
  new make(Dict dict) { this.dict = dict }
  const override Dict dict
  override Int ticks() { throw UnsupportedErr() }
  override Int watchCount() { throw UnsupportedErr() }
  override Int watchIncrement() { throw UnsupportedErr() }
  override Int watchDecrement() { throw UnsupportedErr() }
}

