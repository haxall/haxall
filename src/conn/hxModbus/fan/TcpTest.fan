//
// Copyright (c) 2012, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   25 Sep 2019  Andy Frank  Creation
//

using inet

@NoDoc class TcpTest
{
  Void main()
  {
    args := Env.cur.args
    if (args.size < 3) { usage; return 1 }

    // parse ip[:port] arguments
    Str? iparg := args[0]
    Int? port  := 502
    if (iparg.contains(":"))
    {
      port = iparg[iparg.index(":")+1..-1].toInt(10, false)
      if (port == null) fatal("Invalid port ${iparg}")
      iparg = iparg[0..<iparg.index(":")]
    }

    // parse ip and set default vals
    ip    := IpAddr(iparg)
    unit  := 1
    func  := 3
    start := 0
    len   := 1

    // check for unit option
    i := 1
    x := args.getSafe(1)
    if (x == "--unit")
    {
      v := Int.fromStr(args.getSafe(2), 10, false)
      if (v == null) fatal("invalid unit id: ${v}")
      unit = v
      i += 2
    }

    // func
    f := Int.fromStr(args.getSafe(i++) ?: "", 10, false)
    if (f == null) fatal("invalid func code: ${f}")
    func = f

    // start
    s := Int.fromStr(args.getSafe(i++) ?: "", 10, false)
    if (s == null) fatal("invalid start address: ${s}")
    start = s

    // length
    Obj? l := args.getSafe(i)
    if (l != null)
    {
      l = Int.fromStr(l, 10, false)
      if (l == null) fatal("invalid length: ${l}")
      len = l
    }

    echo("> req [${ip}:${port} unit=${unit}] func=${func} @ ${start} [${len}]")

    // go baby
    tx     := ModbusTcpTransport(ip, port, 10sec) {} // it.debug=true }
    master := ModbusMaster(tx)
    try
    {
      master.open
      Obj? res
      switch (func)
      {
        case 3:  res = master.readHoldingRegs(unit, start, len)
        default: fatal("Unsupported func ${func}")
      }
      echo("< $res")
    }
    finally { master.close }
  }

  Void fatal(Str msg)
  {
    Env.cur.err.printLine("ERR: $msg")
    Env.cur.exit(1)
  }

  Void usage()
  {
    echo("Modbus TcpTest utility
          usage:
            fan modbusExt::TcpTest <ip>[:<port>] [--unit <id>] <func> <start> [len]

            ip      ip address of slave device
            port    port numbrer of slave device (default=502)
            func    function code to request
            start   raw start address to request (ex: 1, not 40001)
            len     number of registers to read (default=1)

            --unit  unit id of slave device (default to 1)
            ")
  }
}