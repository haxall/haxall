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

//////////////////////////////////////////////////////////////////////////
// Reserved Names
//////////////////////////////////////////////////////////////////////////

  ** Is the given spec name reserved
  static Bool isReservedSpecName(Str n)
  {
    if (n == "pragma") return true
    if (n == "index") return true
    return false
  }

  ** Is the given instance name reserved
  static Bool isReservedInstanceName(Str n)
  {
    if (n == "pragma") return true
    if (n == "index") return true
    if (n.startsWith("doc-")) return true
    if (n.startsWith("_")) return true
    if (n.startsWith("~")) return true
    return false
  }

  ** Is the given name a reserved lib meta tag
  static Bool isReservedLibMetaName(Str n)
  {
    reservedLibMetaNames.containsKey(n) || n.startsWith("xeto")
  }

  ** Is the given name a reserved spec meta tag
  static Bool isReservedSpecMetaName(Str n)
  {
    reservedSpecMetaNames.containsKey(n) || n.startsWith("xeto")
  }

  ** Is the given name a reserved lib or spec meta tag
  static Bool isReservedMetaName(Str n)
  {
    isReservedSpecMetaName(n) || isReservedLibMetaName(n) || n.startsWith("xeto")
  }

  private static once Str:Str reservedLibMetaNames()
  {
    Str:Str[:].setList([
      // used right now
      "id", "spec", "loaded",
      // future proofing
      "data", "instances", "name", "lib", "loc", "slots", "specs", "types", "xeto"
    ])
  }

  private static once Str:Str reservedSpecMetaNames()
  {
    Str:Str[:].setList([
    // used right now
    "id", "base", "type", "spec", "slot", "slots",
    // future proofing
    "class", "def", "is", "lib", "loc", "name", "parent", "qname", "super", "supers", "xeto"
    ])
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
    x := opts.get(name, null)
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
      if (v === Remove.val)
        acc.remove(n)
      else
        acc[n] = v
    }
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
  static Bool isa(CSpec a, CSpec b, Bool isTop := true)
  {
    // check if a and b are the same
    if (a === b) return true

    // if A is "maybe" type, then it also matches None
    if (b.isNone && a.isMaybe && isTop) return true

    // if A is sys::And type, then check any of A.ofs is B
    if (a.isAnd)
    {
      ofs := a.cofs
      if (ofs != null && ofs.any |x| { x.cisa(b) }) return true
    }

    // if A is sys::Or type, then check all of A.ofs is B
    if (a.isOr)
    {
      ofs := a.cofs
      if (ofs != null && ofs.all |x| { x.cisa(b) }) return true
    }

    // if B is sys::Or type, then check if A is any of B.ofs
    if (b.isOr)
    {
      ofs := b.cofs
      if (ofs != null && ofs.any |x| { a.cisa(x) }) return true
    }

    // check a's base type
    if (a.cbase != null) return isa(a.cbase, b, false)

    return false
  }

  ** Given a list of specs, remove any specs that are
  ** supertypes of other specs in this same list:
  **   [Equip, Meter, ElecMeter, Vav]  => ElecMeter, Vav
  static CSpec[] excludeSupertypes(CSpec[] list)
  {
    if (list.size <= 1) return list.dup

    acc := List(list.of, list.size)
    list.each |spec|
    {
      // check if this type has subtypes in our match list
      hasSubtypes := list.any |x| { x !== spec && x.cisa(spec) }

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

