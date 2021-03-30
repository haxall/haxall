//
// Copyright (c) 2015, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   31 Mar 2015  Brian Frank  Creation
//

**
** NA is the singleton which indicates not available.
**
@Js
@Serializable { simple = true }
const final class NA
{
  ** Singleton value
  const static NA val := NA()

  ** Always return `val`
  static new fromStr(Str s) { val }

  private new make() {}

  ** Return "NA"
  override Str toStr() { "NA" }
}