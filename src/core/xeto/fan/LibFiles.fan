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

  ** List all resource files in this library.
  abstract LibFile[] list()

  ** List the resource files published with a uri of their own.  These are
  ** the files a lib offers for public consumption; the rest are packaged
  ** for the runtime to read but are not addressable outside the lib.
  abstract LibFile[] published()

  ** Get a file in this library
  abstract LibFile? get(Uri uri, Bool checked := true)
}

**************************************************************************
** LibFile
**************************************************************************

**
** LibFile models on resource file packaged into a xeto library.
**
@Js
const mixin LibFile
{
  ** Uri identifier with starting with slash such as "/res/icon.svg"
  abstract Uri uri()

  ** Is this library published with its own URI
  abstract Bool isPublished()

  ** Read the file's input stream using a callback. The input stream
  ** is guaranteed to be closed when the callback exits.  Return the
  ** value returned by the callback.
  abstract Obj? read(|InStream->Obj?| f)

  ** Convenience to read file to in-memory string
  abstract Str readAllStr()

  ** Size in bytes if known
  @NoDoc abstract Int? size()

  ** Modified time if known
  @NoDoc abstract DateTime? modified()

  ** File location for compiler error reporting
  @NoDoc abstract FileLoc loc()
}

