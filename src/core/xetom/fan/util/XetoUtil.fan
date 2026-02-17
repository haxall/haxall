//
// Copyright (c) 2023, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   25 Feb 2023  Brian Frank  Creation
//

using concurrent
using util
using xeto
using haystack

**
** Utility functions
**
@Js
const class XetoUtil
{

//////////////////////////////////////////////////////////////////////////
// Naming
//////////////////////////////////////////////////////////////////////////

  ** Return if valid lib name
  static Bool isLibName(Str n)
  {
    libNameErr(n) == null
  }

  ** If the given lib is is not a valid name return an error message,
  ** otherwise if its valid return return null.
  static Str? libNameErr(Str n)
  {
    if (n.isEmpty) return "Lib name cannot be the empty string"
    if (!n[0].isLower) return "Lib name must start with lowercase letter"
    if (!n[-1].isLower && !n[-1].isDigit) return "Lib name must end with lowercase letter or digit"
    for (i := 0; i<n.size; ++i)
    {
      ch := n[i]
      prev := i == 0 ? 0 : n[i-1]
      if (ch.isUpper) return "Lib name must be all lowercase"
      if (prev == '.' && !ch.isLower) return "Lib dotted name sections must begin with lowercase letter"
      if (ch.isLower || ch.isDigit) continue
      if (ch == '_' || ch == '.')
      {
        if (prev.isLower || prev.isDigit) continue;
        return "Invalid adjacent chars at pos $i";
      }
      if (ch == ' ') return "Lib name cannot contain spaces"
      return "Invalid lib name char '$ch.toChar' 0x$ch.toHex"
    }
    return null
  }

  ** Return if valid top-level type (or mixin) name
  static Bool isTypeName(Str n)
  {
    isSpecName(n) && n[0].isUpper
  }

  ** Return if valid slot name
  static Bool isSlotName(Str n)
  {
    isSpecName(n) && n[0].isLower
  }

  ** Return if valid function name - same as isSlotName
  static Bool isFuncName(Str n)
  {
    isSlotName(n)
  }

  ** Return if valid spec name
  static Bool isSpecName(Str n)
  {
    if (n.isEmpty) return false
    ch := n[0]

    // _123
    if (ch == '_') return n.all |c, i| { i == 0 || c.isDigit }

    // Foo_Bar_123
    if (!ch.isAlpha) return false
    return n.all |c| { c.isAlphaNum || c == '_' }
  }

  ** Return if valid instance id/name (and must not start with uppercase)
  static Bool isInstanceName(Str n)
  {
    Ref.isId(n) && !n[0].isUpper && !n.contains(":")
  }

  ** Return if name is "_" + digits
  static Bool isAutoName(Str n)
  {
    if (n.size < 2 || n[0] != '_' || !n[1].isDigit) return false
    for (i:=2; i<n.size; ++i) if (!n[i].isDigit) return false
    return true
  }

  ** Generate an auto name of "_0", "_1", etc.
  ** This method must be called in incrementing order for a given thread
  static Str autoName(Int i)
  {
    // check cache
    autoNames := (Str[])autoNamesRef.val
    if (i < autoNames.size) return autoNames[i]

    // lock, try again, and add new one
    autoNameLock.lock
    try
    {
      // check again
      autoNames = (Str[])autoNamesRef.val
      if (i < autoNames.size) return autoNames[i]

      //  i should be size
      if (i != autoNames.size) throw ArgErr("Out of order: $i")

      // build new one and cache
      s := i.toStr
      n := StrBuf(1+s.size).addChar('_').add(s).toStr
      autoNamesRef.val = autoNames.dup.add(n).toImmutable
      return n
    }
    finally autoNameLock.unlock
  }
  private const static Lock autoNameLock := Lock.makeReentrant
  private const static AtomicRef autoNamesRef := AtomicRef(Str[,].toImmutable)

  ** Convert "fooBarBaz" or "FooBarBaz" to "foo.bar.baz".
  static Str camelToDotted(Str name, Int dot := '.')
  {
    s := StrBuf(name.size + 4)
    name.each |char|
    {
      if (char.isUpper)
      {
        if (!s.isEmpty) s.addChar(dot)
        s.addChar(char.lower)
      }
      else
      {
        s.addChar(char)
      }
    }
    return s.toStr
  }

  ** Convert "fooBarBaz" or "FooBarBaz" to "foo-bar-baz".
  static Str camelToDashed(Str name)
  {
    camelToDotted(name, '-')
  }

  ** Convert "foo.bar.baz" to "fooBarBaz"
  static Str dottedToCamel(Str name, Int dot := '.')
  {
    s := StrBuf(name.size)
    capitalize := false
    name.each |char|
    {
      if (char == dot)
        capitalize = true
      else if (capitalize)
        { s.addChar(char.upper); capitalize = false }
      else
        s.addChar(char)
    }
    return s.toStr
  }

  ** Convert "foo-bar-baz" to "fooBarBaz"
  static Str dashedToCamel(Str name)
  {
    dottedToCamel(name, '-')
  }

  ** Build qname from optional lib and simple name
  static Str qname(Str? lib, Str name)
  {
    if (lib == null) return name
    return StrBuf(lib.size+2+name.size).add(lib).add("::").add(name).toStr
  }

  ** Convert "foo.bar::Baz" to simple name "Baz" or null if no "::"
  static Str? qnameToName(Obj qname)
  {
    s := qname.toStr
    colon := s.index(":")
    if (colon == null || colon < 1 || colon+2 >= s.size || s[colon+1] != ':') return null
    return s[colon+2..-1]
  }

  ** Convert "foo.bar::Baz" to lib name "foo.bar" or null if no "::"
  static Str? qnameToLib(Obj qname)
  {
    s := qname.toStr
    colon := s.index(":")
    if (colon == null || colon < 1 || colon+2 >= s.size || s[colon+1] != ':') return null
    return s[0..<colon]
  }

  ** Convert "foo.bar::Baz.x.y.z" to "x.y.z" or null.
  static Str? qnameToSlotPath(Obj qname)
  {
    s := qname.toStr
    colon := s.index(":")
    if (colon == null || colon < 1 || colon+2 >= s.size || s[colon+1] != ':') return null
    dot := s.index(".", colon+1)
    if (dot == null) return null
    return s[dot+1..-1]
  }

  ** Convert a list of Str or Ref qnames into the unique list of libraries
  static Str[] qnamesToLibs(Obj[] qnames)
  {
    if (qnames.isEmpty) return Str#.emptyList
    acc := Str:Str[:]
    qnames.each |qname|
    {
      lib := qnameToLib(qname)
      if (lib != null) acc[lib] = lib
    }
    return acc.vals
  }

  ** Convert a list of dicts with "spec" tag to unique lib names
  static Str[] dataToLibs(Dict[] recs)
  {
    // get all unique lib names
    acc := Str:Str[:]
    recs.each |row|
    {
      spec := row["spec"] as Ref
      if (spec == null) return
      libName := XetoUtil.qnameToLib(spec.toStr)
      if (libName == null) return
      acc[libName] = libName
    }
    return acc.keys
  }

  ** Convert a lib name like "foo.bar.baz" to "baz"
  static Str lastDottedName(Str n)
  {
    dot := n.indexr(".")
    if (dot == null) return n
    return n[dot+1..-1]
  }

  ** Project companion lib name
  static const Str companionLibName := "proj"

//////////////////////////////////////////////////////////////////////////
// Literals
//////////////////////////////////////////////////////////////////////////

  ** Xeto quoted string (we don't escape $ like Fantom Str.toCode)
  static Str strToCode(Str s)
  {
    buf := StrBuf(2 + s.size)
    buf.addChar('"')
    s.each |ch|
    {
      esc := ch < 127 ? strEscapes.get(ch) : null
      if (esc != null) buf.add(esc); else buf.addChar(ch)
    }
    return buf.addChar('"').toStr
  }

  ** Xeto quoted lookup table
  const static Str?[] strEscapes
  static
  {
    acc := Str?[,]
    acc.size = 127
    (0 ..< ' ').each |i| { acc[i] = "\\u{" + i.toHex + "}" }
    acc['\n'] = Str<|\n|>
    acc['\r'] = Str<|\r|>
    acc['\f'] = Str<|\f|>
    acc['\t'] = Str<|\t|>
    acc['\\'] = Str<|\\|>
    acc['"']  = Str<|\"|>
    strEscapes = acc
  }

//////////////////////////////////////////////////////////////////////////
// Reserved Names
//////////////////////////////////////////////////////////////////////////

  ** Is the given spec name reserved
  static Bool isReservedSpecName(Str n)
  {
    if (n == "Pragma") return true
    return false
  }

  ** Is the given instance name reserved
  static Bool isReservedInstanceName(Str n)
  {
    if (n == "pragma") return true
    if (n.startsWith("doc-")) return true
    if (n.startsWith("_")) return true
    if (n.startsWith("~")) return true
    return false
  }

//////////////////////////////////////////////////////////////////////////
// Spec Dict Representation
//////////////////////////////////////////////////////////////////////////

  const static Ref specSpecRef := Ref("sys::Spec")

  static Obj? specGet(Spec x, Str name)
  {
    if (name == "id")   return x.id
    if (name == "name") return x.name
    if (name == "spec") return specSpecRef
    if (x.isType)
    {
      if (name == "base") return x.base?.id
    }
    else
    {
      if (name == "type") return x.type.id
    }
    return x.meta.get(name)
  }

  static Bool specHas(Spec x, Str name)
  {
    if (name == "id")    return true
    if (name == "name")  return true
    if (name == "spec")  return true
    if (name == "base")  return x.isType && x.base != null
    if (name == "type")  return !x.isType
    return x.meta.has(name)
  }

  static Bool specMissing(Spec x, Str name)
  {
    if (name == "id")   return false
    if (name == "name") return false
    if (name == "spec") return false
    if (name == "base") return !x.isType || x.base == null
    if (name == "type") return x.isType
    return x.meta.missing(name)
  }

  static Void specEach(Spec x, |Obj val, Str name| f)
  {
    f(x.id, "id")
    f(x.name, "name")
    f(specSpecRef, "spec")
    if (x.isType)
    {
      if (x.base != null) f(x.base.id, "base")
    }
    else
    {
      f(x.type.id, "type")
    }
    x.meta.each(f)
  }

  static Obj? specEachWhile(Spec x, |Obj val, Str name->Obj?| f)
  {
    r := f(x.id, "id");          if (r != null) return r
    r  = f(x.name, "name");      if (r != null) return r
    r  = f(specSpecRef, "spec"); if (r != null) return r
    if (x.isType)
    {
      if (x.base != null) { r = f(x.base.id, "base"); if (r != null) return r }
    }
    else
    {
      r = f(x.type.id, "type"); if (r != null) return r
    }
    return x.meta.eachWhile(f)
  }

  static Obj? specTrap(Spec x, Str name, Obj?[]? args := null)
  {
    val := specGet(x, name)
    if (val != null) return val
    return x.meta.trap(name, args)
  }

//////////////////////////////////////////////////////////////////////////
// Dirs
//////////////////////////////////////////////////////////////////////////

  ** Return "{work}" for source path of "{work}/src/xeto/{name}".
  static File? srcToWorkDir(LibVersion v)
  {
    srcPath := v.file.path
    if (srcPath.size < 4 || srcPath[-3] != "src" || srcPath[-2] != "xeto" || srcPath[-1] != v.name)
      throw Err("Non-standard src dir: $v [$v.file]")
    return (v.file + `../../../`).normalize
  }

  ** Return "{work}/lib/xeto/{name}" for source path of "{work}/src/xeto/{name}".
  static File? srcToLibDir(LibVersion v)
  {
    srcToWorkDir(v) + `lib/xeto/${v.name}/`
  }

  ** Return "{work}/lib/xeto/{name}/{name}-{version}.xetolib" for
  ** source path of "{work}/src/xeto/{name}".
  static File? srcToLibZip(LibVersion v)
  {
    srcToWorkDir(v) + `lib/xeto/${v.name}/${v.name}-${v.version}.xetolib`
  }

//////////////////////////////////////////////////////////////////////////
// Coercion
//////////////////////////////////////////////////////////////////////////

  ** To floating point number
  static Float? toFloat(Obj? x)
  {
    if (x == null) return x
    if (x is Number) return ((Number)x).toFloat
    if (x is Num) return ((Num)x).toFloat
    return null
  }

//////////////////////////////////////////////////////////////////////////
// Opts
//////////////////////////////////////////////////////////////////////////

  ** Boolean option
  static Bool optBool(Dict? opts, Str name, Bool def)
  {
    v := opts?.get(name)
    if (v === Marker.val) return true
    if (v is Bool) return v
    return def
  }

  ** Integer option
  static Int optInt(Dict? opts, Str name, Int def)
  {
    v := opts?.get(name)
    if (v is Int) return v
    if (v is Number) return ((Number)v).toInt
    return def
  }

  ** Get logging function from options
  static |XetoLogRec|? optLog(Dict? opts, Str name)
  {
    if (opts == null) return null
    x := opts.get(name)
    if (x == null) return null
    if (x is Unsafe) x = ((Unsafe)x).val
    if (x is Func) return x
    throw Err("Expecting |XetoLogRec| func for $name.toCode [$x.typeof]")
  }

  ** Standard option to fidellity level mapping
  static XetoFidelity optFidelity(Dict? opts)
  {
    if (optBool(opts, "haystack", false)) return XetoFidelity.haystack
    return XetoFidelity.full
  }

//////////////////////////////////////////////////////////////////////////
// Meta
//////////////////////////////////////////////////////////////////////////

  ** Merge in own meta with special handling for Remove
  static Void addOwnMeta(Str:Obj acc, Dict own)
  {
    if (own.isEmpty) return
    own.each |v, n|
    {
      if (v === None.val)
        acc.remove(n)
      else
        acc[n] = v
    }
  }

//////////////////////////////////////////////////////////////////////////
// Inheritance
//////////////////////////////////////////////////////////////////////////

  static Void eachInherited(Spec x, |Spec| f)
  {
    f(x)
    if (x.isCompound && x.isAnd)
      x.ofs.each |of| { eachInherited(of, f) }
    else if (x.base != null)
      eachInherited(x.base, f)
  }

  static SpecMap globals(Spec base)
  {
    acc := SpecMap[,]
    eachInherited(base) |x|
    {
      g := x.globalsOwn
      if (g.isEmpty) return
      if (acc.containsSame(g)) return
      acc.add(g)
    }
    return SpecMap(acc)
  }

  static Spec? member(Spec base, Str name, Bool checked := true)
  {
    x := base.members.get(name, checked)
    if (x != null) return x
    if (checked) throw UnknownSpecErr("Member not found: ${base.qname}.${name}")
    return null
  }

//////////////////////////////////////////////////////////////////////////
// Is-A
//////////////////////////////////////////////////////////////////////////

  ** Return if a is a direct subtype of b
  static Bool isDirectSubtype(Spec a, Spec b)
  {
    if (a.base === b) return true
    if (a.isAnd)
    {
      ofs := a.ofs(false)
      return ofs != null && ofs.any |x| { x === b }
    }
    return false
  }

  ** Return if a is-a b
  static Bool isa(Spec a, Spec b, Bool isTop := true)
  {
    // check if a and b are the same
    if (a === b) return true

    // if A is "maybe" type, then it also matches None
    if (b.isNone && a.isMaybe && isTop) return true

    // if A is sys::And type, then check any of A.ofs is B
    if (a.isAnd)
    {
      ofs := a.ofs(false)
      if (ofs != null && ofs.any |x| { x.isa(b) }) return true
    }

    // if A is sys::Or type, then check all of A.ofs is B
    if (a.isOr)
    {
      ofs := a.ofs(false)
      if (ofs != null && ofs.all |x| { x.isa(b) }) return true
    }

    // if B is sys::Or type, then check if A is any of B.ofs
    if (b.isOr)
    {
      ofs := b.ofs(false)
      if (ofs != null && ofs.any |x| { a.isa(x) }) return true
    }

    // check a's base type
    if (a.base != null) return isa(a.base, b, false)

    return false
  }

  ** Given a list of specs, remove any specs that are
  ** supertypes of other specs in this same list:
  **   [Equip, Meter, ElecMeter, Vav]  => ElecMeter, Vav
  static Spec[] excludeSupertypes(Spec[] list)
  {
    if (list.size <= 1) return list.dup

    acc := List(list.of, list.size)
    list.each |spec|
    {
      // check if this type has subtypes in our match list
      hasSubtypes := list.any |x| { x !== spec && x.isa(spec) }

      // add it to our best accumulator only if no subtypes
      if (!hasSubtypes) acc.add(spec)
    }
    return acc
  }

  ** Given a list of specs, find the most specific common
  ** supertype they all share.
  static Spec commonSupertype(Spec[] specs)
  {
    if (specs.isEmpty) throw ArgErr("Must pass at least one spec")
    if (specs.size == 1) return specs[0]
    best := specs.first
    specs.eachRange(1..-1) |spec|
    {
      best = commonSupertypeBetween(best, spec)
    }
    return best
  }

  ** Find the most common supertype between two specs.
  ** In the case of and/or types we only work first ofs
  static Spec commonSupertypeBetween(Spec a, Spec b)
  {
    if (a === b) return a
    if (a.isa(b)) return b
    if (b.isa(a)) return a
    if (a.base == null) return a
    if (b.base == null) return b
    abase := a.isCompound ? a.ofs.first : a.base
    bbase := b.isCompound ? b.ofs.first : b.base
    return commonSupertypeBetween(abase, bbase)
  }

//////////////////////////////////////////////////////////////////////////
// Fidelity
//////////////////////////////////////////////////////////////////////////

  ** Convert Xeto full level fidelity to a Haystack fidelity
  static Obj? toHaystack(Obj? x)
  {
    if (x == null) return x
    kind := Kind.fromVal(x, false)
    if (kind != null)
    {
      if (kind.isDict) return toHaystackDict(x)
      if (kind.isList) return toHaystackList(x)
      return x
    }
    if (x is Num) return Number.makeNum(x)
    if (x is Duration) return Number.makeDuration(x)
    return x.toStr
  }

  ** Convert Xeto full level fidelity to a Haystack fidelity
  static Dict toHaystackDict(Dict x)
  {
    x.map |v, n| { toHaystack(v) }
  }

  ** Convert Xeto full level fidelity to a Haystack fidelity
  static List toHaystackList(List x)
  {
    of := Obj#
    if (x.of.isNullable) of = of.toNullable
    acc := List(of, x.size)
    x.each |v| { acc.add(toHaystack(v)) }
    return acc
  }

//////////////////////////////////////////////////////////////////////////
// Misc
//////////////////////////////////////////////////////////////////////////

  ** Return if lib name 'd' is under lib 'x' name's dependency graph
  static Bool isInDepends(Namespace ns, Str x, Str d)
  {
    if (x == d) return true

    lib := ns.version(x, false)
    if (lib == null) return false

    return lib.depends.any |q| { isInDepends(ns, q.name, d) }
  }

  static Bool isDictList(Obj x)
  {
    list := x as List
    if (list == null || list.isEmpty) return false
    if (list.of.fits(Dict#)) return true
    return list.all { it is Dict }
  }

}

**************************************************************************
** XetoFidelity
**************************************************************************

** Data fidelity and type erasure level
@Js
enum class XetoFidelity
{
  full,
  haystack,
  json

  Bool isFull() { this === full }

  ** Coerce value to the proper level of data fidelity
  Obj? coerce(Obj? x)
  {
    if (this === haystack) return XetoUtil.toHaystack(x)
    if (this === json) throw Err("JSON fidelity not supported yet")
    return x
  }
}

