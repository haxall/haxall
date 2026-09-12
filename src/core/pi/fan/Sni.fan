//
// Copyright (c) 2026, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   23 May 2026  Brian Frank  Creation
//

using concurrent
using util
using xeto
using haystack

**
** Sni models a Subject Navigation Identifier formatted as:
**
**     /provider/tail?params#frag
**
@Js
const class Sni
{

//////////////////////////////////////////////////////////////////////////
// Construction
//////////////////////////////////////////////////////////////////////////

  ** Create "/db?sel=id1,id2,..." sni from multiple refs.
  ** If norm is true, relativize ids via UiSpace if available.
  ** More than 8 ids will spill to the `$a` key (e.g. "?sel=$a").
  static Sni fromIds(Ref[] ids, Bool norm := true)
  {
    if (ids.isEmpty) throw ArgErr("Empty ids")
    if (ids.size == 1) return fromId(ids.first, norm)
    if (norm) ids = ids.map |id->Ref| { normRef(id) }
    return fromStr("/db").setSel(ids)
  }

  ** Construct Sni from a Ref identity (reverse of id).
  ** If norm is true, relativize the ref via UiSpace if available.
  static Sni fromId(Ref id, Bool norm := true)
  {
    s := id.id
    if (s.startsWith("sni:"))
    {
      i := s.index(":", 4)
      provider := s[4..<i]
      tail := Ref.tildeDecode(s, i + 1)
      return fromStr("/$provider/$tail")
    }
    if (norm) s = normRef(id).id
    return fromStr("/db/${s}")
  }

  ** Coerce object to Sni instance
  @NoDoc static Sni? coerce(Obj? obj)
  {
    if (obj == null) return null
    if (obj is Sni) return obj
    return Sni.fromStr(obj.toStr)
  }

  ** Parse from string formatted as "/provider/tail?params#frag"
  static new fromStr(Str s, Bool checked := true)
  {
    try
    {
      return parse(s)
    }
    catch (Err e)
    {
      if (checked) throw ParseErr("Sni: $s")
      return null
    }
  }

  private static Sni parse(Str s)
  {
    len := s.size
    if (len == 0 || s[0] != '/') throw Err()

    // parse char by char thru sections:
    //   /provider/tail?params#frag
    provider := ""
    tail := Str[,]
    params := emptyParams
    Str? frag := null
    section := 0  // 0=provider, 1=tail, 2=paramKey, 3=paramVal, 4=frag
    seg := StrBuf()
    paramKey := ""
    for (i := 1; i < len; ++i)
    {
      ch := s[i]
      switch (section)
      {
        // provider
        case 0:
          if (ch == '/') { provider = seg.toStr; seg.clear; section = 1 }
          else if (ch == '?') { provider = seg.toStr; seg.clear; section = 2 }
          else if (ch == '#') { provider = seg.toStr; seg.clear; section = 4 }
          else seg.addChar(ch)

        // tail segments
        case 1:
          if (ch == '/') { str := seg.toStr; if (!str.isEmpty) tail.add(str); seg.clear }
          else if (ch == '?') { str := seg.toStr; if (!str.isEmpty) tail.add(str); seg.clear; section = 2 }
          else if (ch == '#') { str := seg.toStr; if (!str.isEmpty) tail.add(str); seg.clear; section = 4 }
          else seg.addChar(ch)

        // param key
        case 2:
          if (ch == '=') { paramKey = seg.toStr; seg.clear; section = 3 }
          else if (ch == '#') { seg.clear; section = 4 }
          else seg.addChar(ch)

        // param value
        case 3:
          if (ch == '&')
          {
            if (params.isEmpty) params = Str:Str[:] { ordered = true }
            params[paramKey] = seg.toStr; seg.clear; section = 2
          }
          else if (ch == '#')
          {
            if (params.isEmpty) params = Str:Str[:] { ordered = true }
            params[paramKey] = seg.toStr; seg.clear; section = 4
          }
          else seg.addChar(ch)

        // frag
        case 4:
          seg.addChar(ch)
      }
    }

    // flush last segment
    isDir := false
    switch (section)
    {
      case 0: provider = seg.toStr
      case 1:
        str := seg.toStr
        if (!str.isEmpty) tail.add(str)
        else isDir = true
      case 3:
        if (params.isEmpty) params = Str:Str[:] { ordered = true }
        params[paramKey] = seg.toStr
      case 4:
        str := seg.toStr
        if (!str.isEmpty) frag = str
    }

    return makeFields(s, provider, tail, params, isDir, frag)
  }

  private new makeFields(Str str, Str provider, Str[] tail, Str:Str params, Bool isDir, Str? frag, Dict spills := Etc.dict0)
  {
    this.str      = str
    this.provider = provider
    this.tail     = tail
    this.params   = params
    this.isDir    = isDir
    this.frag     = frag
    this.spills   = spills
  }

  ** Return copy with the given spills Dict attached.  Used by [decode].
  private Sni withSpills(Dict spills)
  {
    if (spills.isEmpty) return this
    return makeFields(str, provider, tail, params, isDir, frag, spills)
  }

  private Sni rebuild(Str[] tail, Str:Str params, Bool dir := this.isDir, Str? frag := this.frag)
  {
    s := StrBuf()
    s.addChar('/')
    if (!provider.isEmpty)
    {
      s.add(provider)
    }
    tail.each |seg| { s.addChar('/').add(seg) }
    if (dir) s.addChar('/')
    if (!params.isEmpty)
    {
      i := 0
      params.each |v, k|
      {
        s.addChar(i++ == 0 ? '?' : '&')
        s.add(k).addChar('=').add(v)
      }
    }
    if (frag != null) s.addChar('#').add(frag)
    return makeFields(s.toStr, provider, tail, params, dir, frag, spills)
  }

  private static Ref normRef(Ref id)
  {
    PiEnv.cur.normRef(id)
  }

  ** Empty params constant
  private static const Str:Str emptyParams := Str:Str[:]  { ordered = true }.toImmutable

  ** Sanity check for gluing together ids
  @NoDoc static const Int maxSize := 2000

  ** Max number of refs to inline in tail before spilling to the spills map
  @NoDoc static const Int maxInlineRefs := 8

  ** Create a temporary Sni with auto-incrementing counter
  @NoDoc static Sni makeTemp() { fromStr("/temp/" + tempCounter.getAndIncrement) }
  private static const AtomicInt tempCounter := AtomicInt()

  ** Home root "/"
  static const Sni home := fromStr("/")

  ** Default is same as [home]
  static Sni defVal() { home }

//////////////////////////////////////////////////////////////////////////
// Identity
//////////////////////////////////////////////////////////////////////////

  ** Full string representation.  This is the URL form which carries spill
  ** placeholders such as "$0" but not the spilled values themselves.  Use
  ** [encode]/`decode` to round-trip the full state including spills.
  override Str toStr() { str }
  private const Str str

  ** Spilled values keyed by spill key "a", "b", "c"...  These are the typed
  ** values (e.g. `Ref[]`) referenced by "$key" placeholders in the string
  ** (so "$a" maps to `spills->a`).  Keys are valid tag names.  Empty Dict if
  ** no values spilled.  See [encode].
  const Dict spills

  ** Equality based on string and spills.  Spill keys must match exactly.
  ** For string-only comparison use `a.toStr == b.toStr`.
  override Bool equals(Obj? that)
  {
    x := that as Sni
    if (x == null || str != x.str) return false
    return Etc.dictEq(spills, x.spills)
  }

  ** Hash code based on string
  override Int hash() { str.hash }

  ** Provider is the first path segment identifying the subject provider.
  ** Empty string only for root "/".
  **
  **     /db/ph::Equip/abc-123 => "db"
  **     /files/lib/doc.xeto/Specs.md => "file"
  const Str provider

  ** Tail as list of path segments after the provider.
  ** Returns empty list if no tail.
  **
  **     /db/ph::Equip/abc-123 => ["ph::Equip", "abc-123"]
  **     /files/lib/doc.xeto/Specs.md => ["lib", "doc.xeto", "Specs.md"]
  const Str[] tail

  ** Tail as the full string after the provider.
  ** Returns empty string if no tail.
  **
  **     /db/ph::Equip/abc-123 => "ph::Equip/abc-123"
  **     /files/lib/doc.xeto/Specs.md => "lib/doc.xeto/Specs.md"
  Str tailStr()
  {
    s := StrBuf()
    tail.each |seg, i| { if (i > 0) s.addChar('/'); s.add(seg) }
    if (isDir) s.addChar('/')
    return s.toStr
  }

  ** Is the path a directory (ends with trailing slash)
  @NoDoc const Bool isDir

  ** Is this a temporary Sni
  @NoDoc Bool isTemp() { provider == "temp" }

  ** Last named part in path of tail or provider
  **
  **     /files/lib/doc.xeto/Specs.md => "Specs.md"
  Str name()
  {
    if (!tail.isEmpty) return tail.last
    return provider
  }

  ** Query parameters parsed as key-value map.
  ** Returns empty map if no params.
  const Str:Str params

  ** Get a single param value by name, or null if not present.
  @Operator Str? get(Str name) { params[name] }

  ** Get the "view" parameter
  Str? view() { get("view") }

  ** Selection ids parsed from the "sel" param, or null if not present.
  ** A selection is a view of its base collection, never identity - see
  ** [id].  Returns null if the param was spilled and the spill values
  ** are not available (string-only reparse).  See [setSel].
  Ref[]? sel()
  {
    s := params["sel"]
    if (s == null) return null
    if (s.startsWith("\$")) return spills[s[1..-1]] as Ref[]
    acc := Ref[,]
    s.split(',').each |x| { acc.add(Ref(x)) }
    return acc
  }

  ** Fragment identifier for location within the subject.
  ** Null if no fragment.
  **
  **     /files/lib.xeto#L10 => "L10"
  **     /files/lib.xeto#L10,5-L20,3 => "L10,5-L20,3"
  const Str? frag

  ** Parse fragment as start location, or null if no fragment.
  ** Returns FileLoc with line and optional column.
  **
  **     #L10 => FileLoc("", 10)
  **     #L10,5 => FileLoc("", 10, 5)
  **     #L10,5-L20,3 => FileLoc("", 10, 5)
  FileLoc? loc()
  {
    if (frag == null) return null
    return parseLoc(frag, 0)
  }

  ** Parse fragment as end location for a range, or null if no range.
  ** Returns FileLoc with line and optional column.
  **
  **     #L10 => null
  **     #L10-L20 => FileLoc("", 20)
  **     #L10,5-L20,3 => FileLoc("", 20, 3)
  FileLoc? locEnd()
  {
    if (frag == null) return null
    dash := frag.index("-")
    if (dash == null) return null
    return parseLoc(frag, dash+1)
  }

  private static FileLoc? parseLoc(Str frag, Int off)
  {
    if (off >= frag.size || frag[off] != 'L') return null
    comma := frag.index(",", off)
    dash := frag.index("-", off+1)
    lineEnd := comma ?: (dash ?: frag.size)
    line := frag[off+1..<lineEnd].toInt(10, false)
    if (line == null) return null
    Int col := 0
    if (comma != null && (dash == null || comma < dash))
    {
      colEnd := dash ?: frag.size
      c := frag[comma+1..<colEnd].toInt(10, false)
      if (c == null) return null
      col = c
    }
    return FileLoc("", line, col)
  }

  ** Get Ref identity for this Sni.
  ** For /db/{id} where id is a valid bare Ref, returns Ref(id).
  ** For all others returns sni:{provider}:{tail-encoded}.
  ** Params and fragment are never part of identity.
  once Ref id()
  {
    if (provider == "db" && tail.size == 1 && Ref.isId(tail[0]))
      return Ref(tail[0])
    buf := StrBuf(str.size+16)
    buf.add("sni:").add(provider).addChar(':')
    tail.each |seg, i| { if (i > 0) buf.add("~2f"); Ref.tildeEncode(buf, seg) }
    return Ref(buf.toStr)
  }

  ** Convert to a URI
  Uri toUri() { str.toUri }

  ** To item
  Item toItem(Obj? text := null, Icon? icon := null, Dict? meta := null)
  {
    MItem(this, Text.fromData(text ?: this.name), icon, Etc.dictSet(meta, "sni", this))
  }

//////////////////////////////////////////////////////////////////////////
// State Encoding
//////////////////////////////////////////////////////////////////////////

  ** Encode the full view state -- string plus spilled values -- to a Dict for
  ** history state, server requests, and favorites.  The `sni` tag holds the
  ** string (with "$key" placeholders); the `spills` tag holds the spilled
  ** values when present.  Reverse with [decode].
  Dict encode()
  {
    if (spills.isEmpty) return Etc.dict1("sni", str)
    return Etc.dict2("sni", str, "spills", spills)
  }

  ** Decode the full view state from a Dict produced by [encode].
  static Sni decode(Dict d)
  {
    sni := fromStr(d->sni)
    spills := d["spills"] as Dict
    if (spills == null || spills.isEmpty) return sni
    return sni.withSpills(spills)
  }

//////////////////////////////////////////////////////////////////////////
// Builders
//////////////////////////////////////////////////////////////////////////

  ** Return new Sni with the given param set.
  ** If val is null, the param is removed.
  ** Returns this if unchanged.
  Sni set(Str name, Str? val)
  {
    if (params[name] == val) return this
    newParams := params.dup
    if (val != null) newParams[name] = val
    else newParams.remove(name)
    return rebuild(tail, newParams)
  }

  ** Set view name
  Sni setView(Str viewName)
  {
    set("view", viewName)
  }

  ** Return new Sni with the "sel" param set to the given selection ids,
  ** or removed if null.  More than 8 ids spill to a "$key" placeholder
  ** carried by the [spills] Dict.  See [sel].
  Sni setSel(Ref[]? ids)
  {
    // strip current spilled value if any
    cur := params["sel"]
    newSpills := spills
    if (cur != null && cur.startsWith("\$"))
      newSpills = Etc.dictRemove(newSpills, cur[1..-1])

    if (ids == null) return set("sel", null).replaceSpills(newSpills)

    // spill if too many to inline
    if (ids.size > maxInlineRefs)
    {
      key := spillKey(newSpills)
      newSpills = Etc.dictSet(newSpills, key, ids.toImmutable)
      return set("sel", "\$$key").replaceSpills(newSpills)
    }
    return set("sel", ids.join(",") |id| { id.id }).replaceSpills(newSpills)
  }

  ** Return copy with the given spills Dict, or this if unchanged
  private Sni replaceSpills(Dict newSpills)
  {
    if (Etc.dictEq(spills, newSpills)) return this
    return makeFields(str, provider, tail, params, isDir, frag, newSpills)
  }

  ** First unused spill key "a", "b", "c"...
  private static Str spillKey(Dict spills)
  {
    for (i := 0; true; ++i)
    {
      key := ('a' + i).toChar
      if (spills.missing(key)) return key
    }
    throw Err()
  }

  ** Append a name to the tail path, dropping any params.
  **
  **     /dev/a/b?view=xxx plusName("c.txt") => /dev/a/b/c.txt
  Sni plusName(Str name)
  {
    rebuild(tail.dup.add(name), emptyParams, false)
  }

  ** Append a trailing slash, dropping any params
  **
  **     /dev/a/b?view=xxx plusSlash => /dev/a/b/
  Sni plusSlash()
  {
    if (params.isEmpty && isDir) return this
    return rebuild(tail, emptyParams, true)
  }

  ** Return new Sni with given tail.
  Sni setTail(Str[] tail)
  {
    rebuild(tail, params)
  }

  ** Return new Sni with given params.
  Sni setParams([Str:Str]? params)
  {
    rebuild(tail, params ?: emptyParams)
  }

  ** Return new Sni with given fragment, or remove if null.
  Sni setFrag(Str? frag)
  {
    if (this.frag == frag) return this
    return rebuild(tail, params, isDir, frag)
  }

  ** Return new Sni with fragment set to given line and optional column.
  @NoDoc Sni setLine(Int line, Int col := 0)
  {
    if (col <= 0) return setFrag("L$line")
    return setFrag("L$line,$col")
  }

  ** Return Sni with fragment stripped.  Returns this if no fragment.
  Sni noFrag()
  {
    if (frag == null) return this
    return rebuild(tail, params, isDir, null)
  }

  ** Equality ignoring fragment
  Bool equalsIgnoreFrag(Sni that)
  {
    if (frag == null && that.frag == null) return str == that.str
    a := this.str; b := that.str
    ai := a.size; bi := b.size
    if (frag != null) ai = ai - frag.size - 1
    if (that.frag != null) bi = bi - that.frag.size - 1
    if (ai != bi) return false
    for (i := 0; i < ai; ++i) if (a[i] != b[i]) return false
    return true
  }

}

