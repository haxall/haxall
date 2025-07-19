//
// Copyright (c) 2021, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   14 Jun 2021  Brian Frank  Creation
//

using xeto
using util

**
** SysInfo models the meta data of the system running Haxall.
**
const class SysInfo
{

//////////////////////////////////////////////////////////////////////////
// Construction
//////////////////////////////////////////////////////////////////////////

  **
  ** Construct with meta/config
  ** Meta:
  **   - version (required)
  **   - runtime (required)
  **   - hostOs, hostModel
  **   - productName, productVersion, productUri
  **   - vendorName, vendorUri
  ** Config:
  **   - test
  **
  @NoDoc new make(Dict meta)
  {
    this.metaRef    = meta
    this.versionRef = Version.fromStr(meta->version)
    this.rtRef      = SysInfoRuntime.fromStr(meta->runtime)
  }

//////////////////////////////////////////////////////////////////////////
// Host
//////////////////////////////////////////////////////////////////////////

  ** System info metadata
  Dict meta() { metaRef }
  private const Dict metaRef

  ** System version
  Version version() { versionRef }
  private const Version versionRef

  ** Operating system name - see `sys::Env.os`
  virtual Str os() { Env.cur.os }

  ** Microprocessor architecture - see `sys::Env.arch`
  virtual Str arch() { Env.cur.arch }

  ** Host operating system platform and version
  virtual Str hostOs() { meta["hostOs"] as Str ?: "$os $arch " + Env.cur.vars["os.version"] }

  ** Host model
  virtual Str hostModel() { meta["hostModel"] as Str ?: productName + " (" + Env.cur.vars["os.name"] + ")" }

  ** Host hardware identifier or null if not available.
  @NoDoc Str? hostId() { null }

  ** System runtime type
  @NoDoc SysInfoRuntime rt() { rtRef }
  private const SysInfoRuntime rtRef

//////////////////////////////////////////////////////////////////////////
// Branding
//////////////////////////////////////////////////////////////////////////

  ** Product name
  virtual Str productName() { meta["productName"] as Str ?: "Haxall" }

  ** Product version
  virtual Str productVersion() { meta["productVersion"] as Str ?: typeof.pod.version.toStr }

  ** Product home page
  virtual Uri productUri() { meta["productUri"] as Uri ?: `https://haxall.io/` }

  ** Vendor name
  virtual Str vendorName() { meta["vendorName"] as Str ?: "SkyFoundry" }

  ** Vendor home page
  virtual Uri vendorUri() { meta["vendorUri"] as Uri ?: `https://skyfoundry.com/` }

  ** Relative URI to the SVG logo
  @NoDoc virtual Uri logoUri() { `/user/logo.svg` }

  ** Relative URI to the #555555 monochrome SVG logo
  @NoDoc virtual Uri logoMonoUri() { `/user/logo.svg` }

  ** Relative URI to favicon.png image
  @NoDoc virtual Uri faviconUri() { `/user/favicon.png` }

//////////////////////////////////////////////////////////////////////////
// Debug
//////////////////////////////////////////////////////////////////////////

  ** Debug dump
  @NoDoc Void dump(Console con := Console.cur)
  {
    typeof.methods.each |m|
    {
      if (m.parent != Obj# && !m.isStatic && !m.isCtor && m.params.isEmpty)
        con.info("$m.name: " + m.callOn(this, null))
    }
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

