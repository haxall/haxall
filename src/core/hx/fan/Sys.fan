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

  ** Platform hosting the runtime
  abstract Platform platform()

  ** System version
  abstract Version version()

 ** Configuration options defined at bootstrap
  @NoDoc abstract SysConfig config()

//////////////////////////////////////////////////////////////////////////
// Exts
//////////////////////////////////////////////////////////////////////////

  ** Cluster system extension (optional)
  @NoDoc abstract IClusterExt? cluster(Bool checked := true)

  ** Crypto system extension (required)
  @NoDoc abstract ICryptoExt crypto()

  ** HTTP system extension (required)
  abstract IHttpExt http()

  ** Project management (required)
  abstract IProjExt proj()

  ** User management system extension (required)
  abstract IUserExt user()


}

