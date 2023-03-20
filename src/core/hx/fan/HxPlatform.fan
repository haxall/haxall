//
// Copyright (c) 2021, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   14 Jun 2021  Brian Frank  Creation
//

using concurrent
using web
using haystack
using folio

**
** HxPlatform models the host platform running Haxall
**
const class HxPlatform
{
  ** Construct with meta data dict
  new make(Dict meta)
  {
    this.metaRef = meta
    this.isShell = meta.has("axonsh")
  }

  ** Meta data
  virtual Dict meta() { metaRef }
  private const Dict metaRef

  ** Operating system name - see `sys::Env.os`
  virtual Str os() { Env.cur.os }

  ** Microprocessor architecture - see `sys::Env.arch`
  virtual Str arch() { Env.cur.arch }

  ** Is this the full SkySpark runtime
  virtual Bool isSkySpark() { false }

  ** Relative URI to the SVG logo
  virtual Uri logoUri() { meta["logoUri"] as Uri ?: `/hxUser/logo.svg` }

  ** Product name for about op
  virtual Str productName() { meta["productName"] as Str ?: "Haxall" }

  ** Product version for about op
  virtual Str productVersion() { meta["productVersion"] as Str ?: typeof.pod.version.toStr }

  ** Product home page for about op
  virtual Uri productUri() { meta["productUri"] as Uri ?: `https://haxall.io/` }

  ** Vendor name for about op
  virtual Str vendorName() { meta["vendorName"] as Str ?: "SkyFoundry" }

  ** Vendor home page for about op
  virtual Uri vendorUri() { meta["vendorUri"] as Uri ?: `https://skyfoundry.com/` }

  ** Host operating system platform and version
  virtual Str hostOs() { meta["hostOs"] as Str ?: "$os $arch " + Env.cur.vars["os.version"] }

  ** Host model
  virtual Str hostModel() { meta["hostModel"] as Str ?: productName + " (" + Env.cur.vars["os.name"] + ")" }

  ** Is this the axon shell
  @NoDoc const Bool isShell

}

