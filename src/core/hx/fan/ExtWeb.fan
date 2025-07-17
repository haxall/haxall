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

  ** System for parent extension
  virtual Sys sys() { extRef.sys }

  ** Project for parent extension
  virtual Proj proj() { extRef.proj }

  ** Parent library.  Subclasses can override this method to be covariant.
  virtual Ext ext() { extRef }
  private const Ext extRef

  ** Base uri for this library's endpoint such as "/myLib/"
  Uri uri() { ext.spi.webUri }

  ** Get the route name for this web extension. By default its
  ** the last name in the dotted lib path.  This must be a valid
  ** path name (must not contain slashes).
  virtual Str routeName() { ext.name.split('.').last }

  ** Is the unsupported no-up default instance
  @NoDoc virtual Bool isUnsupported() { false }

}

**************************************************************************
** UnsupportedExtWeb
**************************************************************************

internal const class UnsupportedExtWeb : ExtWeb
{
  new make(Ext lib) : super(lib) {}
  override Str routeName() { "" }
  override Bool isUnsupported() { true }
  override Void onService() { res.sendErr(404) }
}

