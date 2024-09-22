//
// Copyright (c) 2024, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   22 Sep 2024  Brian Frank  Creation
//

**
** DocLink is a hyperlink
**
@Js
const class DocLink
{
  ** Constructor
  new make(Uri uri, Str dis)
  {
    this.uri = uri
    this.dis = dis
  }

  ** URI relative to base dir to page
  const Uri uri

  ** Display text for link
  const Str dis
}

