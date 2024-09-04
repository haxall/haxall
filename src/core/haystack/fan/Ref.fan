//
// Copyright (c) 2009, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//    3 Jan 2009  Brian Frank  Creation
//   17 Sep 2012  Brian Frank  Rework RecId -> Ref
//

using concurrent

**
** Ref is used to model a record identifier and optional display string.
**
@Js
@Serializable { simple = true }
final const class Ref : xeto::Ref
{

//////////////////////////////////////////////////////////////////////////
// Construction
//////////////////////////////////////////////////////////////////////////

  ** Make with simple id
  static new fromStr(Str id, Bool checked := true)
  {
    try
    {
      return make(id, null)
    }
    catch (ParseErr e)
    {
      if (checked) throw e
      return null
    }
  }

  ** Construct with id string and optional display string.
  static new make(Str id, Str? dis)
  {
    err := isIdErr(id)
    if (err != null) throw ParseErr("Invalid Ref id ($err): $id")
    return makeImpl(id, dis)
  }

  ** Construct with Ref id string and optional display string.
  static new makeWithDis(Ref ref, Str? dis := null)
  {
    if (dis == null && ref.disVal == null) return ref
    return makeImpl(ref.id, dis)
  }

  ** Generate a unique Ref.
  static Ref gen()
  {
    time := (DateTime.nowTicks / 1sec.ticks).and(0xffff_ffff)
    rand := (Int.random).and(0xffff_ffff)
    str  := handleToStr(time, rand)
    return makeSegs(str, null, [RefSeg("", str)])
  }

  ** Construct with 64-bit handle
  @NoDoc static new makeHandle(Int handle)
  {
    time := handle.shiftr(32).and(0xffff_ffff)
    rand := handle.and(0xffff_ffff)
    str  := handleToStr(time, rand)
    return makeSegs(str, null, [RefSeg("", str)])
  }

  ** Format as "tttttttt-rrrrrrrr"
  private static Str handleToStr(Int time, Int rand)
  {
    StrBuf(20).add(time.toHex(8)).addChar('-').add(rand.toHex(8)).toStr
  }

  ** Constructor
  @NoDoc protected new makeImpl(Str id, Str? dis)
  {
    this.idRef  = id
    this.segs   = RefSeg.parse(id)
    this.disVal = dis
  }

  ** Constructor
  @NoDoc private new makeSegs(Str id, Str? dis, RefSeg[] segs)
  {
    this.idRef  = id
    this.segs   = segs
    this.disVal = dis
  }

//////////////////////////////////////////////////////////////////////////
// Identity
//////////////////////////////////////////////////////////////////////////

  ** Identifier which does **not** include the leading '@'
  override Str id() { idRef }
  private const Str idRef

  ** Optional display string for what the identifier references or null.
  @NoDoc Str? disVal
  {
    get { disValRef.val }
    set { disValRef.val = it }
  }
  private const AtomicRef disValRef := AtomicRef()

  ** Segments formatted as "scheme:body:scheme:body...".
  ** If the id has no colons then this a single segment
  ** with the scheme of ""
  @NoDoc const RefSeg[] segs

  ** Get this ref as 64-bit handle or throw UnsupportedErr
  @NoDoc Int handle()
  {
    try
    {
      if (id.size == 17 && id[8] == '-')
      {
        time := id[0..7].toInt(16)
        rand := id[9..16].toInt(16)
        return time.and(0xffff_ffff).shiftl(32).or(rand.and(0xffff_ffff))
      }
    }
    catch (Err e) {}
    if (isNull) return 0
    throw UnsupportedErr("Not handle Ref: $id")
  }

  ** Hash `id`
  override Int hash() { id.hash }

  ** Equality is based on `id` only (not dis).
  override Bool equals(Obj? that)
  {
    x := that as Ref
    if (x == null) return false
    return id == x.id
  }

  ** Return display value of target if available, otherwise `id`
  override Str dis() { disVal ?: idRef }

  ** String format is `id` which does **not** include
  ** the leading '@'.  Use `toCode` to include leading '@'.
  override Str toStr() { id }

  ** Return "@id"
  Str toCode() { StrBuf(id.size+1).addChar('@').add(id).toStr }

  ** Parse "@id"
  @NoDoc static Ref fromCode(Str s)
  {
    if (!s.startsWith("@")) throw ParseErr("Missing leading @: $s")
    return fromStr(s[1..-1])
  }

  ** Return "[@id, @id, ...]"
  @NoDoc static Str toCodeList(Ref[] refs)
  {
    s := StrBuf(refs.size*20).addChar('[')
    refs.each |ref, i|
    {
      if (i > 0) s.addChar(',')
      s.addChar('@').add(ref.id)
    }
    return s.addChar(']').toStr
  }

  ** Encode a list of Refs as "@a,@b,..."
  @NoDoc static Str listToStr(Ref[] ids)
  {
    if (ids.size == 0) return ""
    if (ids.size == 1) return ids.first.toCode
    s := StrBuf()
    s.capacity = ids.size * 20
    ids.each |id|
    {
      if (!s.isEmpty) s.addChar(',')
      s.addChar('@').add(id)
    }
    return s.toStr
  }

  ** Decode a list of refs separated by comma.  Support both
  ** old format (without @) and new format (with @)
  @NoDoc static Ref[] listFromStr(Str s)
  {
    if (s.isEmpty) return Ref#.emptyList
    return s.split(',').map |tok->Ref|
    {
      if (tok.startsWith("@")) tok = tok[1..-1]
      return Ref.make(tok, null)
    }
  }

  ** This Ref with no disVal
  @NoDoc Ref noDis()
  {
    if (disVal == null) return this
    return make(this.id, null)
  }

//////////////////////////////////////////////////////////////////////////
// Utils
//////////////////////////////////////////////////////////////////////////

  ** Null ref has id value of "null"?
  Bool isNull() { id == "null" }

  ** Return if the string is a valid Ref identifier or error message if not
  internal static Str? isIdErr(Str n)
  {
    if (n.isEmpty) return "empty string"
    for (i:=0; i<n.size; ++i)
      if (!isIdChar(n[i])) return "invalid char " + n[i].toChar.toCode('\'', true)
    return null
  }

  ** Return if the string is a valid Ref identifier.  See `isIdChar`
  static Bool isId(Str n) { isIdErr(n) == null }

  ** Take an arbitrary string and convert into a safe Ref identifier.
  static Str toId(Str n)
  {
    if (n.isEmpty) throw ArgErr("string is empty")
    buf := StrBuf()
    n.each |ch|
    {
      if (isIdChar(ch)) buf.addChar(ch)
    }
    if (buf.isEmpty) throw ArgErr("no valid id chars")
    return buf.toStr
  }

  **
  ** Is the given character a valid id char:
  **  - 'A' - 'Z'
  **  - 'a' - 'z'
  **  - '0' - '9'
  **  - '_ : - . ~'
  **
  static Bool isIdChar(Int char)
  {
    if (char < 127) return idChars[char]
    return false
  }

  private static const Bool[] idChars
  static
  {
    map := Bool[,]
    map.fill(false, 127)
    for (i:='a'; i<='z'; ++i) map[i] = true
    for (i:='A'; i<='Z'; ++i) map[i] = true
    for (i:='0'; i<='9'; ++i) map[i] = true
    map['_'] = true
    map[':'] = true
    map['-'] = true
    map['.'] = true
    map['~'] = true
    idChars = map
  }

  @NoDoc Str toZinc()
  {
    if (disVal == null) return toCode
    return StrBuf(1+id.size+8+disVal.size)
            .addChar('@').add(id)
            .addChar(' ').add(disVal.toCode).toStr
  }

  @NoDoc Str toJson()
  {
    s := StrBuf(2+id.size+8+(disVal?.size ?: 0))
    s.addChar('r').addChar(':').add(id)
    if (disVal != null) s.addChar(' ').add(disVal)
    return s.toStr
  }

//////////////////////////////////////////////////////////////////////////
// Abs/Rel
//////////////////////////////////////////////////////////////////////////

  ** Is this a relative ref with no "scheme:"
  @NoDoc Bool isRel()
  {
    segs.size == 1 && segs.first.scheme == "" && !isNull
  }

  ** Relativize this ref to the given prefix.
  @NoDoc Ref toRel(Str? prefix)
  {
    if (prefix == null) return this
    if (id.size <= prefix.size) return this
    if (id[prefix.size-1] != prefix[-1]) return this
    if (!id.startsWith(prefix)) return this
    return Ref.makeImpl(id[prefix.size..-1], disVal)
  }

  ** Make this ref absolute with given prefix
  @NoDoc Ref toAbs(Str prefix)
  {
    if (!isId(prefix)) throw ArgErr("Invalid Ref prefix: $prefix")
    if (prefix[-1] != ':') throw ArgErr("Prefix must end with colon: $prefix")
    return Ref.makeImpl(prefix+id, disVal)
  }

  ** Return if this is a ref formatted as "p:xxx:r:yyy"
  @NoDoc Bool isProjRec()
  {
    segs.size == 2 && segs[0].scheme == RefSchemes.proj && segs[1].scheme == RefSchemes.rec
  }

  ** Get the proj-relative version of this Ref.
  ** "@p:xxx:r:yyy" => "@yyy"
  @NoDoc Ref toProjRel()
  {
    if (!isProjRec()) return this
    body := segs[1].body
    return makeSegs(body, disVal, [RefSeg("", body)])
  }

//////////////////////////////////////////////////////////////////////////
// Main
//////////////////////////////////////////////////////////////////////////

  ** Call from command line to generate id
  @NoDoc static Void main() { echo(gen) }

//////////////////////////////////////////////////////////////////////////
// Fields
//////////////////////////////////////////////////////////////////////////

  ** Null ref is "@null"
  const static Ref nullRef := Ref("null")

  ** Default is `nullRef`
  const static Ref defVal := nullRef
}

