//
// Copyright (c) 2021, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   18 May 2021  Brian Frank  Creation
//    8 Jul 2025  Brian Frank  Redesign from HxLib
//

using concurrent
using web
using xeto
using haystack
using obs
using folio

**
** Extension
**
const mixin Ext
{

//////////////////////////////////////////////////////////////////////////
// Identity
//////////////////////////////////////////////////////////////////////////

  ** Runtime which is proj if project ext or sys if system ext
  virtual Runtime rt() { spi.rt }

  ** System
  virtual Sys sys() { spi.sys }

  ** Project if a project extension, otherwise raise exception
  virtual Proj proj() { spi.proj(true) }

  ** Library dotted name that identifies the extension
  Str name() { spi.name }

  ** Xeto spec for this extension
  Spec spec() { spi.spec }

  ** Settings for the extension
  virtual Dict settings() { spi.settings }

  ** Asynchronously update settings with Str:Obj, Dict, or Diff.
  @NoDoc Void settingsUpdate(Obj changes) { spi.settingsUpdate(changes, false) }

  ** Logger to use for this extension
  Log log() { spi.log }

  ** Web service handling for this extension
  virtual ExtWeb web() { UnsupportedExtWeb(this) }

  ** Get an upload handler for this extenstion
  @NoDoc virtual UploadHandler uploadHandler(WebReq req, WebRes res, Dict opts)
  {
    UploadHandler(req, res, opts)
  }

  ** Initialize a feed from a subscription request for this library
  @NoDoc virtual Feed feedInit(Dict req, Context cx)
  {
    throw Err("Ext does not support feedInit: $name")
  }

  ** Service provider interface
  @NoDoc abstract ExtSpi spi()

//////////////////////////////////////////////////////////////////////////
// Observables
//////////////////////////////////////////////////////////////////////////

  ** Return list of observables this extension publishes.  This method
  ** must be overridden as a const field and set in the constructor.
  virtual Observable[] observables() { Observable#.emptyList }

  ** Observable subscriptions for this extension
  Subscription[] subscriptions() { spi.subscriptions }

  ** Subscribe this library to an observable. The callback must be an
  ** Actor instance or Method literal on this class.  If callback is a
  ** method, then its called on the lib's dedicated background actor.
  ** pool. This method should be called in the `onStart` callback.
  ** The observation is automatically unsubscribed on stop.  You should
  ** **not** unsubscribe this subscription - it must be managed by the
  ** extension itself.  See `docHaxall::Observables#fantomObserve`.
  Subscription observe(Str name, Dict config, Obj callback) { spi.observe(name, config, callback) }

//////////////////////////////////////////////////////////////////////////
// Lifecycle Callbacks
//////////////////////////////////////////////////////////////////////////

  ** Running flag.  On startup this flag transitions to true before calling
  ** ready and start on the library.  On shutdown this flag transitions
  ** to false before calling unready and stop on the library.
  Bool isRunning() { spi.isRunning }

  ** Callback when library is started.
  ** This is called on dedicated background actor.
  virtual Void onStart() {}

  ** Callback when all libs are fully started.
  ** This is called on dedicated background actor.
  virtual Void onReady() {}

  ** Callback before we stop the project
  ** This is called on dedicated background actor.
  virtual Void onUnready() {}

  ** Callback when extension is stopped.
  ** This is called on dedicated background actor.
  virtual Void onStop() {}

  ** Callback when extension reaches steady state.
  ** This is called on dedicated background actor.
  virtual Void onSteadyState() {}

  ** Callback when associated settings are modified.
  ** This is called on dedicated background actor.
  virtual Void onSettings() {}

  ** Callback made periodically to perform background tasks.
  ** Override `houseKeepingFreq` to enable the frequency of this callback.
  virtual Void onHouseKeeping() {}

  ** Override to return non-null for onHouseKeeping callback
  virtual Duration? houseKeepingFreq() { null }

  ** System reload of pods and xeto libs callback
  ** This is called on dedicated background actor.
  @NoDoc virtual Void onSysReload() {}

  ** Callback to handle a non-standard actor message to this library.
  @NoDoc virtual Obj? onReceive(HxMsg msg)
  {
    throw UnsupportedErr("Unknown msg: $msg")
  }
}

**************************************************************************
** ExtObj
**************************************************************************

**
** Base class for all `Ext` implementations
**
abstract const class ExtObj : Ext
{
  ** All subclasses must declare public no-arg constructor.
  new make()
  {
    this.spi = Actor.locals["hx.spi"] as ExtSpi ?: throw Err("Invalid make context")
  }

  ** Identity hash
  override final Int hash() { super.hash }

  ** Equality is based on reference equality
  override final Bool equals(Obj? that) { this === that }

  ** Return `name`
  override final Str toStr() { name }

  @NoDoc
  const override ExtSpi spi
}

**************************************************************************
** ExtSpi
**************************************************************************

**
** Ext service provider interface
**
@NoDoc
const mixin ExtSpi
{
  abstract Runtime rt()
  abstract Sys sys()
  abstract Proj? proj(Bool checked)
  abstract Str name()
  abstract Spec spec()
  abstract Dict settings()
  abstract Void settingsUpdate(Obj changes, Bool reset)
  abstract Log log()
  abstract Bool isRunning()
  abstract Future send(Obj? msg)
  abstract Actor actor()
  abstract Void sync(Duration? timeout := 30sec)
  abstract Subscription[] subscriptions()
  abstract Subscription observe(Str name, Dict config, Obj callback)
  abstract Bool isFault()
}

**************************************************************************
** UploadHandler
**************************************************************************

**
** Ext support for uploading files
**
@NoDoc
class UploadHandler
{
  new make(WebReq req, WebRes res, Dict opts)
  {
    this.req  = req
    this.res  = res
    this.opts = opts
  }

  Context cx() { Context.cur }
  WebReq req { private set }
  WebRes res { private set }
  const Dict opts

  ** Get the requested upload path for this ext
  Uri? path() { opts["path"] }

  ** Handle file upload.
  **
  ** Return a Haystack value that should be returned to the client, or you may commit
  ** the response yourself, in which case the return value is ignored.
  virtual Obj? upload()
  {
    res.sendErr(404)
    return null
  }

  ** Send and commit an error response to the client.
  protected Obj? sendErr(Int code, Str? msg := null)
  {
    res.sendErr(code, msg)
    return null
  }

  ** If the file exists, should it be renamed so as to avoid overwriting the existing file
  protected Bool isRename() { req.method == "POST" }

  ** Create a unique file or directory
  protected File uniquify(File file)
  {
    iter     := 0
    isDir    := file.isDir
    baseDir  := file.parent ?: throw ArgErr("Cannot create new root: $file")
    nameUri  := file.name.toUri
    basename := nameUri.basename
    ext      := isDir ? "" : ".${nameUri.ext}"
    testUri  := nameUri
    while (iter < 1_000)
    {
      if (isDir) testUri = testUri.plusSlash

      target := baseDir + testUri
      if (!target.exists) return target

      ++iter
      suffix := iter.toLocale("0000")
      testUri = `${basename}-${suffix}${ext}`
    }
    throw IOErr("Too many files prefixed with ${nameUri.toCode} in ${baseDir}")
  }
}