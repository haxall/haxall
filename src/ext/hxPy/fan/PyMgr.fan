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
using xeto
using haystack
using docker
using hx
using hxDocker

**
** PyMgr
**
internal const class PyMgr : Actor
{

//////////////////////////////////////////////////////////////////////////
// Constructor
//////////////////////////////////////////////////////////////////////////

  new make(PyExt ext, |This|? f := null) : super(ext.proj.exts.actorPool)
  {
    f?.call(this)
    this.ext = ext
  }

  internal const PyExt ext
  private Log log() { ext.log }
  private const ConcurrentMap sessions := ConcurrentMap()
  private const AtomicBool running := AtomicBool(true)

  private static const Duration timeout := 10sec

  private PyDockerSession? lookup(Str id) { ((Unsafe?)sessions.get(id))?.val }

//////////////////////////////////////////////////////////////////////////
// PyMgr
//////////////////////////////////////////////////////////////////////////

  PySession openSession(Dict? opts := null)
  {
    taskSession(opts) ?: createSession(opts)
  }

  Void shutdown(Duration? timeout := PyMgr.timeout)
  {
    send(HxMsg("shutdown")).get(timeout)
  }

  internal PyMgrSession? taskSession(Dict? opts := null)
  {
    try
    {
      tasks := (ITaskExt)ext.proj.ext("hx.task")
      return tasks.adjunct |->HxTaskAdjunct| { createSession(opts) }
    }
    catch (Err err)
    {
      return null
    }
  }

  private PyMgrSession createSession(Dict? opts)
  {
    send(HxMsg("open", PyMgrSession(this, opts ?: Etc.dict0).open)).get(timeout)
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

  private PyMgrSession onOpen(PyMgrSession session)
  {
    if (!running.val) throw Err("Not running")

    sessions.add(session.id, session)
    return session
  }

//////////////////////////////////////////////////////////////////////////
// Close
//////////////////////////////////////////////////////////////////////////

  // deallocates (does not close) the session
  internal Void removeSession(PyMgrSession session)
  {
    sessions.remove(session.id)
  }

//////////////////////////////////////////////////////////////////////////
// Shutdown
//////////////////////////////////////////////////////////////////////////

  private Obj? onShutdown()
  {
    running.val = false
    sessions.each |PyMgrSession session, Uuid id|
    {
      log.info("Killing python session: $id")
      session.onKill
    }
    return null
  }
}

**************************************************************************
** PyMgrSession
**************************************************************************

internal const class PyMgrSession : PySession, HxTaskAdjunct
{
  new make(PyMgr mgr, Dict opts)
  {
    this.id   = Uuid()
    this.mgr  = mgr
    this.opts = opts
  }

  const Uuid id
  const PyMgr mgr
  const Dict opts
  PySession session() { ((Unsafe)sessionRef.val).val }
  private const AtomicRef sessionRef := AtomicRef()

  private Log log() { mgr.ext.log }

  private Bool isClosed() { sessionRef.val == null }

//////////////////////////////////////////////////////////////////////////
// Open
//////////////////////////////////////////////////////////////////////////

  This open()
  {
    if (!isClosed) throw Err("Already open")

    docker := (DockerExt)mgr.ext.proj.ext("hx.docker")
    s := PyDockerSession(docker, opts)
    sessionRef.val = Unsafe(s)
    return this
  }

//////////////////////////////////////////////////////////////////////////
// PySession
//////////////////////////////////////////////////////////////////////////

  override This init(|PySession session| fn)
  {
    session.init(fn)
    return this
  }

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
      this.close
      if (inTask) this.restart
      throw err
    }
    catch (Err err)
    {
      if (inTask) this.restart
      throw err
    }
  }

  override This close()
  {
    // kill the session if not running in a task
    if (!inTask) onKill
    return this
  }

  ** Restart the session, but only if running in a task
  private Void restart()
  {
    if (!inTask) return
    try
    {
      onClose
      this.open
    }
    catch (Err err)
    {
      onRemoveSession
      log.err("Could not restart persistent session. Killing it.", err)
      throw err
    }
  }

  private Void onClose()
  {
    if (isClosed) return
    try { session.close } catch (Err err) { log.err("Failed to close session", err) }
    sessionRef.val = null
  }

  private Void onRemoveSession()
  {
    mgr.removeSession(this)
  }

//////////////////////////////////////////////////////////////////////////
// HxTaskAdjunct
//////////////////////////////////////////////////////////////////////////

  override Void onKill()
  {
    // kill the session
    session.kill

    // close the session
    onClose

    // deallocate python mgr session
    onRemoveSession
  }

//////////////////////////////////////////////////////////////////////////
// Util
//////////////////////////////////////////////////////////////////////////

  private Bool inTask() { mgr.taskSession != null }
}

