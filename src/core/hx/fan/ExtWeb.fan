//
// Copyright (c) 2021, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   24 May 2021  Brian Frank  Creation
//

using concurrent
using web

**
** Ext plugin to add web servicing capability.
** See `docHaxall::Libs#web`.
**
abstract const class ExtWeb : WebMod
{
  ** Subclass constructor
  protected new make(Ext ext) { this.extRef = ext }

  ** Runtime for parent library
  virtual Proj rt() { extRef.rt }

  ** Parent library.  Subclasses can override this method to be covariant.
  virtual Ext ext() { extRef }
  private const Ext extRef

  ** Base uri for this library's endpoint such as "/myLib/"
  Uri uri() { ext.spi.webUri }

  ** Is the unsupported no-up default instance
  @NoDoc virtual Bool isUnsupported() { false }

}

**************************************************************************
** UnsupportedExtWeb
**************************************************************************

internal const class UnsupportedExtWeb : ExtWeb
{
  new make(Ext lib) : super(lib) {}
  override Bool isUnsupported() { true }
  override Void onService() { res.sendErr(404) }
}

