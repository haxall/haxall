//
// Copyright (c) 2010, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   21 Dec 2010  Brian Frank  Creation
//    3 Jan 2016  Brian Frank  Refactor for 3.0
//

using concurrent

**
** PasswordStore manages plaintext/hashed passwords and other secrets.
** It is stored via an obscured props file to prevent casual reading,
** but is not encrypted.  The passwords file must be kept secret and
** reads must be sequestered from all network access.  We separate secrets
** from the main database so that it may be more easily secured.
**
const class PasswordStore
{

//////////////////////////////////////////////////////////////////////////
// Construction
//////////////////////////////////////////////////////////////////////////

  ** Open for the given file
  @NoDoc static PasswordStore open(File file, FolioConfig config)
  {
    ps := make(file, config)
    ps.actor.send(msg(PasswordStoreMsgType.init)).get(timeout)
    return ps
  }

  private new make(File file, FolioConfig config)
  {
    this.file     = file
    this.idPrefix = config.idPrefix
    this.log      = config.log
    this.actor    = Actor(config.pool) |msg| { receive(msg); return null }
  }

//////////////////////////////////////////////////////////////////////////
// Access
//////////////////////////////////////////////////////////////////////////

  ** File used to store passwords passed to `open` method.
  @NoDoc const File file

  ** Logging
  @NoDoc const Log log

  ** Ref prefix
  @NoDoc const Str? idPrefix

  ** Get a password by its key or return null if not found.
  Str? get(Str key)
  {
    // first check for key
    val := cache[key]

    // if not found, check relativized key
    if (val == null)
      val = cache[key = relKey(key)]

    // return decoded password if found
    if (val == null) return null
    return decode(val)
  }

  ** Set a password by its key.
  Void set(Str key, Str val)
  {
    // always relativize new passwords
    key = relKey(key)
    actor.send(msg(PasswordStoreMsgType.set, key, encode(val))).get(timeout)
  }

  ** Remove a password by its key.
  Void remove(Str key)
  {
    // first check for unrelativized key
    val := cache[key]

    // check by relativized key
    if (val == null)
      val = cache[key = relKey(key)]

    // remove the password associated with this key if found
    if (val != null)
      actor.send(msg(PasswordStoreMsgType.remove, key)).get(timeout)
  }

  ** Relativize a key by stripping the leading idPrefix (if configured)
  private Str relKey(Str key)
  {
    if (idPrefix != null && key.startsWith(idPrefix))
      return key[idPrefix.size..-1]
    return key
  }

  ** Read the password props file into an in-memory buffer
  @NoDoc Buf readBuf()
  {
    buf := Buf()
    buf.out.writeProps(cache)
    return buf.toImmutable
  }

  ** Overwrite the contents of the password database on disk with given buf
  @NoDoc Void writeBuf(Buf buf)
  {
    actor.send(msg(PasswordStoreMsgType.writeBuf, buf.toImmutable)).get(timeout)
  }

//////////////////////////////////////////////////////////////////////////
// Messaging
//////////////////////////////////////////////////////////////////////////

  private Obj? receive(PasswordStoreMsg msg)
  {
    switch (msg.type)
    {
      case PasswordStoreMsgType.init:     return onInit
      case PasswordStoreMsgType.sync:     return onSync
      case PasswordStoreMsgType.set:      return onSet(msg.a, msg.b)
      case PasswordStoreMsgType.remove:   return onSet(msg.a, null)
      case PasswordStoreMsgType.writeBuf: return onWriteBuf(msg.a)
      default: throw Err(msg.type.toStr)
    }
  }

  private Obj? onSync()
  {
    return "sync"
  }

  private Obj? onInit()
  {
    try
      if (file.exists) cacheRef.val = file.readProps.toImmutable
    catch (Err e)
      log.err("Failed to load $file", e)
    return "init"
  }

  private Obj? onSet(Str key, Obj? val)
  {
    newCache := cache.dup
    if (val != null)
      newCache[key] = val
    else
      newCache.remove(key)
    return update(newCache)
  }

  private Obj? onWriteBuf(Buf buf)
  {
    update(buf.in.readProps)
  }

  private Obj? update(Str:Str newCache)
  {
    // update cache
    cacheRef.val = newCache.toImmutable

    // rewrite file
    out := file.out
    try
      file.writeProps(newCache)
    catch (Err e)
      log.err("Failed to save $file", e)
    finally
      out.close

    return "updated"
  }

  internal static PasswordStoreMsg msg(PasswordStoreMsgType type, Obj? a := null, Obj? b := null)
  {
    PasswordStoreMsg(type, a, b)
  }

//////////////////////////////////////////////////////////////////////////
// Utils
//////////////////////////////////////////////////////////////////////////

  ** Encode a password into an obsured format that provides
  ** marginal protection over plaintext.
  @NoDoc static Str encode(Str password)
  {
    // pad short passwords
    if (password.size < 10)
      password += "\u0000" + Str.spaces(10-password.size)
    buf := Buf()
    rs := rands.size
    x := Int.random(0..<rs)
    y := Int.random(0..<rs)
    z := Int.random(0..<rs)
    buf.write(0x6C)  // ver/magic
    buf.write(x)     // index into rands
    buf.write(y)     // index into rands
    buf.write(z)     // index into rands
    password.each |ch, i|
    {
      if (ch > 0x3fff) throw IOErr("Unsupported unicode chars")
      mask := rands[(x+i)%rs]
         .xor(rands[(y+i)%rs])
         .xor(rands[(z+i)%rs])
      buf.writeI2(ch.shiftl(2).xor(mask).and(0xffff))
    }
    return buf.toBase64
  }

  ** Given an encoded password, decode into the actual password.
  @NoDoc static Str decode(Str password)
  {
    buf := Buf.fromBase64(password)
    if (buf.readU1 != 0x6C) throw IOErr("bad password")
    rs := rands.size
    x := buf.readU1  // index into rands
    y := buf.readU1  // index into rands
    z := buf.readU1  // index into rands
    s := StrBuf()
    while (buf.more)
    {
      i := s.size
      mask := rands[(x+i)%rs]
         .xor(rands[(y+i)%rs])
         .xor(rands[(z+i)%rs])
      ch := buf.readU2.xor(mask).shiftr(2).and(0x3fff)
      if (ch == 0) break
      s.addChar(ch)
    }
    return s.toStr
  }

  private static const Int[] rands :=
  [
    0x8b173c97d70961c1,
    0xcf8e5bfa60994287,
    0xcbdd1d43df008afe,
    0x961097d99af14ac0,
    0x06a5f6771246a91d,
    0x2ee1ba8375b4d34b,
    0x060e3e6cb0f9b632,
    0x20a6b6643e5e3f8a,
    0x0428f439342e73c3,
    0x54a6ec0f585f7042,
    0xe827f4494c90a635,
    0x3abedd06bb8f7d0a,
    0xc79f221912d25608,
    0x2c62534b3bea2d44,
    0xd632b4ffdaeca67c,
    0x68ad1e314553f07d,
    0xe5e1c7fdbc3e4193,
    0x232840bc25563c2b,
    0x127e2cf874dee710,
    0x7fe9487be804a253
  ]

//////////////////////////////////////////////////////////////////////////
// Private Fields
//////////////////////////////////////////////////////////////////////////

  private static const Duration timeout := 15sec
  private Str:Str cache() { cacheRef.val }
  private const AtomicRef cacheRef := AtomicRef(Str:Str[:].toImmutable)
  private const Actor actor
}

**************************************************************************
** PasswordStoreMsg
**************************************************************************

internal enum class PasswordStoreMsgType
{
  init, sync, set, remove, writeBuf
}

internal const class PasswordStoreMsg
{
  new make(PasswordStoreMsgType type, Obj? a, Obj? b) { this.type = type; this.a = a; this.b = b }
  const PasswordStoreMsgType type
  const Obj? a
  const Obj? b
}

