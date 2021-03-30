//
// Copyright (c) 2021, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   26 Jan 2021  Brian Frank  Creation
//

using compilerDoc

**
** DocNavData encodes triples of level+uri+display for navigation.
** It is used to encode the breadcrumb and a navigation menu for
** each page.  We encode it into a simple plaintext comment for
** external application use.
**
class DocNavData
{
  ** Add link relative to current document
  This add(Uri uri, Str title, Int level := 1)
  {
    buf.add(Str.spaces(level))
    buf.add(uri.encode.replace(".html", "")).addChar(' ')
    addSafe(title)
    buf.addChar('\n')
    return this
  }

  ** Add title stripping any unsafe character
  private Void addSafe(Str s)
  {
    if (s.isEmpty || s[0] == ' ') throw ArgErr(s)
    s.each |c|
    {
      if (c < ' ' || c == '>') return
      buf.addChar(c)
    }
  }

  ** Is the sidebar tree empty
  Bool isEmpty() { buf.isEmpty }

  ** Encode items to plain text
  Str encode() { buf.toStr }

  private StrBuf buf := StrBuf()
}