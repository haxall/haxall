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
** PythonSession
**************************************************************************

**
** Mixin for types that implement a python session.
**
mixin PySession
{
  ** Define a variable in local scope, and return this
  abstract This define(Str name, Obj? val)

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

  new open(Uri serverUri, |This|? f := null)
  {
    f?.call(this)
    this.serverUri = serverUri

    if ("tcp" != serverUri.scheme) throw ArgErr("Invalid scheme: $serverUri")
    if (serverUri.query["key"] == null) throw ArgErr("Missing key: $serverUri")

    if (evalPool == null)
    {
      evalPool = ActorPool() { it.name = "DefHxpySessionEvalPool" }
    }

    openSession
  }

  private Void openSession()
  {
    // this.socketRef = Unsafe(TcpSocket.make(socketConfig))
    this.socket = TcpSocket.make(socketConfig)
    socket.connect(IpAddr(serverUri.host), serverUri.port ?: 8888)

    // authenticate with key
    key  := serverUri.query["key"]
    auth := Etc.makeDict(["key": key, "ver": "0"])
    resp := (Dict)sendBrio(auth)
    if (resp.has("err")) throw IOErr("Auth failed: ${resp->errMsg}")
  }

  ** The python service uri
  const Uri serverUri

  ** Socket config
  const SocketConfig socketConfig := SocketConfig.cur

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

  ** Is the session closed
  private const AtomicBool closed := AtomicBool(false)

//////////////////////////////////////////////////////////////////////////
// PySession
//////////////////////////////////////////////////////////////////////////

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
    // transition to closed
    this.closed.val = true

    // close the socket
    socket?.close
    socket = null

    return this
  }

  private Void checkClosed()
  {
    if (closed.val) throw IOErr("Session is closed")
  }

//////////////////////////////////////////////////////////////////////////
// Util
//////////////////////////////////////////////////////////////////////////

  internal Obj? sendBrio(Obj obj)
  {
    buf := Buf()
    brio := BrioWriter(buf.out) { it.maxStrCode = -1 }
    brio.writeVal(obj).close
    return sendFrame(buf.flip).recvVal
  }

  private This sendFrame(Buf buf)
  {
    if (buf.size > maxPacketSize) throw ArgErr("Packet too big: ${buf.size}")
    socket.out.writeI4(buf.size).writeBuf(buf).flush
    return this
  }

  private Obj? recvVal()
  {
    BrioReader(socket.in).readVal
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