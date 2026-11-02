//
// Copyright (c) 2026, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   15 Oct 2026  Lincoln Harmer  Creation
//

using xeto
using xetom
using haystack
using [java] java.lang::System
using [java] java.io::ByteArrayOutputStream
using [java] java.io::PrintStream

**
** CompNullLinkLogTest checks the log lines for a skipped or failed link
** push.  It redirects System.out, so it uses Java FFI and is not @Js.
**
class CompNullLinkLogTest : CompNullLinkBase
{
  ** A failing link logs once when it starts failing and once when it recovers
  Void testLog()
  {
    link := "Link @${d.id}.methodEcho -> @${e.id}.b"
    verifyEq(capture { 3.times { exec { d.call("methodEcho", null) } } },
      ["WARN: $link: null not pushed, target slot is not maybe (repeats not logged until it recovers)"])
    verifyEq(capture { 2.times { exec { d.call("methodEcho", "x") } } },
      ["$link: push recovered (repeats not logged: 2)"])

    lines := capture { exec { d.set("c", "x") }; exec { d.set("c", "y") } }
    verifyEq(lines.size, 1, lines.toStr)
    verify(lines.first.startsWith("ERR: Link @${d.id}.c -> @${e.id}.methodBad1: push failed: "), lines.first)
  }

  ** Console lines naming a link written while running f
  Str[] capture(|Obj?| f)
  {
    old := System.out
    buf := ByteArrayOutputStream()
    System.setOut(PrintStream(buf, true))
    try
      f(null)
    finally
      System.setOut(old)
    return buf.toString.splitLines.findAll |s| { s.contains("Link @") }
  }
}
