//
// Copyright (c) 2021, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   14 Jun 2021  Brian Frank  Creation
//

using util
using xeto
using haystack

**
** SysInfo models the meta data of the system running Haxall.
**
const class SysInfo
{

//////////////////////////////////////////////////////////////////////////
// Construction
//////////////////////////////////////////////////////////////////////////

  **
  ** Construct with meta:
  **   - version
  **   - runtime
  **   - hostOs, hostModel, hostId?
  **   - productName, productVersion, productUri
  **   - vendorName, vendorUri
  **
  @NoDoc new make(Dict meta)
  {
    this.meta           = meta
    this.version        = Version.fromStr(meta->version)
    this.hostOs         = meta->hostOs
    this.hostModel      = meta->hostModel
    this.hostId         = meta["hostId"]
    this.rt             = SysInfoRuntime.fromStr(meta->runtime)
    this.productName    = meta->productName
    this.productVersion = meta->productVersion
    this.productUri     = meta->productUri
    this.vendorName     = meta->vendorName
    this.vendorUri      = meta->vendorUri
  }

//////////////////////////////////////////////////////////////////////////
// Host
//////////////////////////////////////////////////////////////////////////

  ** System info metadata
  const Dict meta

  ** System version
  const Version version

  ** System runtime type
  @NoDoc const SysInfoRuntime rt

  ** Host operating system platform and version
  const Str hostOs

  ** Host model
  const Str hostModel

  ** Host hardware identifier or null if not available.
  @NoDoc const Str? hostId

//////////////////////////////////////////////////////////////////////////
// Branding
//////////////////////////////////////////////////////////////////////////

  ** Product name
  const Str productName

  ** Product version
  const Str productVersion

  ** Product home page
  const Uri productUri

  ** Vendor name
  const Str vendorName

  ** Vendor home page
  const Uri vendorUri

  ** File resource for SVG logo
  @NoDoc virtual Uri logoUri() { `/user/logo.svg` }

  ** File resource for #555555 monochrome SVG logo
  @NoDoc virtual Uri logoMonoUri() { `/user/logo.svg` }

  ** File resource favicon.png image
  @NoDoc virtual Uri faviconUri() { `/user/favicon.png` }

//////////////////////////////////////////////////////////////////////////
// Debug
//////////////////////////////////////////////////////////////////////////

  ** Debug grid
  @NoDoc Grid debug()
  {
    gb := GridBuilder().addCol("name").addCol("val")
    debugEach |v, n|
    {
      if (v != null && Kind.fromVal(v, false) == null) v = v.toStr
      gb.addRow2(n, v)
    }
    return gb.toGrid
  }

  ** Debug iterate properties
  @NoDoc Void debugEach(|Obj?,Str| cb)
  {
    typeof.fields.each |f|
    {
      if (!f.isStatic && f.name != "meta")
        cb(f.get(this), f.name)
    }
    typeof.methods.each |m|
    {
      if (m.name == "debug") return
      if (m.parent != Obj# && !m.isStatic && !m.isCtor && m.params.isEmpty)
        cb(m.callOn(this, null), m.name)
    }
    meta.each |v, n|
    {
      if (typeof.slot(n, false) == null) cb(v, n)
    }
  }

  ** Debug dump
  @NoDoc Void dump(Console con := Console.cur)
  {
    debugEach |v, n| { con.info("$n: $v") }
  }
}

**************************************************************************
** SysInfoRuntime
**************************************************************************

** System runtime type
@NoDoc
enum class SysInfoRuntime
{
  hxd,
  axonsh,
  skyspark,
  xb

  Bool isHxd()      { this === hxd }
  Bool isAxonsh()   { this === axonsh }
  Bool isSkySpark() { this === skyspark }
  Bool isXb()       { this === xb }
}

