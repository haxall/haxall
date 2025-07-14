//
// Copyright (c) 2021, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   3 Aug 2021  Brian Frank  Creation
//

using concurrent
using crypto
using inet
using xeto
using haystack
using axon
using web

**
** Base class for system level only extensions
**
const mixin SysExt : Ext
{
}

**************************************************************************
** IHttpExt
**************************************************************************

**
** HTTP system extension
**
const mixin IHttpExt : SysExt
{
  ** Public HTTP or HTTPS URI of this host.  This is always
  ** an absolute URI such 'https://acme.com/'
  abstract Uri siteUri()

  ** URI on this host to the Haystack HTTP API.  This is always
  ** a host relative URI which end withs a slash such '/api/'.
  abstract Uri apiUri()

  ** Root web module
  @NoDoc abstract WebMod? root(Bool checked := true)
}

**************************************************************************
** IProjExt
**************************************************************************

**
** Project management system extension
**
@NoDoc
const mixin IProjExt : SysExt
{
  ** Lookup a project by Ref id or Str name.  If the id is not
  ** formatted as "p:" then raise exception regardless of checked flag.
  abstract Proj? get(Obj id, Bool checked := true)

  ** List all accessible projects (exclude sys)
  abstract Proj[] list()
}

**************************************************************************
** IUserExt
**************************************************************************

**
** User management system extension
**
const mixin IUserExt : SysExt
{
  ** Lookup a user by username.  If not found then raise
  ** exception or return null based on the checked flag.
  abstract User? read(Obj username, Bool checked := true)

  ** Authenticate a web request and return a context.  If request
  ** is not authenticated then redirect to login page and return null.
  ** Session information is available via `hx::Context.session`.
  abstract Context? authenticate(WebReq req, WebRes res)

  ** Close the given authentication session
  @NoDoc abstract Void closeSession(UserSession session)

  ** Create synthetic user.  The tags arg may be a dict or a map.
  @NoDoc abstract User makeSyntheticUser(Str username, Obj? tags := null)
}

**************************************************************************
** ICryptoExt
**************************************************************************

**
** Cryptographic certificate and key pair management
**
@NoDoc
const mixin ICryptoExt : SysExt
{
  ** The keystore to store all trusted keys and certificates
  abstract KeyStore keystore()

  ** Get a keystore containing only the key aliased as "https".
  abstract KeyStore? httpsKey(Bool checked := true)

  ** The host specific public/private key pair
  abstract KeyPair hostKeyPair()

  ** The host specific private key and certificate
  abstract PrivKeyEntry hostKey()

  ** Read the keystore into an in-memory buffer
  abstract Buf readBuf()

  ** Overwrite the contents of the keystore on disk with the contents of this Buf.
  abstract Void writeBuf(Buf buf)
}

**************************************************************************
** IFileExt
**************************************************************************

**
** File APIs
**
@NoDoc
const mixin IFileExt : Ext
{
  **
  ** Resolve a virtual file system URI.  If the uri does not resolve
  ** to a file, then return a File instance where exists returns false.
  ** All projects must support a sandboxed directory accessed via the
  ** relative path "io/".  The current context is used for permission
  ** checking.
  **
  abstract File resolve(Uri uri)
}

**************************************************************************
** IClusterExt
**************************************************************************

**
** Arcbeam cluster service
**
@NoDoc
const mixin IClusterExt : SysExt
{
  ** Local node id
  abstract Ref nodeId()

  ** Lookup stashed user for given node and username or raise StashSyncErr
  abstract User stashedUser(Obj node, Str username)
}

**************************************************************************
** IIOExt
**************************************************************************

**
** I/O APIs
**
@NoDoc
const mixin IIOExt : Ext
{
  **
  ** Read from an I/O handle.  The callback is invoked with the input stream
  ** and the callback's result is returned.  The input stream is guaranteed
  ** to be closed.  Raise an exception if the handle cannot be accessed
  ** as an input stream.
  **
  abstract Obj? read(Obj? handle, |InStream->Obj?| f)

  **
  ** Write to an I/O handle.  The callback is invoked with the output stream.
  ** The output stream is guaranteed to be closed.  Raise an exception if the
  ** handle cannot be accessed as an output stream.
  **
  abstract Obj? write(Obj? handle, |OutStream| f)
}

**************************************************************************
** ITaskExt
**************************************************************************

**
** Task APIs to run Axon in the background
**
@NoDoc
const mixin ITaskExt : Ext
{
  ** Get the currently running task
  abstract HxTask? cur(Bool checked := true)

  ** Run the given expression asynchronously in an ephemeral task.
  ** Return a future to track the asynchronous result.
  abstract Future run(Expr expr, Obj? msg := null)

  ** Update current task's progress info for debugging.  If not
  ** running in the context of a task, then this is a no op.
  abstract Void progress(Dict progress)

  ** Get or create an adjunct within the context of the current
  ** task.  If an adjunct is already attached to the task then return
  ** it, otherwise invoke the given function to create it.  Raise an
  ** exception if not running with the context of a task.
  abstract HxTaskAdjunct adjunct(|->HxTaskAdjunct| onInit)
}

**
** HxTask interface models the task record
**
@NoDoc
const mixin HxTask : Dict {}

**
** HxTaskAdjunct is used to bind a Fantom object as a dependency
** within the current task.  Adjuncts are initialized once on the
** first call to adjunct and receive a callback when the task is killed.
**
@NoDoc
const mixin HxTaskAdjunct
{
  ** Callback when task is killed. There is no guarantee which thread is
  ** used to make this callback, so implementations must ensure that
  ** any processing is thread-safe and non-blocking.
  virtual Void onKill() {}
}

**************************************************************************
** IHisExt
**************************************************************************

