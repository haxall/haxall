//
// Copyright (c) 2012, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   19 Aug 2012  Brian Frank  Creation
//

**
** GridReader is the interface for reading an encoding of grid data
** All implementations must have a constructor called 'make' that
** takes an InStream.  Constructors may also declare a second parameter
** for a Dict opts.
**
@NoDoc
@Js
mixin GridReader
{

  **
  ** Read a single grid
  **
  abstract Grid readGrid()

}