//
// Copyright (c) 2019, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   17 Jan 2019  Brian Frank  Creation
//

using concurrent
using xeto
using haystack

**
** Lib implementation
**
@NoDoc @Js
const class MLib : MDef, DefLib
{
  new make(BDef b) : super(b)
  {
    this.baseUri = ((Uri)meta->baseUri).plusSlash
    this.version = Version.fromStr(meta->version)
    this.depends = meta.has("depends") ? Symbol[,].addAll(meta["depends"]) : Symbol#.emptyList
  }

  override Int index() { indexRef.val }
  internal const AtomicInt indexRef := AtomicInt()

  override const Uri baseUri

  override const Version version

  override const Symbol[] depends
}

**************************************************************************
** MLibFeature
**************************************************************************

@Js
internal const class MLibFeature : MFeature
{
  new make(BFeature b) : super(b) {}

  override Type defType() { DefLib# }

  override MDef createDef(BDef b) { MLib(b) }

  override Err createUnknownErr(Str name) { UnknownLibErr(name) }
}

