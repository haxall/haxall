//
// Copyright (c) 2012, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   19 Aug 2012  Brian Frank  Creation
//

**
** GridWriter is the interface for writing an encoding of grid data.
** All implementations must have a constructor called 'make' that
** takes an OutStream.  Constructors may also declare a second parameter
** for a Dict opts.
**
@NoDoc
@Js
mixin GridWriter
{

  **
  ** Write a single grid
  **
  abstract This writeGrid(Grid grid)

}