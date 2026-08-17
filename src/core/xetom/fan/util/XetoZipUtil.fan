//
// Copyright (c) 2026, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   3 Aug 2026  Brian Frank  Creation
//

using crypto
using xeto
using haystack

**
** XetoZipUtil is the choke point for building xetolib zip files; it is
** used by the compiler build pipeline, remote repo clients which
** assemble a zip from fetched source, and repo servers which zip a
** local source lib on the fly.
**
const class XetoZipUtil
{

  ** Choke point to format digest of xetolib zip contents as "sha256:"
  ** followed by the base64uri encoding of the SHA-256 hash
  static Str digest(Buf contents)
  {
    digestFrom(Crypto.cur.digest("SHA-256").update(contents))
  }

  ** Digest a stream incrementally without buffering its contents.  The
  ** stream is read to exhaustion, and if close is true it is guaranteed
  ** closed upon return - matching the semantics of `sys::InStream.pipe`.
  ** Use this instead of `digest` when the content may be large, such as
  ** an uploaded lib zip or one of its entries.
  static Str digestStream(InStream in, Bool close := true)
  {
    d := Crypto.cur.digest("SHA-256")
    chunkSize := 64*1024
    buf := Buf(chunkSize)
    try
      while (in.readBuf(buf.clear, chunkSize) != null) d.update(buf.flip)
    finally
      if (close) in.close
    return digestFrom(d)
  }

  ** Choke point to format the hash of a completed digest computation;
  ** see `digest` and `digestStream`
  static Str digestFrom(Digest d)
  {
    "sha256:" + d.digest.toBase64Uri
  }
}