**************************************************************************
** RefDir
**************************************************************************

@NoDoc @Js
enum class RefDir
{
  ** Not applicable
  na("na", "na"),

  ** Relationship direction is entity "<<" *from* referent
  from("<<", "\u00AB"),

  ** Relationship direction is entity ">>" *to* referrent
  to(">>", "\u00BB ")

  private new make(Str code, Str symbol)
  {
    this.code = code
    this.symbol = symbol
  }

  ** Code token is the "<<" or ">>" string
  const Str code

  ** Unicode display as chevron char
  const Str symbol

}

**************************************************************************
** RefSeg
**************************************************************************

** Ref segment
@NoDoc @Js
const class RefSeg
{
  ** Parse id into segments
  internal static RefSeg[] parse(Str id)
  {
    colon := id.index(":")
    if (colon == null) return [RefSeg("", id)]
    toks := id.split(':')
    segs := RefSeg[,]
    half := toks.size / 2
    segs.capacity = half
    for (i := 0; i<half; ++i)
      segs.add(RefSeg(toks[i*2], toks[i*2+1]))
    if (toks.size.isOdd)
      segs.add(RefSeg("", toks.last))
    return segs
  }

  ** Constructor
  new make(Str scheme, Str body)
  {
    this.scheme = scheme
    this.body = body
  }

  ** Scheme type such as "p" for project
  const Str scheme

  ** Body of the segment
  const Str body

  ** Equality based on scheme and body
  override Int hash() { scheme.hash.xor(body.hash) }

  ** Equality based on scheme and body
  override Bool equals(Obj? that)
  {
    x := that as RefSeg
    if (x == null) return false
    return scheme == x.scheme && body == x.body
  }

  ** Format as scheme:body
  override Str toStr() { "$scheme:$body" }
}

**************************************************************************
** RefSchemes
**************************************************************************

** Constants for compile time checked schemes
@NoDoc @Js
const class RefSchemes
{
  static const Str proj    := "p"
  static const Str host    := "h"
  static const Str user    := "u"
  static const Str rec     := "r"
  static const Str node    := "n"
  static const Str lic     := "lic"
  static const Str replica := "replica"
  static const Str subnet  := "subnet"
}