**************************************************************************
** PyDockerSession
**************************************************************************

internal class PyDockerSession : PySession
{

//////////////////////////////////////////////////////////////////////////
// Constructor
//////////////////////////////////////////////////////////////////////////

  new make(DockerExt dockerExt, Dict opts)
  {
    this.dockerExt = dockerExt
    this.opts = opts

    // Create an un-opened HxpySession. It will be lazily opened on the first eval()
    this.session = HxpySession()

    // configure timeout
    t := opts.get("timeout") as Number
    if (t != null) session.timeout(t.toDuration)
  }

  ** The Docker Ext
  private const DockerExt dockerExt

  ** Convenience to get docker manager
  private DockerMgr dockerMgr() { dockerExt.mgr }

  ** Session options
  private const Dict opts

  ** HxpySession
  private HxpySession session

  ** Has the init() callback been called on the underlying session
  private Bool isInitialized := false

  ** Docker container spawned by this session
  internal DockerContainer? container := null

//////////////////////////////////////////////////////////////////////////
// Open
//////////////////////////////////////////////////////////////////////////

  private HxpySession openSession()
  {
    if (this.session.isConnected) return this.session

    // run docker container
    key    := Uuid()
    level  := (opts.get("logLevel")?.toStr ?: "WARN").upper
    net    := opts.get("network")
    port   := (opts.get("port") as Number)?.toInt ?: findOpenPort
    hostConfig := Str:Obj?[
      "portBindings": [
          "${port}/tcp": [ ["hostPort": "$port"] ],
      ],
      "networkMode": net,
    ]
    config := Str:Obj?[
      "cmd": ["-m", "hxpy", "--key", "$key", "--port", "${port}", "--level", level],
      "exposedPorts": ["${port}/tcp": [:]],
      "hostConfig": hostConfig,
    ]

    // find the image to run and start it
    errs := Err[,]
    this.container = priorityImageNames(opts).eachWhile |image->DockerContainer?|
    {
      try
      {
        return dockerMgr.run(image, config)
      }
      catch (Err err)
      {
        errs.add(err)
        return null
      }
    }
    if (container == null)
    {
      errs.each { it.trace }
      throw Err("Could not run any of these docker images: ${priorityImageNames(opts)}.\nSee the stack trace above for reasons.")
    }

    // determine the host address to connect to. if a docker network
    // was specified (for docker within docker use case), then use the ip address
    // of the container that was created
    host := "localhost"
    if (net != null)
    {
      host = container.network(net).ipv4.toStr
    }

    // now connect the HxpySession with retries. retry is necessary because the
    // container might have started, but the python hxpy server might not yet
    // have opened the port for accepting connections
    retry := (opts.get("maxRetry") as Number)?.toInt ?: 5
    uri   := `tcp://${host}:${port}?key=${key}`
    while (true)
    {
      try
      {
        this.session.connect(uri)
        break
      }
      catch (Err err)
      {
        if (--retry < 0)
        {
          this.close
          throw IOErr("Failed to connect to $uri", err)
        }
      }
      // sleep 1sec before retry
      Actor.sleep(1sec)
    }

    return this.session
  }

  private static Str[] priorityImageNames(Dict opts)
  {
    // check if image name is explicitly specified
    x := opts.get("image") as Str
    if (x != null) return [x]

    // otherwise, try in this order
    ver := PyMgr#.pod.version
    return [
      "ghcr.io/haxall/hxpy:${ver}",
      "ghcr.io/haxall/hxpy:latest",
      "ghcr.io/haxall/hxpy:main",
    ]
  }

  ** This assume the docker daemon is running on the localhost. If we remove
  ** that assumption then we need to configure a port range for hxPy and
  ** explicitly cycle through that port range instead of finding random port.
  private static Int findOpenPort(Range range := Range.makeInclusive(10000, 30000))
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

//////////////////////////////////////////////////////////////////////////
// PySession
//////////////////////////////////////////////////////////////////////////

  override This init(|PySession| fn)
  {
    // want to call with *this* as the session
    // cb := |PySession py| { fn.call(this) }
    if (!isInitialized)
      session.init { fn.call(this); this.isInitialized = true }
    return this
  }

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
      // lazily open the session and then eval the code
      return openSession.eval(code)
    }
    // only catch timeout errors so we can keep around exited containers for inspection
    catch (TimeoutErr err)
    {
      this.close
      throw err
    }
  }

  override This close()
  {
    // delete the container
    try
    {
      if (this.container != null)
      {
        dockerMgr.deleteContainer(container.id)
        this.container = null
      }
    }
    catch (Err ignore)
    {
      // log.err("Failed to delete container $cid", err)
    }

    // close the session
    session.close

    return this
  }

}

