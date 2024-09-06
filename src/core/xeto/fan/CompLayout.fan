//
// Copyright (c) 2024, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//    6 Sep 2024  Brian Frank  Creation
//

using concurrent

**
** CompLayout models layout of a component on a logical grid coordinate system
**
@Js
const mixin CompLayout : Dict
{
  ** Logical x coordinate
  abstract Int x()

  ** Logical y coordinate
  abstract Int y()

  ** Width in logical coordinate system
  abstract Int w()

}

