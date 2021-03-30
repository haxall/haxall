//
// Copyright (c) 2009, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   19 Jun 2009  Brian Frank  Creation
//

**
** Bin is a tag value for a binary file stored on disk
** rather than in the in-memory record database.  The Bin
** instance itself stores the MIME type.
**
@Js
const final class Bin
{
  **
  ** Construct with mime type string.
  **
  static new make(Str mime)
  {
    p := predefined[mime]
    if (p != null) return p
    if (mime.contains(")")) throw ArgErr("Bin MimeType cannot contain ')': $mime")
    return makeImpl(MimeType(mime))
  }

  private new makeImpl(MimeType mime) { this.mime = mime }

  **
  ** MimeType of the bin file.
  **
  const MimeType mime

  override Int hash() { mime.hash }

  override Bool equals(Obj? that)
  {
    x := that as Bin
    if (x == null) return false
    return mime == x.mime
  }

  override Str toStr() { mime.toStr }

  private const static Str:Bin predefined
  static
  {
    map := Str:Bin[:]
    try
    {
      mimes :=
      [
        "text/plain",
        "text/plain; charset=utf-8",
        "text/html",
        "text/html; charset=utf-8",
        "image/jpeg",
        "image/png",
        "image/gif",
        "application/pdf",
      ]
      mimes.each |mime| { map[mime] = makeImpl(MimeType(mime)) }
    }
    catch (Err e) e.trace
    predefined = map
  }

  **
  ** Bin for "text/plain; charset=utf-8".
  **
  const static Bin defVal := Bin("text/plain; charset=utf-8")

}