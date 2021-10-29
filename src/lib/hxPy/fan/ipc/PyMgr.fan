//
// Copyright (c) 2021, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   10 Sep 2021  Matthew Giannini  Creation
//

using concurrent
using haystack
using hx

**
** PyMgr handles allocation of python processes for IPC
**
@NoDoc const class PyMgr : Actor
{

//////////////////////////////////////////////////////////////////////////
// Constructor
//////////////////////////////////////////////////////////////////////////

  new make(ActorPool pool, |This|? f := null) : super(pool)
  {
    f?.call(this)
  }

  const Log log := Log.get(pool.name)
  private const ConcurrentMap processes := ConcurrentMap()
  private const AtomicBool running := AtomicBool(true)

//////////////////////////////////////////////////////////////////////////
// ProcessMgr
//////////////////////////////////////////////////////////////////////////

  PyIpc alloc(Dict? opts := null, Duration? timeout := 10sec)
  {
    send(HxMsg("alloc", opts)).get(timeout)->val
  }

  internal Str dealloc(Str pid, Duration? timeout := 10sec)
  {
    send(HxMsg("dealloc", pid)).get(timeout)
  }

  Void kill(Duration? timeout := 10sec)
  {
    send(HxMsg("kill")).get(timeout)
  }

//////////////////////////////////////////////////////////////////////////
// Actor
//////////////////////////////////////////////////////////////////////////

  protected override Obj? receive(Obj? obj)
  {
    msg := (HxMsg)obj
    switch (msg.id)
    {
      case "alloc":   return onAlloc(msg.a)
      case "dealloc": return onDealloc(msg.a)
      case "kill":    return onKill
    }
    throw UnsupportedErr("$msg")
  }

  private Unsafe onAlloc(Dict? opts)
  {
    if (!running.val) throw Err("PyMgr is no longer running")

    ipc := PyIpc(this, opts)
    ref := Unsafe(ipc)
    processes.add(ipc.pid, ref)
    return ref
  }

  private Obj? onDealloc(Str id)
  {
    ref := processes.remove(id) as Unsafe
    if (ref == null) return null
    ((PyIpc)ref.val).killProcess
    return id
  }

  private Obj? onKill()
  {
    running.val = false
    processes.each |Unsafe ref, Str pid|
    {
      log.info("Killing python process: $pid")
      onDealloc(pid)
      // ((PyIpc)ref.val).close
    }
    return null
  }
}