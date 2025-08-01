//
// Copyright (c) 2021, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   18 May 2021  Brian Frank  Creation
//   13 Jul 2025  Brian Frank  Redesign from HxRuntimeLibs
//

**
** System is the host level project in multi-tenant systems
**
const mixin Sys : Proj
{

//////////////////////////////////////////////////////////////////////////
// Identity
//////////////////////////////////////////////////////////////////////////

  ** System metadata
  abstract SysInfo info()

  ** System configuration
  @NoDoc abstract SysConfig config()

//////////////////////////////////////////////////////////////////////////
// Exts
//////////////////////////////////////////////////////////////////////////

  ** Cluster system extension (optional)
  @NoDoc abstract IClusterExt? cluster(Bool checked := true)

  ** Crypto system extension (required)
  @NoDoc abstract ICryptoExt crypto()

  ** Ion user interface system extension (optional)
  @NoDoc abstract IIonExt? ion(Bool checked := true)

  ** HTTP system extension (required, but not in tests)
  @NoDoc abstract IHttpExt http()

  ** Platform management system extension (optional)
  @NoDoc abstract IPlatformExt? platform(Bool checked := true)

  ** Project management (required)
  @NoDoc abstract IProjExt proj()

  ** User management system extension (required)
  @NoDoc abstract IUserExt user()


}

