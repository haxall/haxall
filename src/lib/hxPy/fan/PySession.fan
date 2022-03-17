//
// Copyright (c) 2021, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   15 Oct 2021  Matthew Giannini  Creation
//

using concurrent
using inet
using haystack

**************************************************************************
** PySession
**************************************************************************

**
** Mixin for types that implement a python session.
**
mixin PySession
{
  ** Define a variable in local scope, and return this
  abstract This define(Str name, Obj? val)

  ** If the session has not been initialized yet, invoke the callback
  ** with this session to allow it to do one-time setup.
  abstract This init(|PySession session| fn)

  ** Execute the given code block, and return this
  abstract This exec(Str code)

  ** Set the timeout for evaluating python expressions and return this
  abstract This timeout(Duration? dur)

  ** Evaluate the expression and return the result.
  abstract Obj? eval(Str expr)

  ** Close the session, and return this
  virtual This close() { return this }
}

**************************************************************************
** HxpySession
**************************************************************************

**
** HxpySession opens a connection to a python process running 'hxpy'.
**
@NoDoc class HxpySession : PySession
{

//////////////////////////////////////////////////////////////////////////
// Constructor
//////////////////////////////////////////////////////////////////////////

  ** Make an unconnected session. Must call `connect()` before invoking
  ** any `eval()` calls.
  new make(|This|? f := null) : this.make_priv(null, f) { }

  ** Connect the session running on the given server uri.
  new open(Uri serverUri, |This|? f := null) : this.make_priv(serverUri, f) { }

  private new make_priv(Uri? serverUri, |This|? f:= null)
  {
    f?.call(this)

    if (evalPool == null)
    {
      evalPool = ActorPool() { it.name = "DefHxpySessionEvalPool" }
    }

    if (serverUri != null) connect(serverUri)
  }

  ** Connect to the hxpy server running at the given uri.
  This connect(Uri serverUri)
  {
    if (isConnected) throw IOErr("Already connected to ${this.serverUri}")

    if ("tcp" != serverUri.scheme) throw ArgErr("Invalid scheme: $serverUri")
    if (serverUri.query["key"] == null) throw ArgErr("Missing key: $serverUri")
    this.serverUri = serverUri

    try
    {
      // connect
      this.socket = TcpSocket.make(socketConfig)
      socket.connect(IpAddr(serverUri.host), serverUri.port ?: 8888)

      // authenticate with key
      key  := serverUri.query["key"]
      auth := Etc.makeDict(["key": key, "ver": "0"])
      resp := (Dict)sendBrio(auth)
      if (resp.has("err")) throw IOErr("Auth failed: ${resp->errMsg}")
    }
    catch (Err err)
    {
      this.close
      throw err
    }

    return this
  }

  ** The python service uri
  Uri? serverUri { private set }

  ** Socket config
  const SocketConfig socketConfig := SocketConfig.cur.copy { it.receiveTimeout = null }

  ** Session log
  const Log log := Log.get("py")

  ** Actor pool for evaluating expressions
  const ActorPool evalPool

  ** Instructions to run on the python service
  private Instr[] instrs := Instr[,]

  ** Socket to python server
  private TcpSocket? socket

  ** Eval timeout
  private Duration? evalTimeout := null

  ** Have we initialized
  Bool isInitialized := false

  ** Is the session connected
  Bool isConnected() { this.socket != null && !socket.isClosed }

//////////////////////////////////////////////////////////////////////////
// PySession
//////////////////////////////////////////////////////////////////////////

  override This init(|PySession| fn)
  {
    if (!isInitialized)
    {
      fn.call(this)
      this.isInitialized = true
    }
    return this
  }

  override This define(Str name, Obj? val)
  {
    // TODO: type checking on val?
    instrs.add(DefineInstr(name, val))
    return this
  }

  override This exec(Str code)
  {
    // Just buffer the exec instruction until an eval is requested
    instrs.add(ExecInstr(code))
    return this
  }

  override This timeout(Duration? dur)
  {
    this.evalTimeout = dur
    return this
  }

  override Obj? eval(Str expr)
  {
    checkClosed

    // finish instructions
    toEval := instrs.add(EvalInstr(expr))
    this.instrs = Instr[,]

    // evaluate
    return EvalActor(this, evalPool).send(toEval).get(this.evalTimeout)
  }

  override This close()
  {
    // close the socket
    socket?.close
    socket = null

    // reset to not initialized
    this.isInitialized = false

    return this
  }

  private Void checkClosed() { if (!isConnected) throw IOErr("${typeof.name} is closed") }

//////////////////////////////////////////////////////////////////////////
// Util
//////////////////////////////////////////////////////////////////////////

  internal Obj? sendBrio(Obj obj)
  {
    buf := Buf()
    brio := BrioWriter(buf.out) { it.maxStrCode = -1 }
    brio.writeVal(obj).close
    val := sendFrame(buf.flip).recvVal

    // check for err grid
    if (val is Grid)
    {
      g := (Grid)val
      if (g.meta.has("err")) throw IOErr("Python failed: ${g.meta->errMsg}\n${g.meta->errTrace}")
    }

    // decode ndarray
    if (val is Dict && ((Dict)val).has("ndarray")) val = NDArray.decode(val)

    return val
  }

  private This sendFrame(Buf buf)
  {
    if (buf.size > maxPacketSize) throw ArgErr("Packet too big: ${buf.size}")
    socket.out.writeI4(buf.size).writeBuf(buf).flush
    return this
  }

  private Obj? recvVal()
  {
    try
      return BrioReader(socket.in).readVal
    catch (IOErr err)
      throw IOErr("Unable to read from hxpy server. It is probably not running anymore", err)
  }

  private static const Int maxPacketSize := 2.pow(31) - 1

}

**************************************************************************
** EvalActor
**************************************************************************

internal const class EvalActor : Actor
{
  new make(HxpySession session, ActorPool pool) : super(pool)
  {
    this.sessionRef = Unsafe(session)
  }

  private HxpySession session() { sessionRef.val }
  private const Unsafe sessionRef

  protected override Obj? receive(Obj? obj)
  {
    instrs := (Instr[])obj
    return session.sendBrio(instrs.map |instr->Dict| { instr.encode })
  }
}