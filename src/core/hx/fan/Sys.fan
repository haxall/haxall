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
  @NoDoc virtual IClusterExt? cluster(Bool checked := true) { exts.getByType(IClusterExt#, checked) }

  ** Crypto system extension (required)
  @NoDoc virtual ICryptoExt crypto() { exts.getByType(ICryptoExt#) }

  ** File system extension (required)
  @NoDoc virtual IFileExt file() { exts.getByType(IFileExt#) }

  ** Ion user interface system extension (optional)
  @NoDoc virtual IIonExt? ion(Bool checked := true) { exts.getByType(IIonExt#, checked) }

  ** HTTP system extension (required, but not in tests)
  @NoDoc virtual IHttpExt http() { exts.getByType(IHttpExt#) }

  ** Platform management system extension (optional)
  @NoDoc virtual IPlatformExt? platform(Bool checked := true)  { exts.getByType(IPlatformExt#, checked) }

  ** Project management system extension (required)
  @NoDoc virtual IProjExt proj() { exts.getByType(IProjExt#) }

  ** User management system extension (required)
  @NoDoc virtual IUserExt user()  { exts.getByType(IUserExt#) }
}

