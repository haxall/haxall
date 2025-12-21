//
// Copyright (c) 2025, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   21 Dec 2025  Brian Frank  Creation
//

using util
using xeto
using haystack

**
** FatSlot is used to wrap MCompSpi slot values that have outgoing
** links to manage pushing the value to the target component.
**
@Js
final class FatSlot
{
  ** Constructor
  new make(Obj? val) { this.val = val }

  ** const for this type
  static const Type type := FatSlot#

  ** Test hook to get value
  Obj? getVal() { val }

  ** Wrapped value or null for methods
  internal Obj? val
}

