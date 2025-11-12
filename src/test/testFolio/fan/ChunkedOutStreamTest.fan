//
// Copyright (c) 2025, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   12 Nov 2025  Matthew Giannini  Creation
//

using concurrent
using xeto
using haystack
using folio

class ChunkedOutStreamTest : Test
{
  Void testBytes()
  {
    buf := Buf()
    chunked := ChunkedOutStream(buf.out)
    bytes := 1024 * 1024 * 8
    bytes.times |x| { chunked.write('a') }
    chunked.close
    verifyEq(bytes, chunked.bytesWritten)
    verifyEq(bytes, buf.size)
  }

  Void testBufs()
  {
    buf := Buf()
    chunked := ChunkedOutStream(buf.out)
    mb1 := Buf().fill('a', 1024 * 1024)
    n := 8
    n.times |x| { chunked.writeBuf(mb1.seek(0)) }
    chunked.close
    verifyEq(n * mb1.size, chunked.bytesWritten)
    verifyEq(n * mb1.size, buf.size)
  }
}