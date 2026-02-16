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
** See `hx.doc.haxall::Exts#web`.
**
abstract const class ExtWeb : WebMod
{
  ** Subclass constructor
  protected new make(Ext ext) { this.extRef = ext }

  ** Parent library.  Subclasses can override this method to be covariant.
  virtual Ext ext() { extRef }
  private const Ext extRef

  ** Get the route name for this web extension. By default its
  ** the last name in the dotted lib path.  This must be a valid
  ** path name (must not contain slashes).
  virtual Str routeName() { ext.name.split('.').last }

  ** Base uri for this library's endpoint such as "/myLib/"
  Uri uri()
  {
    ext.rt.isSys ? `/${routeName}/` : `/ext/${ext.rt.name}/${routeName}`
  }

  ** Return true if this is not the UnsupportedExtWeb type
  @NoDoc virtual Bool isSupported() { true }

  ** Return true if this is the UnsupportedExtWeb type
  @NoDoc Bool isUnsupported() { !isSupported }

  ** Return priority number to use this route as the index redirect
  ** as the primary user UI.  Built in routes are less 99 or less,
  ** so use a prioirty 100+ to override the built-in UI.
  @NoDoc virtual Int indexPriority() { 0 }

  ** Return index redirect URI to use for given user context
  @NoDoc virtual Uri indexRedirect(Context cx) { `/${routeName}` }
}

**************************************************************************
** UnsupportedExtWeb
**************************************************************************

internal const class UnsupportedExtWeb : ExtWeb
{
  new make(Ext ext) : super(ext) {}
  override Str routeName() { "" }
  override Bool isSupported() { false }
  override Void onService() { res.sendErr(404) }
}

