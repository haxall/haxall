//
// Copyright (c) 2022, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   03 Feb 2022  Matthew Giannini  Creation
//

**
** Page object
**
const class EcobeePage : EcobeeObj
{

//////////////////////////////////////////////////////////////////////////
// Constructor
//////////////////////////////////////////////////////////////////////////

  new make(|This| f) { f(this) }

  new makeReq(Int page) { this.page = page.max(1) }

  ** The page retrieved or, in the case of a request parameter, the
  ** specific page requested
  const Int? page

  ** The total pages available
  const Int? totalPages

  ** The number of objects on this page
  const Int? pageSize

  ** The total number of objects available
  const Int? total

//////////////////////////////////////////////////////////////////////////
// Util
//////////////////////////////////////////////////////////////////////////

  ** Are there more pages to fetch. If this returned true, then
  ** all fields can be assumed to be non-null.
  Bool morePages()
  {
    page != null && totalPages != null && page < totalPages
  }
}

