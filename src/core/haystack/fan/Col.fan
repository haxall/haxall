//
// Copyright (c) 2009, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   22 Dec 2009  Brian Frank  Creation
//


**
** Column of a Grid
**
@Js
abstract const class Col
{
  **
  ** Programatic name identifier for columm
  **
  abstract Str name()

  **
  ** Meta-data for column
  **
  abstract Dict meta()

  **
  ** Display name for columm which is 'meta.dis(null, name)'
  **
  Str dis() { meta.dis(null, name) }

  **
  ** Equality is based on reference
  **
  override final Bool equals(Obj? that) { this === that }

  **
  ** Compare based on name
  **
  override final Int compare(Obj x) { name <=> ((Col)x).name }

  **
  ** String representation is name
  **
  override final Str toStr() { name }
}