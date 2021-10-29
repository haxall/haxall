//
// Copyright (c) 2021, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   16 Jul 2021  Matthew Giannini  Creation
//

using concurrent
using inet
using haystack

**
** PyProcess handles inter-process communication with Python
**
internal class PyProcess
{

//////////////////////////////////////////////////////////////////////////
// Constructor
//////////////////////////////////////////////////////////////////////////

  static new open(PyOpts opts)
  {
    PyProcess.make(opts).launch
  }

  private new make(PyOpts opts)
  {
    this.opts = opts
    this.socketConfig = SocketConfig.cur.copy { it.reuseAddr = true }
  }

  private static const ActorPool ipcPool := ActorPool() { it.name = "IpcPool" }

  ** Options
  protected PyOpts opts

  ** The Python process
  private Process? process

  ** The IPC socket for communicating with the process
  private TcpSocket? socket

  ** Is the process running
  private Bool running := false

  ** Socket configuration
  private const SocketConfig socketConfig


//////////////////////////////////////////////////////////////////////////
// Connect
//////////////////////////////////////////////////////////////////////////

  private This launch()
  {
    listener := TcpListener(socketConfig)
    try
    {
      // launch mini-server to accept connection from python process
      // listener.options.receiveTimeout = 20sec
      listener.bind(IpAddr("127.0.0.1"), opts.port)

      f := Actor(ActorPool() { it.name = "PyIpc-${listener.localPort}" }) |msg->Obj?| {
        l := ((Unsafe)msg).val as TcpListener
        s := l.accept
        return Unsafe(s)
      }.send(Unsafe(listener))

      // if port was passed, assume the process will be launched externally (for debug)
      if (opts.port == null)
        launchPythonProcess(listener.localPort)

      // wait for connection from python process
      this.socket = f.get(10sec)->val

      // the python process must send the api key as the very first thing
      challenge := socket.in.readLine
      if (challenge != opts.key) throw IOErr("Invalid api key received from python")

      return this
    }
    catch (Err e)
    {
      this.close
      throw e
    }
    finally
    {
      listener.close
    }
  }

  private Void launchPythonProcess(Int port)
  {
    cmd := Str["python", "-m", "hxpy",
               "--port", "${port}",
               "--key", opts.key,
               "--level", opts.logLevel,]
    if (Env.cur.os.startsWith("win"))
    {
      // freaking windows
      cmd[0] = opts.pythonhome.plus(`python.exe`).normalize.osPath
    }
    // NOTE: do NOT use this code below - killing the process will only
    // terminate the cmd shell, but not the child python process!!!
    // if (Env.cur.os.startsWith("win")) cmd = ["cmd", "/K"].addAll(cmd)

    // TODO:FIXIT temp hack assumes we are in /venv/Scripts/
    // maybe walk up until we find hxpyd/ package?
    // better yet we would just install it as a module in the venv
    this.process = Process(cmd, opts.pythonhome.plus(`../../`))
    // process.command = cmd
    // process.dir = opts.pythonhome.plus(`../../`)
    // process.out = null

    // update the process PATH environment variable
    path := process.env["PATH"]
    process.env["PATH"] = "${opts.pythonhome.normalize.osPath}"

    // kickoff the process
    process.run
  }

//////////////////////////////////////////////////////////////////////////
// Send
//////////////////////////////////////////////////////////////////////////

  Obj? send(Instr[] instrs)
  {
    try
    {
      return IpcActor(this.socket, ipcPool).send(instrs).get(opts.timeout)
    }
    catch (TimeoutErr err)
    {
      this.close
      throw err
    }
  }

//////////////////////////////////////////////////////////////////////////
// Close
//////////////////////////////////////////////////////////////////////////

  Bool isClosed() { socket == null || socket.isClosed }

  Void close()
  {
    socket?.close
    socket = null

    process?.kill?.join
    process = null
  }
}

**************************************************************************
** IpcActor
**************************************************************************

internal const class IpcActor : Actor
{
  new make(TcpSocket socket, ActorPool pool) :  super(pool)
  {
    this.socketRef = Unsafe(socket)
  }

  private static const Int maxPacketSize := 2.pow(31) - 1

  private TcpSocket socket() { socketRef.val }
  private const Unsafe socketRef

  override protected Obj? receive(Obj? obj)
  {
    sendInstrs(obj)
  }

//////////////////////////////////////////////////////////////////////////
// I/O
//////////////////////////////////////////////////////////////////////////

  private Obj? sendInstrs(Instr[] instrs)
  {
    buf  := Buf()
    brio := BrioWriter(buf.out) { it.maxStrCode = -1 }
    brio.writeVal(instrs.map |instr->Dict| { instr.encode })
    brio.close
    return sendBuf(buf.flip).recvVal
  }

  private This sendBuf(Buf buf)
  {
    if (buf.size > maxPacketSize) throw ArgErr("Packet too big: ${buf.size}")
    socket.out.writeI4(buf.size).writeBuf(buf).flush
    return this
  }

  Obj? recvVal()
  {
    BrioReader(socket.in).readVal
  }
}