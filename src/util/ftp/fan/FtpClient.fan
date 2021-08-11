//
// Copyright (c) 2010, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   15 Jan 2010  Brian Frank  Creation
//

using inet

**
** FtpClient is used to retrieve files from an FTP server
**
class FtpClient
{
  ** Construct with credentials
  new make(Str username := "anonymous", Str password := "")
  {
    this.username = username
    this.password = password
  }

  ** Read file from remote server, return input stream to passive socket
  InStream read(Uri uri)
  {
    path := toFilePath(uri)
    open(uri, "RETR $path")
    return FtpInStream(pasvSocket.in) |->|
    {
      this.close
    }
  }

  ** Write a file to the remote server, return output stream to passive socket
  OutStream write(Uri uri)
  {
    path := toFilePath(uri)
    open(uri, "STOR $path")
    return FtpOutStream(pasvSocket.out) |->|
    {
      try
      {
        res := readRes
        if (res.code != 226) throw FtpErr(res.code, "Write failed: $res")
      }
      finally close
    }
  }

  ** List file names in given directory and return absolute uris
  Uri[] list(Uri uri)
  {
    try
    {
      path := toDirPath(uri)
      open(uri, "NLST $path")
      acc := Uri[,]
      pasvSocket.in.readAllLines.each |n|
      {
        slash := n.indexr("/", -2)
        if (slash != null) n = n[slash+1..-1]
        acc.add(uri.plusName(n))
      }
      return acc
    }
    finally close
  }

  ** Create a directory and return the URI of the directory as reported by the server.
  ** Will create all intermediate directories. If checked is false, no errors are
  ** reported.
  Uri mkdir(Uri uri, Bool checked := false)
  {
      path    := toDirPath(uri)
      created := path.toUri

      // create full path
      todo := Uri[,]
      uri.path.size.times |i| { todo.add(uri[0..i]) }
      todo.each |pathUri, i|
      {
        try
        {
          ignore := Int[550]
          if (i+1 == todo.size && checked) ignore.clear

          path = toDirPath(pathUri)
          res := open(pathUri, "MKD $path", ignore)
          m   := Regex.fromStr(Str<|"(.*).*"|>).matcher(res.text)
          created = m.matches ? m.group(1).toUri : path.toUri
        }
        finally close
      }
      return created
  }

  ** Remove the file at the given uri
  Uri delete(Uri uri)
  {
    try
    {
      path := toFilePath(uri)
      res  := open(uri, "DELE $path")
      return path.toUri
    }
    finally close
  }

  ** Remove the directory at the given uri.
  Uri rmdir(Uri uri)
  {
    try
    {
      path := toDirPath(uri)
      // res  := open(uri, "RMD $path", [550])
      res  := open(uri, "RMD $path", [550])
      return path.toUri
    }
    finally close
  }

