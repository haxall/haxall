//
// Copyright (c) 2023, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   16 Jan 2023  Brian Frank  Creation
//

using util

**
** Access to file resources packaged with library.
**
@Js
const mixin LibFiles
{
  ** Return if this API is supported, will be false in browser environments.
  abstract Bool isSupported()

  ** List resource files in this library.
  abstract Uri[] list()

  ** List the resource files published with a uri of their own.  These are
  ** the files a lib offers for public consumption; the rest are packaged
  ** for the runtime to read but are not addressable outside the lib.
  abstract Uri[] published()

  ** Get a file in this library (treat this file as readonly)
  abstract File? get(Uri uri, Bool checked := true)
}

