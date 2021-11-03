//
// Copyright (c) 2021, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   18 Oct 2021  Matthew Giannini  Creation
//

using concurrent
using inet
using util
using haystack
using hx

**
** PyMgr
**
internal const class PyMgr : Actor
{

//////////////////////////////////////////////////////////////////////////
// Constructor
//////////////////////////////////////////////////////////////////////////

  new make(PyLib lib, |This|? f := null) : super(lib.rt.libs.actorPool)
  {
    f?.call(this)
    this.lib = lib
  }

  internal const PyLib lib
  private Log log() { lib.log }
  private const ConcurrentMap sessions := ConcurrentMap()
  private const AtomicBool running := AtomicBool(true)

  private static const Duration timeout := 10sec

  private PyDockerSession? lookup(Str id) { ((Unsafe?)sessions.get(id))?.val }

//////////////////////////////////////////////////////////////////////////
// PyMgr
//////////////////////////////////////////////////////////////////////////

  PySession open(Dict? opts := null, Duration? timeout := PyMgr.timeout)
  {
    send(HxMsg("open", opts)).get(timeout)->val
  }

  Void shutdown(Duration? timeout := PyMgr.timeout)
  {
    send(HxMsg("shutdown")).get(timeout)
  }

//////////////////////////////////////////////////////////////////////////
// Actor
//////////////////////////////////////////////////////////////////////////

  protected override Obj? receive(Obj? obj)
  {
    msg := (HxMsg)obj
    switch (msg.id)
    {
      case "open":     return onOpen(msg.a)
      case "shutdown": return onShutdown
    }
    throw UnsupportedErr("$msg")
  }

//////////////////////////////////////////////////////////////////////////
// Open
//////////////////////////////////////////////////////////////////////////

  private Unsafe onOpen(Dict? opts)
  {
    if (!running.val) throw Err("Not running")

    session := PyDockerSession(this, opts ?: Etc.emptyDict)
    ref := Unsafe(session)
    sessions.add(session.cid, ref)
    return ref
  }

//////////////////////////////////////////////////////////////////////////
// Close
//////////////////////////////////////////////////////////////////////////

  internal Obj? onClose(Str id)
  {
    session := lookup(id)
    session?.close
    sessions.remove(id)
    return id
  }

//////////////////////////////////////////////////////////////////////////
// Shutdown
//////////////////////////////////////////////////////////////////////////

  private Obj? onShutdown()
  {
    running.val = false
    sessions.each |Unsafe ref, Str id|
    {
      log.info("Killing python session: $id")
      onClose(id)
    }
    return null
  }
}

**************************************************************************
** PyDockerSession
**************************************************************************

internal class PyDockerSession : PySession
{

//////////////////////////////////////////////////////////////////////////
// Constructor
//////////////////////////////////////////////////////////////////////////

  new open(PyMgr mgr, Dict opts)
  {
    this.mgr  = mgr
    this.opts = opts

    // run docker container
    image  := opts.get("image", "hxpy:latest")
    key    := Uuid()
    level  := ((Str)opts.get("logLevel", "WARN" )).upper
    port   := findOpenPort
    config := Str:Obj?[
      "cmd": ["-m", "hxpy", "--key", "$key", "--level", level],
      "exposedPorts": ["8888/tcp": [:]],
      "hostConfig": Str:Obj?[
        "portBindings": [
          "8888/tcp": [ ["hostPort": "$port"] ],
        ],
      ],
    ]

    this.cid = dockerService.run(image, config)

    // now connect the HxpySession
    try
    {
      this.session = HxpySession.open(`tcp://localhost:${port}?key=${key}`)
    }
    catch (Err err)
    {
      this.close
      throw err
    }

    // configure timeout
    t := opts.get("timeout") as Number
    if (t != null) session.timeout(t.toDuration)
  }

  ** This assume the docker daemon is running on the localhost. If we remove
  ** that assumption then we need to configure a port range for hxPy and
  ** explicitly cycle through that port range instead of finding random port.
  private static Int findOpenPort(Range range := Range.makeInclusive(49152, 65532))
  {
    attempts := 100
    i := 1
    r := Random.makeSecure
    port := r.next(range)
    while (i <= attempts)
    {
      s := TcpSocket()
      try
      {
        s.bind(IpAddr("localhost"), port)
        return port
      }
      catch (Err ignore) { }
      finally { s.close }
      ++i
    }
    throw IOErr("Cannot find free port in $range after $attempts attempts")
  }

  private const PyMgr mgr
  private Log log() { mgr.lib.log }
  private HxDockerService dockerService() { mgr.lib.rt.services.get(HxDockerService#) }

  ** Session options
  private const Dict opts

  ** Docker container id spawned by this session
  internal const Str cid

  ** HxpySession
  private HxpySession? session

//////////////////////////////////////////////////////////////////////////
// PySession
//////////////////////////////////////////////////////////////////////////

  override This define(Str name, Obj? val)
  {
    session.define(name, val)
    return this
  }

  override This exec(Str code)
  {
    session.exec(code)
    return this
  }

  override This timeout(Duration? dur)
  {
    session.timeout(dur)
    return this
  }

  override Obj? eval(Str code)
  {
    try
    {
      return session.eval(code)
    }
    catch (TimeoutErr err)
    {
      mgr.onClose(cid)
      throw err
    }
  }

  override This close()
  {
    // delete the container
    try
    {
      dockerService.deleteContainer(this.cid)
    }
    catch (Err err)
    {
      log.err("Failed to delete container $cid", err)
    }

    // close the session
    session?.close

    return this
  }

}