**
** Point historization APIs
**
@NoDoc
const mixin IHisExt : Ext
{
  **
  ** Read the history items stored for given point.  If span is
  ** null then all items are read, otherwise the span's inclusive
  ** start/exclusive end are used.  Leading and trailing items
  ** may be included.
  **
  abstract Void read(Dict pt, Span? span, Dict? opts, |HisItem| f)

  **
  ** Write history items to the given point.  The items must have
  ** have a matching timezone, value kind, and unit (or be unitless).
  ** Before writing the timestamps are normalized to 1sec or 1ms precision;
  ** items with duplicate normalized timestamps are removed.  If there is
  ** existing history data with a given timestamp then the new data overwrites
  ** the current value, or if the new item's value is `haystack::Remove.val`
  ** then that item is removed.
  **
  abstract Future write(Dict pt, HisItem[] items, Dict? opts := null)
}

**************************************************************************
** IPointExt
**************************************************************************

**
** Point extension is used to override writable points.
**
@NoDoc
const mixin IPointExt : Ext
{
  **
  ** Set a writable point's priority array value at the given level.
  ** Level must be 1 to 17 (where 17 represents default value).  The
  ** who parameter must be a non-empty string which represent debugging
  ** information about which user or application is writing to this
  ** priorirty array level.
  **
  abstract Future pointWrite(Dict point, Obj? val, Int level, Obj who, Dict? opts := null)

  **
  ** Get current state of a writable points priority array.  The result
  ** is a grid with 17 rows including a 'level' and 'val' column.
  **
  abstract Grid pointArray(Dict point)
}

**************************************************************************
** IConnExt
**************************************************************************

**
** Connector extension manages the roster of enabled connector libraries,
** connectors, and points.
**
@NoDoc
const mixin IConnExt : Ext
{
  ** List of installed connector libraries
  abstract HxConnExt[] exts()

  ** Lookup of installed connector library by name
  abstract HxConnExt? ext(Str name, Bool checked := true)

  ** List of connectors across all installed libraries
  abstract HxConn[] conns()

  ** Lookup of connector from any installed library
  abstract HxConn? conn(Ref id, Bool checked := true)

  ** Return if given id maps to a connector record
  abstract Bool isConn(Ref id)

  ** List of connector points across all installed libraries
  abstract HxConnPoint[] points()

  ** Lookup of connector point from any installed library
  abstract HxConnPoint? point(Ref id, Bool checked := true)

  ** Return if given id maps to a connector point record
  abstract Bool isPoint(Ref id)
}

**
** HxConnExt models a subtype of ConnExt which models a specific protocol
**
@NoDoc
const mixin HxConnExt
{
  ** Library name
  abstract Str name()

  ** Display name to use for connector library
  abstract Str extDis()

  ** Icon logical name to use for this connector type library
  abstract Str icon()

  ** Tag name for the connector records such as 'bacnetConn'
  abstract Str connTag()

  ** Tag name for the connector records such as 'bacnetConnRef'
  abstract Str connRefTag()

  ** Number of configured connectors
  abstract Int numConns()

  ** Dict with markers for supported features: learn, cur, write, his
  abstract Dict connFeatures()
}

**
** HxConn models a connector record
**
@NoDoc
const mixin HxConn
{
  ** Parent connector extension
  abstract HxConnExt ext()

  ** Record id
  abstract Ref id()

  ** Current version of the record.
  ** This dict only represents the current persistent tags.
  ** It does not track transient changes such as 'connStatus'.
  abstract Dict rec()

  ** Ping the connector
  abstract Future ping()

  ** Force connector closed
  abstract Future close()

  ** Make a learn request to the connector.  Future result is learn grid.
  abstract Future learnAsync(Obj? arg := null)

  ** Debug details
  abstract Str details()
}

**
** HxConnPoint models a connector point record
**
@NoDoc
const mixin HxConnPoint
{
  ** Parent connector library
  abstract Ext ext()

  ** Parent connector
  abstract HxConn conn()

  ** Record id
  abstract Ref id()

  ** Current version of the record.
  ** This dict only represents the current persistent tags.
  ** It does not track transient changes such as 'connStatus'.
  abstract Dict rec()

  ** Debug details
  abstract Str details()
}

**************************************************************************
** HxDockerService
**************************************************************************

/* TODO
**
** HxDockerService manages Docker containers
**
@NoDoc
const mixin HxDockerService : HxService
{
  ** Run a Docker image using the given container configuration.
  ** Returns the `HxDockerContainer` that was created.
  HxDockerContainer run(Str image, Obj config) { runAsync(image, config).get }

  ** Async version of `run`. Returns a Future that is completed
  ** with the container id once it is started.
  abstract Future runAsync(Str image, Obj config)

  ** Kill the container with the given id, and then remove it
  abstract Dict deleteContainer(Str id)
}

**
** Models a Docker container
**
@NoDoc
const mixin HxDockerContainer
{
  ** The id of the container
  abstract Str id()

  ** The names that this container has been given
  abstract Str[] names()

  ** The name of the image used when creating the container
  abstract Str image()

  ** The timestamp when the container was created
  abstract DateTime created()

  ** Addtional human-readable status of this container
  abstract Str state()

  ** Get the network endpoint settings for the docker network with the given name
  abstract HxDockerEndpoint? network(Str name)
}

**
** Models a Docker container network endpoint
**
@NoDoc
const mixin HxDockerEndpoint
{
  ** The IPv4 network gateway
  abstract IpAddr? gateway()

  ** The IPv4 address
  abstract IpAddr? ip()

  ** The IPv6 network gateway
  abstract IpAddr? gateway6()

  ** The IPv6 address
  abstract IpAddr? ip6()
}
*/

