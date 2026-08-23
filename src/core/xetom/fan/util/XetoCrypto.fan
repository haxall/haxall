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
** XetoCrypto is the choke point for xeto's cryptographic operations:
** today the content digests used to verify xetolib integrity, and where
** signing would live.  It is kept separate from `XetoUtil` because crypto
** pulls a JS dependency which XetoUtil must not carry.
**
const class XetoCrypto
{

//////////////////////////////////////////////////////////////////////////
// Encoding
//////////////////////////////////////////////////////////////////////////

  ** Choke point to format the hash of a completed digest computation;
  ** see `digest` and `digestStream`
  static Str encode(Digest d) { d.digest.toBase64Uri }

  ** Choke point to format the hash of a completed digest computation;
  ** see `digest` and `digestStream`
  static Str encodePrefix(Digest d) { "sha256:" + encode(d) }

//////////////////////////////////////////////////////////////////////////
// File Digests
//////////////////////////////////////////////////////////////////////////

  ** Choke point to format digest of xetolib zip contents as "sha256:"
  ** followed by the base64uri encoding of the SHA-256 hash
  static Str digest(Buf contents)
  {
    encodePrefix(Crypto.cur.digest("SHA-256").update(contents))
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
    return encodePrefix(d)
  }

//////////////////////////////////////////////////////////////////////////
// Pods Cache Key
//////////////////////////////////////////////////////////////////////////

  ** Cache key for a set of pods to parallel the libsCacheKey
  static Str podsCacheKey(Pod[] pods)
  {
    d := Crypto.cur.digest("SHA-256")
    pods.dup.sort.each |x|
    {
      d.updateAscii(x.name)
      d.updateAscii(x.version.toStr)
      d.updateAscii(podToBuildTime(x))
    }
    return encode(d)
  }

  private static Str podToBuildTime(Pod pod)
  {
    pod.meta["build.tsKey"] ?: (pod.meta["build.ts"] ?: "")
  }

//////////////////////////////////////////////////////////////////////////
// Lib Cache Key
//////////////////////////////////////////////////////////////////////////

  ** Cache key for a set of libs.  Sorts a copy: the caller's list is in
  ** dependency order, which a reader relies on to resolve each lib's
  ** depends before it loads.
  static Str libsCacheKey(Lib[] libs)
  {
    d := Crypto.cur.digest("SHA-256")
    libs.dup.sort.each |x| { d.updateAscii(x.cacheKey) }
    return encode(d)
  }

  static Str libCacheKey(MLib lib)
  {
    d := Crypto.cur.digest("SHA-256")
    d.updateAscii(lib.name)
    d.updateAscii(lib.version.toStr)
    buf := Buf()
    if (lib.files.isSupported) lib.files.list.each |f|
    {
      buf.clear.print(f.uri.toStr)
      d.update(buf).updateI8(f.size ?: 0).updateI8(cacheKeyTicks(f.modified))
    }
    return encode(d)
  }

  ** Timestamp rounded to the two second resolution of the zip format.
  private static Int cacheKeyTicks(DateTime? ts)
  {
    ts == null ? 0 : ts.ticks / 2sec.ticks
  }

//////////////////////////////////////////////////////////////////////////
// Inheritance Digest
//////////////////////////////////////////////////////////////////////////

  static Int computeInheritanceDigest(Spec t)
  {
    d := Crypto.cur.digest("SHA-1")
    updateInheritanceDigest(d, t)
    return d.digest.readS8
  }

  private static Void updateInheritanceDigest(Digest d, Spec t)
  {
    d.updateAscii(t.qname)
    if (t.base == null) return
    updateInheritanceDigest(d, t.base)
    if (t.isCompound)
    {
      t.ofs.each |of| { updateInheritanceDigest(d, of) }
    }
  }

}

