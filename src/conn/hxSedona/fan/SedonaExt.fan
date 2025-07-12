//
// Copyright (c) 2012, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   14 May 2012  Brian Frank  Creation
//

using web
using haystack
using hxConn
using [java]java.lang::System
using [java]fanx.interop
using [java]sedona.manifest
using [java]sedona.xml

**
** Sedona Extension
**
const class SedonaExt : ConnExt
{

  static
  {
    // set sedona.home Java system property
    homeDir :=  Env.cur.workDir.plus(`etc/sedona/`)
    try
      System.getProperties.put("sedona.home", homeDir.osPath)
    catch (Err e)
      e.trace

    // if there isn't already, stub an empty sedona.properties
    props := homeDir + `lib/sedona.properties`
    try
      if (!props.exists) props.out.print("# sedona.props\n# stubbed $DateTime.now.toLocale").close
    catch (Err e)
      e.trace
  }

}

