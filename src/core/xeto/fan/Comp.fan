//
// Copyright (c) 2024, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   17 May 2024  Brian Frank  Sandbridge
//

using concurrent

**
** Component or function block
**
@Js
mixin Comp
{
  ** Component identifier
  abstract Ref id()

  ** Parent component idendifier or null if tree root or unmounted
  abstract Ref? parentRef()

  ** Parent component instance or null if tree root or unmounted
  abstract Comp? parent()

  ** All incoming links to this component
  abstract Links links()

}

