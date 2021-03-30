//
// Copyright (c) 2019, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   22 Jan 2019  Brian Frank  Creation
//

using haystack


**
** CDefParts manages sub-parts of compound defs
**
abstract class CDefParts
{
  ** Constructor
  new make(CDef def) { this.def = def }

  ** Associated CDef
  CDef def

  ** As feature key
  virtual CKeyParts key() { throw Err("Not key: $def") }

  ** As conjunct
  virtual CConjunctParts conjunct() { throw Err("Not conjunct: $def") }
}

**************************************************************************
** CKeyParts
**************************************************************************

class CKeyParts : CDefParts
{
  new make(CDef def, CDef feature) : super(def)
  {
    this.feature = feature
  }

  override CKeyParts key() { this }

  CDef feature
}

**************************************************************************
** CConjunctParts
**************************************************************************

class CConjunctParts : CDefParts
{
  new make(CDef def, CDef[] tags) : super(def)
  {
    this.tags = tags
  }

  override CConjunctParts conjunct() { this }

  CDef[] tags
}

