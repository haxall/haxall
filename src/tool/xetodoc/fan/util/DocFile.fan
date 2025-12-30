//
// Copyright (c) 2025, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   17 Apr 2025  Brian Frank  Creation
//

using xeto
using haystack

**
** DocFile represents a documentation page which can be accessed as
** a JSON file or an in-memory DocPage AST
**
const mixin DocFile
{
  ** Normalized uri for the file
  abstract Uri uri()

  ** Access as a JSON file, this might encode on each call
  abstract File file()

  ** Access an in-memory AST, this might decode on each call
  abstract DocPage page()

  ** Debug string
  override Str toStr() { "$typeof.name `$uri`" }
}

**************************************************************************
** DocMemFile
**************************************************************************

const class DocMemFile : DocFile
{
  new make(DocPage page)
  {
    this.page = page
  }

  override Uri uri() { page.uri }

  override File file() { page.encodeToFile }

  override const DocPage page
}

**************************************************************************
** DocDiskFile
**************************************************************************

const class DocDiskFile : DocFile
{
  new make(Uri uri, File file)
  {
    this.uri = uri
    this.file = file
  }

  new makeBuf(Uri uri, Buf buf)
  {
    this.uri = uri
    this.file = buf.toFile(uri)
  }

  const override Uri uri

  const override File file

  override DocPage page() { DocPage.decodeFromFile(file) }
}