  **
  ** Execute a FTP command:
  **  1. connect to command socket
  **  2. authenticate
  **  3. common setup
  **  4. run command
  **  5. open passive socket
  **  6. run command
  **
  ** NOTE: it is caller (or client) responsibility to close the sockets!!!
  **
  private FtpRes open(Uri uri, Str cmd, Int[] allowableErrs := Int#.emptyList)
  {
    if (uri.scheme != "ftp" && uri.scheme != "ftps") throw ArgErr("Uri not ftp: $uri")
    useTls := uri.scheme == "ftps"

    // connect
    cmdSocket = connect(IpAddr(uri.host), uri.port ?: 21)
    res := readRes
    if (res.code != 220 && res.code != 530) throw FtpErr(res.code, "Cannot connect: $res")

    // upgrade to TLS
    if (useTls)
    {
      writeReq("AUTH TLS")
      res = readRes
      if (res.code != 234) throw FtpErr(res.code, "Cannot set auth mechanism to TLS: $res")
      cmdSocket = TcpSocket.makeTls(cmdSocket)

      writeReq("PBSZ 0")
      res = readRes
      if (res.code != 200) throw FtpErr(res.code, "Cannot set protection buffer size: $res")
      writeReq("PROT P")
      res = readRes
      if (res.code != 200) throw FtpErr(res.code, "Cannot set data channel protection level: $res")
    }

    // login
    writeReq("USER $username")
    res = readRes
    if (res.code != 331) throw FtpErr(res.code, "Cannot login: $res")
    writeReq("PASS $password")
    res = readRes
    if (res.code != 230) throw FtpErr(res.code, "Cannot login: $res")

    // set to binary mode
    writeReq("TYPE I")
    res = readRes
    if (res.code != 200) throw FtpErr(res.code, "Cannot set to binary mode: $res")

    // enter PASV mode
    writeReq("PASV")
    res = readRes
    pasvSocket = openPassive(res)

    // run command
    writeReq(cmd)
    res = readRes
    switch (res.code)
    {
      case 125:
        // Data connection already open; transfer starting
        _ := res.code
      case 150:
        // File status okay; about to open data connection
        _ := res.code
      case 250:
        // Requested file action okay, completed.
        return res
      case 257:
        // "PATHNAME" created
        _ := res.code
      default:
        // if (!allowableErrs.contains(res.code)) throw FtpErr(res.code, "Cannot run $cmd: $res")
        throw FtpErr(res.code, "Cannot run $cmd: $res")
    }

    // upgrade data channel to TLS
    if (useTls) pasvSocket = openSecureDataChannel(cmdSocket, pasvSocket)

    // return the response of the command
    return res
  }

  private native TcpSocket openSecureDataChannel(TcpSocket cmd, TcpSocket data)

  ** Close command and passive sockets
  private Void close()
  {
    try { cmdSocket?.close } catch {}
    try { pasvSocket?.close } catch {}
  }

  ** Given response to PASV, open passive data socket
  private TcpSocket openPassive(FtpRes res)
  {
    if (res.code != 227) throw FtpErr(res.code, "Cannot enter passive mode: $res")
    text := res.text
    IpAddr? host
    Int? port
    try
    {
      toks := text[text.index("(")+1..<text.index(")")].split(',')
      host = IpAddr("${toks[0]}.${toks[1]}.${toks[2]}.${toks[3]}")
      port = toks[4].toInt*256 + toks[5].toInt
      return connect(host, port)
    }
    catch (Err e) throw FtpErr(227, "Cannot parse PASV res [host=$host port=$port]: $text.toCode", e)
  }

  ** Open a socket
  private TcpSocket connect(IpAddr host, Int port)
  {
    socket := TcpSocket()
    socket.options.receiveTimeout = 1min
    return socket.connect(host, port)
  }

  ** Read server response
  private FtpRes readRes()
  {
    line := cmdSocket.in.readLine
    if (log.isDebug) log.debug("s: $line")
    try
    {
      code := line[0..2].toInt
      text := line[4..-1].trim
      if (line[3] == '-')
      {
        prefix := line[0..2] + " "
        while (true)
        {
          line = cmdSocket.in.readLine
          if (log.isDebug) log.debug("s: $line")
          if (line == null) throw Err("Unexpected end of stream, expecting $prefix.toCode")
          text += "\n" + line
          if (line.startsWith(prefix)) break
        }
        text += "\n" + line[4..-1].trim
      }
      return FtpRes(code, text)
    }
    catch (Err e) throw IOErr("Invalid FTP reply '$line'")
  }

  ** Write server request
  private Void writeReq(Str line)
  {
    if (log.isDebug) log.debug("c: $line")
    cmdSocket.out.print(line).print("\r\n").flush
  }

  ** Get path to file to use for FTP request
  private Str toFilePath(Uri uri)
  {
    if (uri.isDir) throw ArgErr("Uri is dir: $uri")
    pathStr := uri.pathStr
    if (pathStr.isEmpty) throw ArgErr("Uri has no path: $uri")
    return pathStr
  }

  ** Get path to directory to use for FTP request
  private Str toDirPath(Uri uri)
  {
    if (!uri.isDir) throw ArgErr("Uri is not dir: $uri")
    pathStr := uri.pathStr
    if (pathStr.isEmpty) throw ArgErr("Uri has no path: $uri")
    return pathStr
  }

//////////////////////////////////////////////////////////////////////////
// Fields
//////////////////////////////////////////////////////////////////////////

  ** Log for tracing
  Log log := Log.get("ftp")

  private const Str username
  private const Str password

  private TcpSocket? cmdSocket
  private TcpSocket? pasvSocket
}

**************************************************************************
** FtpRes
**************************************************************************

internal class FtpRes
{
  new make(Int c, Str t) { code = c; text = t }
  override Str toStr() { return "$code $text" }
  const Int code
  const Str text
}

**************************************************************************
** FtpInStream
**************************************************************************

internal class FtpInStream : InStream
{
  new make(InStream in, |->| onClose) : super(in) { this.onClose = onClose }
  override Bool close()
  {
    if (closed) return true
    closed = true
    r := super.close
    onClose(); return r
  }
  private Bool closed
  private |->| onClose
}

**************************************************************************
** FtpOutStream
**************************************************************************

internal class FtpOutStream : OutStream
{
  new make(OutStream out, |->| onClose) : super(out) { this.onClose = onClose }
  override Bool close()
  {
    if (closed) return true
    closed = true
    r := super.close
    onClose(); return r
  }
  private Bool closed
  private |->| onClose
}

