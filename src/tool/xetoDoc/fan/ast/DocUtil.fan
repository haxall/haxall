//
// Copyright (c) 2024, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   24 Sep 2024  Brian Frank  Creation
//

using xetoEnv

**
** Documentation utilities
**
@Js
const class DocUtil
{
  ** Lib name to the library index page
  static Uri libToUri(Str libName)
  {
    "/${libName}/index".toUri
  }

  ** Convert spec or instance qualified name to its normalized URI
  static Uri qnameToUri(Str qname)
  {
    // TODO: we are going to have to deal with lower vs upper case names on file systems
    colons := qname.index("::")
    if (colons == null) return "/${qname}".toUri
    s := StrBuf(qname.size + 3)
    return s.addChar('/')
            .addRange(qname, 0..<colons)
            .addChar('/')
            .addRange(qname, colons+2..-1)
            .toStr.toUri
  }
}

