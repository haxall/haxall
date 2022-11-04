//
// Copyright (c) 2009, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   24 Jun 2009  Brian Frank  Create
//

using concurrent

**
** Etc is the utility methods for Haystack.
**
@Js
const class Etc
{

//////////////////////////////////////////////////////////////////////////
// Dict
//////////////////////////////////////////////////////////////////////////

  **
  ** Get the emtpy Dict instance.
  **
  static Dict emptyDict() { EmptyDict.val }

  **
  ** Empty Str:Obj? map
  **
  @NoDoc static const Str:Obj? emptyTags := [:]

  **
  ** Make a Dict instance where 'val' is one of the following:
  **   - Dict: return 'val'
  **   - null: return `emptyDict`
  **   - Str:Obj?: wrap map as Dict
  **   - Str[]: dictionary of key/Marker value pairs
  **
  static Dict makeDict(Obj? val)
  {
    if (val == null) return emptyDict
    if (val is Map)
    {
      Str:Obj? map := val
      switch (map.size)
      {
        case 0:  return emptyDict
        case 1:  return Dict1(map)
        case 2:  return Dict2(map)
        case 3:  return Dict3(map)
        case 4:  return Dict4(map)
        case 5:  return Dict5(map)
        case 6:  return Dict6(map)
        default: return MapDict(map)
      }
    }
    if (val is Dict)
    {
      return val
    }
    if (val is List)
    {
      tags := Str:Obj[:]
      ((List)val).each |Str key| { tags[key] = Marker.val }
      return makeDict(tags)
    }
    throw ArgErr("Cannot create dict from $val.typeof")
  }

  **
  ** Make a Dict with one name/value pair
  **
  static Dict makeDict1(Str n, Obj? v)
  {
    Dict1.make1(n, v)
  }

  **
  ** Make a Dict with two name/value pairs
  **
  static Dict makeDict2(Str n0, Obj? v0, Str n1, Obj? v1)
  {
    Dict2.make2(n0, v0, n1, v1)
  }

  **
  ** Make a Dict with three name/value pairs
  **
  static Dict makeDict3(Str n0, Obj? v0, Str n1, Obj? v1, Str n2, Obj? v2)
  {
    Dict3.make3(n0, v0, n1, v1, n2, v2)
  }

  **
  ** Make a Dict with four name/value pairs
  **
  static Dict makeDict4(Str n0, Obj? v0, Str n1, Obj? v1, Str n2, Obj? v2, Str n3, Obj? v3)
  {
    Dict4.make4(n0, v0, n1, v1, n2, v2, n3, v3)
  }

  **
  ** Make a Dict with five name/value pairs
  **
  static Dict makeDict5(Str n0, Obj? v0, Str n1, Obj? v1, Str n2, Obj? v2, Str n3, Obj? v3, Str n4, Obj? v4)
  {
    Dict5.make5(n0, v0, n1, v1, n2, v2, n3, v3, n4, v4)
  }

  **
  ** Make a Dict with six name/value pairs
  **
  static Dict makeDict6(Str n0, Obj? v0, Str n1, Obj? v1, Str n2, Obj? v2, Str n3, Obj? v3, Str n4, Obj? v4, Str n5, Obj? v5)
  {
    Dict6.make6(n0, v0, n1, v1, n2, v2, n3, v3, n4, v4, n5, v5)
  }

  **
  ** Make a list of Dict instances using `makeDict`.
  **
  static Dict[] makeDicts(Obj?[] maps)
  {
    maps.map |map -> Dict| { makeDict(map) }
  }

  **
  ** Get a read/write list of the dict's name keys.
  **
  static Str[] dictNames(Dict d)
  {
    names := Str[,]
    d.each |v, n| { names.add(n) }
    return names
  }

  **
  ** Given a list of dictionaries, find all the common names
  ** used.  Return the names in standard sorted order.  Any
  ** null dicts are skipped.
  **
  static Str[] dictsNames(Dict?[] dicts)
  {
    Str:Str map := Str:Str[:] { ordered = true }
    hasId   := false
    hasDef  := false
    hasName := false
    hasMod  := false
    dicts.each |dict|
    {
      if (dict == null) return
      dict.each |v, n|
      {
        if (n == "id")   { hasId   = true; return }
        if (n == "def")  { hasDef  = true; return }
        if (n == "name") { hasName = true; return }
        if (n == "mod")  { hasMod  = true; return }
        map[n] = n
      }
    }
    list := map.vals.sort
    if (hasName) list.insert(0, "name")
    if (hasDef)  list.insert(0, "def")
    if (hasId)   list.insert(0, "id")
    if (hasMod)  list.add("mod")
    return list
  }

  **
  ** Get all the non-null values mapped by a dictionary.
  **
  static Obj[] dictVals(Dict d)
  {
    vals := Obj[,]
    d.each |v, n| { if (v != null) vals.add(v) }
    return vals
  }

  **
  ** Convert a Dict to a read/write map.  This method is expensive,
  ** when possible you should instead use `Dict.each`.
  **
  static Str:Obj? dictToMap(Dict? d)
  {
    map := Str:Obj?[:]
    if (d != null) d.each |v, n| { map[n] = v }
    return map
  }

  **
  ** Apply the given map function to each name/value pair
  ** to construct a new Dict.
  **
  static Dict dictMap(Dict d, |Obj? v, Str n->Obj?| f)
  {
    map := Str:Obj?[:]
    d.each |v, n| { map[n] = f(v, n) }
    return makeDict(map)
  }

  **
  ** Return a new Dict containing the name/value pairs
  ** for which f returns true. If f returns false for
  ** every pair, then return an empty Dict.
  **
  static Dict dictFindAll(Dict d, |Obj? v, Str n->Bool| f)
  {
    map := Str:Obj?[:]
    d.each |v, n| { if (f(v, n)) map[n] = v }
    return makeDict(map)
  }

  **
  ** Return if any of the tag name/value pairs match
  ** the given function.
  **
  static Bool dictAny(Dict d, |Obj? v, Str n->Bool| f)
  {
    r := false
    d.each |v, n| { if (!r) r = f(v, n) }
    return r
  }

  **
  ** Return if all of the tag name/value pairs match
  ** the given function.
  **
  static Bool dictAll(Dict d, |Obj? v, Str n->Bool| f)
  {
    r := true
    d.each |v, n| { if (r) r = f(v, n) }
    return r
  }

  **
  ** Add/set all the name/value pairs in a with those defined
  ** in b.  If b defines a remove value then that name/value is
  ** removed from a.  The b parameter may be any value
  ** accepted by `makeDict`
  **
  static Dict dictMerge(Dict a, Obj? b)
  {
    if (b == null) return a
    if (b is Dict)
    {
      bd := (Dict)b
      if (a.isEmpty) return dictRemoveAllWithVal(bd, Remove.val)
      if (bd.isEmpty) return a

      tags := dictToMap(a)
      bd.each |v, n|
      {
        if (v === Remove.val) tags.remove(n)
        else tags[n] = v
      }
      return makeDict(tags)
    }
    else
    {
      bm := (Str:Obj?)b
      if (bm.isEmpty) return a

      tags := dictToMap(a)
      bm.each |v, n|
      {
        if (v === Remove.val) tags.remove(n)
        else tags[n] = v
      }
      return makeDict(tags)
    }
  }

  **
  ** Remove all keys with the given value
  **
  @NoDoc static Dict dictRemoveAllWithVal(Dict d, Obj? val)
  {
    if (d.isEmpty) return d
    [Str:Obj?]? map := null
    d.each |v, n|
    {
      if (v != val) return
      if (map == null) map = dictToMap(d)
      map.remove(n)
    }
    if (map == null) return d
    return makeDict(map)
  }

  **
  ** Strip any tags which a null value from the given dict.
  **
  @NoDoc static Dict dictRemoveNulls(Dict d)
  {
    dictRemoveAllWithVal(d, null)
  }

  **
  ** Set a name/val pair in an existing dict or d is null then
  ** create a new dict with given name/val pair.
  **
  static Dict dictSet(Dict? d, Str name, Obj? val)
  {
    if (d == null || d.isEmpty) return makeDict1(name, val)
    map := Str:Obj?[:]
    if (d != null)
    {
      if (d is Row) map.ordered = true
      d.each |v, n| { map[n] = v }
    }
    map[name] = val
    return makeDict(map)
  }

  **
  ** Remove a name/val pair from an exisiting dict, or
  ** if the name isn't found then return original dict.
  **
  static Dict dictRemove(Dict d, Str name)
  {
    if (d.missing(name)) return d
    map := Str:Obj?[:]
    d.each |v, n| { map[n] = v }
    map.remove(name)
    return makeDict(map)
  }

  **
  ** Remove all names from the given dict.
  ** Ignore any name not defined as a tag.
  **
  static Dict dictRemoveAll(Dict d, Str[] names)
  {
    if (names.isEmpty) return d
    if (names.size == 1) return dictRemove(d, names[0])
    map := Str:Obj?[:]
    d.each |v, n| { map[n] = v }
    names.each |n| { map.remove(n) }
    return makeDict(map)
  }

  **
  ** Rename given name if its defined in the dict, otherwise return original.
  **
  static Dict dictRename(Dict d, Str oldName, Str newName)
  {
    val := d[oldName]
    if (val == null) return d
    map := Str:Obj?[:]
    d.each |v, n| { map[n] = v }
    map.remove(oldName)
    map[newName] = val
    return makeDict(map)
  }

  **
  ** Construct an object which wraps a dict and is suitable to use
  ** for a hash key in a `sys::Map`.  The key provides implementations
  ** of `sys::Obj.hash` and `sys::Obj.equals` based on the
  ** the name/value pairs in the dict.  Hash keys do not support
  ** Dicts which contain anything but scalar values (nested lists,
  ** dicts, and grids are silently ignored for hash/equality purposes).
  **
  static Obj dictHashKey(Dict d) { DictHashKey(d) }

  **
  ** Return if two dicts are equal with same name/value pairs.
  ** Value are compared via the `sys::Obj.equals` method.  Ordering
  ** of the dict tags is not considered.
  **
  static Bool dictEq(Dict a, Dict b)
  {
    x := a.eachWhile |v, n| { eq(b[n], v) ? null : "ne" }
    if (x != null) return false
    x = b.eachWhile |v, n| { a.has(n) || v == null ? null : "ne" }
    if (x != null) return false
    return true
  }

  **
  ** Dump dict name/value pairs to output stream
  **
  @NoDoc
  static Void dictDump(Dict d, OutStream out := Env.cur.out)
  {
    keys := dictNames(d).sort
    keys.each |n|
    {
      v := d[n]
      out.print("  ").print(n)
      if (v !== Marker.val) out.print(": ").print(Etc.valToDis(v))
      out.printLine
    }
    out.flush
  }

  **
  ** Map dict tags to a string such as '{tag1:val1, ...}'
  **
  @NoDoc
  static Str dictToStr(Dict d)
  {
    s := StrBuf()
    s.add("{")
    d.each |v, n|
    {
      if (s.size > 1) s.add(", ")
      s.add(n)
      if (v === Marker.val) return
      s.add(":").add(v)
    }
    return s.add("}").toStr
  }

  ** Get dict tag as Number duration
  @NoDoc
  static Duration? dictGetDuration(Dict d, Str name, Duration? def := null, Duration? remove := def)
  {
    val := d[name]
    if (val === Remove.val) return remove
    num := val as Number
    if (num != null) return num.toDuration
    return def
  }

  ** Get dict tag as Number int
  @NoDoc
  static Int? dictGetInt(Dict d, Str name, Int? def := null, Int? remove := def)
  {
    val := d[name]
    if (val === Remove.val) return remove
    num := val as Number
    if (num != null) return num.toInt
    return def
  }

//////////////////////////////////////////////////////////////////////////
// Values
//////////////////////////////////////////////////////////////////////////

  ** Return if two values are equal including Haystack collection types
  @NoDoc static Bool eq(Obj? a, Obj? b)
  {
    if (a is List && b is List) return listEq(a, b)
    if (a is Dict && b is Dict) return dictEq(a, b)
    if (a is Grid && b is Grid) return gridEq(a, b)
    return a == b
  }

  ** Return if two lists are equal without considering type
  @NoDoc static Bool listEq(Obj?[] a, Obj?[] b)
  {
    if (a.size != b.size) return false
    return a.all |av, i| { eq(av, b[i]) }
  }

  ** Return if two grids are equal
  @NoDoc static Bool gridEq(Grid a, Grid b)
  {
    // grid meta
    if (!Etc.dictEq(a.meta, b.meta)) return false

    // columns
    if (a.cols.size != b.cols.size) return false
    for (i := 0; i<a.cols.size; ++i)
    {
      ac := a.cols[i]
      bc := b.cols[i]
      if (ac.name != bc.name) return false
      if (!Etc.dictEq(ac.meta, bc.meta)) return false
    }

    // require non-lazy grid with size
    if (a.size != b.size) return false
    for (ri := 0; ri<a.size; ++ri)
    {
      ar := a[ri]
      br := b[ri]
      for (ci := 0; ci<a.cols.size; ++ci)
        if (!eq(ar.val(a.cols[ci]), br.val(b.cols[ci])))
          return false
    }

    return true
  }

//////////////////////////////////////////////////////////////////////////
// Dis
//////////////////////////////////////////////////////////////////////////

  **
  ** Given a dict, attempt to find the best display string:
  **   1. 'dis' tag
  **   2. 'disMacro' tag returns `macro` using dict as scope
  **   3. 'disKey' maps to qname locale key
  **   4. 'name' tag
  **   5. 'tag' tag
  **   6. 'id' tag
  **   7. default
  **
  static Str? dictToDis(Dict dict, Str? def := "")
  {
    Obj? d
    d = dict.get("dis", null);       if (d != null) return d.toStr
    d = dict.get("disMacro", null);  if (d != null) return macro(d.toStr, dict)
    d = dict.get("disKey", null);    if (d != null) return disKey(d)
    d = dict.get("name", null);      if (d != null) return d.toStr
    d = dict.get("def", null);       if (d != null) return d.toStr
    d = dict.get("tag", null);       if (d != null) return d.toStr
    id := dict.get("id", null) as Ref; if (id != null) return id.dis
    return def
  }

  **
  ** Get a relative display name.  If the child display name
  ** starts with the parent, then we can strip that as the
  ** common suffix.
  **
  static Str relDis(Str parent, Str child)
  {
    // we could really improve efficiency of this
    p := parent.split
    c := child.split
    m := p.size.min(c.size)
    i := 0
    while (i < m && p[i] == c[i]) ++i
    if (i == 0 || i >= c.size) return child
    dis := c[i..-1].join(" ")
    if (dis.size > 2 && relDisStrip(dis[0])) dis = dis[1..-1].trim
    return dis
  }

  private static Bool relDisStrip(Int c)
  {
    c == ':' || c == '-' || c == '\u2022'
  }

  **
  ** Given two display strings, return 1, 0, or -1 if a is less
  ** than, equal to, or greater than b.  The comparison is case
  ** insensitive and takes into account trailing digits so that a
  ** dis str such as "Foo-10" is greater than "Foo-2".
  **
  static Int compareDis(Str a, Str b)
  {
    // handle empty strings
    if (a.isEmpty) return b.isEmpty ? 0 : -1
    if (b.isEmpty) return 1

    // check first chars as quick optimization
    a0 := a[0].lower
    b0 := b[0].lower
    if (a0 != b0) return a0 <=> b0

    // if neither has trailing digits
    if (!a[-1].isDigit || !b[-1].isDigit) return a.localeCompare(b)

    // find first index of digits for each string
    adi := a.size; while(adi>0 && a[adi-1].isDigit) --adi
    bdi := b.size; while(bdi>0 && b[bdi-1].isDigit) --bdi

    // if the prefixes before the digits don't line up
    if (adi != bdi) return a.localeCompare(b)

    // compare base strings without digits
    mini := adi.min(bdi)
    for (i:=0; i<mini; ++i)
      if (a[i].lower != b[i].lower) return a[i].lower <=> b[i].lower
    if (adi != bdi) return adi <=> bdi

    // prefixes are equal, compare by digits
    anum := a[adi..-1].toInt(10, false)
    bnum := b[bdi..-1].toInt(10, false)
    return anum <=> bnum
  }

  **
  ** Sort a list of dicts by their dis
  **
  @NoDoc static Dict[] sortDictsByDis(Dict[] dicts)
  {
    sortDis(dicts) |Dict dict->Str| { dictToDis(dict) }
  }

  **
  ** Sort a list by display name.  The 'getDis' name function
  ** is used to extract the display name from each item or if null
  ** then the list is assumed to be display names.  The sort
  ** is performed in-place mutating the list.
  **
  @NoDoc static Obj[] sortDis(Obj[] list, |Obj->Str|? getDis := null)
  {
    try
    {
      if (getDis == null)
        list.sort |a, b| { compareDis(a, b) }
      else
        list.sort |a, b| { compareDis(getDis(a), getDis(b)) }
    }
    catch
    {
      if (getDis == null)
        list.sort
      else
        list.sort |a, b| { getDis(a) <=> getDis(b) }
    }
    return list
  }

  ** Compare two values for sorting in a table
  @NoDoc static Int sortCompare(Obj? a, Obj? b)
  {
    if (a == null && b == null) return 0
    if (a == null) return -1
    if (b == null) return +1
    a = sortCompareNorm(a)
    b = sortCompareNorm(b)
    if (a is Str || b is Str || a.typeof != b.typeof)
      return a.toStr.localeCompare(b.toStr)
    else
      return a <=> b
  }

  private static Obj? sortCompareNorm(Obj? val)
  {
    if (val is Ref) return ((Ref)val).dis
    if (val is Number)
    {
      n := (Number)val
      if (n.isDuration) return n.toDuration.ticks.toFloat / 1hr.ticks.toFloat
      return n.toFloat
    }
    return val
  }

  **
  ** Process macro pattern with given scope of variable name/value pairs.
  ** The pattern is a Unicode string with embedded expressions:
  **  - '$tag': resolve tag name from scope, variable name ends
  **    with first non-tag character, see `Etc.isTagName`
  **  - '${tag}': resolve tag name from scope
  **  - '$<pod::key>': localization key
  **
  ** Any variables which cannot be resolved in the scope are
  ** returned as-is (such '$name') in the result string.
  **
  ** If a tag resolves to Ref, then we use Ref.dis for string.
  **
  static Str macro(Str pattern, Dict scope)
  {
    try
      return Macro(pattern, scope).apply
    catch (Err e)
      return pattern
  }

  **
  ** Return the list of variable tag names used in the given `macro`
  ** pattern.  This includes "$tag" and "${tag}" variables, but does
  ** not include "$<pod::key>" localization keys.
  **
  static Str[] macroVars(Str pattern)
  {
    try
      return Macro(pattern, Etc.emptyDict).vars
    catch (Err e)
      return Str#.emptyList
  }

  **
  ** Map display key to localized string
  **
  @NoDoc static Str disKey(Str key)
  {
    try
    {
      colons := key.index("::")
      return Pod.find(key[0..<colons]).locale(key[colons+2..-1], key)
    }
    catch (Err e) return key
  }

  ** Convert arbitary value to dispaly using Kind.valToDis
  @NoDoc static Str valToDis(Obj? val, Dict? meta := null, Bool clip := true)
  {
    if (val == null) return ""
    kind := Kind.fromVal(val, false)
    str := kind == null || kind === Kind.str ?
           val.toStr :
           kind.valToDis(val, meta ?: Etc.emptyDict)
    if (clip && str.size > 55 && kind !== Kind.ref) str = str[0..55] + "..."
    return str
  }

  ** Convert a timestamp in the past to localized age display string
  @NoDoc static Str tsToDis(DateTime? ts, DateTime now := DateTime.now)
  {
    if (ts == null) return ""

    // negative age, return full timestamp;
    // can add future support when needed
    age := now - ts
    if (age < 0ms) return ts.toLocale

    // if today
    isToday := ts.day == now.day && ts.month === now.month && ts.year == now.year
    if (isToday)
    {
      // just now
      if (age < 1min) return "$<justNow>"

      // use just time for today
      return ts.time.toLocale
    }

    // if older than several days
    if (age > 5day)
    {
      // if this year return "Sun 30 Apr" format,
      // or if last year then use "30 Apr 2019"
      if (ts.year == now.year)
        return ts.toLocale("WWW D MMM")
      else
        return ts.toLocale("D MMM YYYY")
    }

    // yesterday <time>
    days := (now.date - ts.date).toDay
    if (days == 1) return "$<yesterday> $ts.time.toLocale"

    // weekday (x days ago)
    else return "$ts.weekday.toLocale ($days $<daysAgo>)"
  }

//////////////////////////////////////////////////////////////////////////
// Names
//////////////////////////////////////////////////////////////////////////

  **
  ** Return if the given string is a legal kind name:
  **   - first char must be ASCII upper case
  **     letter: 'a' - 'z'
  **   - rest of chars must be ASCII letter or
  **     digit: 'a' - 'z', 'A' - 'Z', '0' - '9', or '_'
  **
  static Bool isKindName(Str n)
  {
    if (n.isEmpty || !n[0].isUpper) return false
    return n.all |c| { c.isAlphaNum || c == '_' }
  }

  **
  ** Return if the given string is a legal tag name:
  **   - first char must be ASCII lower case
  **     letter: 'a' - 'z'
  **   - rest of chars must be ASCII letter or
  **     digit: 'a' - 'z', 'A' - 'Z', '0' - '9', or '_'
  **
  static Bool isTagName(Str n)
  {
    if (n.isEmpty || !n[0].isLower) return false
    return n.all |c| { c.isAlphaNum || c == '_' }
  }

  **
  ** Take an arbitrary string and convert into a safe tag name.
  ** Do not assume any specific conversion algorithm as it might
  ** change in the future.  The empty string is not supported.
  **
  static Str toTagName(Str n)
  {
    // if already valid, just return it
    if (isTagName(n)) return n

    // empty string not supported
    if (n.isEmpty) throw ArgErr("string is empty")

    // handle leading caps which isn't handled by Str.fromDisplayName
    if (n.size >= 2 && n[0].isUpper && n[1].isUpper)
    {
      x := StrBuf()
      capsPrefix := true
      for (i := 0; i<n.size; ++i)
      {
        ch := n[i]
        if (capsPrefix && ch.isUpper) x.addChar(ch.lower)
        else { capsPrefix = false; x.addChar(ch) }
      }
      n = x.toStr
    }

    // use normal fromDisplayName
    n = n.fromDisplayName

    // strip invalid chars and make valid identifier
    buf := StrBuf()
    n.each |ch, i|
    {
      if (ch.isAlphaNum || ch == '_')
      {
        if (buf.isEmpty)
        {
          if (ch.isDigit || ch == '_') buf.addChar('v').addChar(ch)
          else if (ch.isUpper) buf.addChar(ch.lower)
          else buf.addChar(ch)
        }
        else buf.addChar(ch)
      }
      else if (ch == '.' || ch == '-' || ch == '/')
      {
        if (buf.isEmpty) buf.addChar('v')
        if (i < n.size - 1) buf.addChar('_')
      }
    }
    if (buf.isEmpty) return "v"
    return buf.toStr
  }

  **
  ** Get the localized string for the given tag name for the
  ** current locale. See `docSkySpark::Localization#tags`.
  **
  static Str tagToLocale(Str name)
  {
    pod := Pod.find("ui", false)
    if (pod != null) return pod.locale(name, name)
    return name
  }

  **
  ** Return if given name is/starts with prefix using camel
  ** case notation:
  **   nameStartsWith("foo", "foo")     // true
  **   nameStartsWith("foo", "fooBar")  // true
  **   nameStartsWith("foo", "fool")    // false
  **
  @NoDoc static Bool nameStartsWith(Str prefix, Str name)
  {
    if (prefix == name) return true
    return name.startsWith(prefix) && name[prefix.size].isUpper
  }

  ** File name is the valid characters in Uri.isName plus space.
  @NoDoc static Bool isFileName(Str name)
  {
    if (name.isEmpty) return false
    if (name[0] == ' ' || name[-1] == ' ') return false
    return name.all |ch| { isFileNameChar(ch) }
  }

  ** Convert to safe file name using characters safe in Uri name
  @NoDoc static Str toFileName(Str n)
  {
    s := StrBuf()
    n = n.trim
    n.each |ch| { s.addChar(isFileNameChar(ch) ? ch : '-') }
    if (s.isEmpty) s.add("x")
    return s.toStr
  }

  private static Bool isFileNameChar(Int ch)
  {
    ch.isAlphaNum || ch == ' '|| ch == '-' || ch == '.' || ch == '_' || ch == '~'
  }

//////////////////////////////////////////////////////////////////////////
// Axon
//////////////////////////////////////////////////////////////////////////

  ** Convert a scalar, list, or dict value to its Axon code representation
  @NoDoc static Obj? toAxon(Obj? val)
  {
    if (val == null) return "null"
    kind := Kind.fromVal(val, false)
    if (kind != null) return kind.valToAxon(val)
    if (val is DateSpan) return ((DateSpan)val).toCode
    return "xstr($val.typeof.name.toCode, $val.toStr.toCode)"
  }

//////////////////////////////////////////////////////////////////////////
// DiscretePeriods
//////////////////////////////////////////////////////////////////////////

  **
  ** Iterate a [discrete period]`discretePeriods()` string formatted in base64.
  ** Call the iterator function for each period where 'time' is offset in minutes
  ** from base timestamp and 'dur' is duration of period in minutes (assuming
  ** a minutely interval).  This method may also be used `discreteEnumPeriods()`
  ** in which case the 'dur' parameter will be the enum ordinal.
  **
  static Void discretePeriods(Str str, |Int time, Int dur| f)
  {
    for (i := 0; i<str.size; i += 4)
    {
      time := fromBase64[str[i+0]].shiftl(6) + fromBase64[str[i+1]]
      dur  := fromBase64[str[i+2]].shiftl(6) + fromBase64[str[i+3]]
      f(time, dur)
    }
  }

  // base64 to/from tables
  @NoDoc static const Str toBase64 := "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
  @NoDoc static const Int[] fromBase64
  static
  {
    list := Int[,].fill(0, 128)
    toBase64.each |ch, i| { list[ch] = i }
    fromBase64 = list
  }

  **
  ** Return periods as human readable time/duration or time/enum pairs using
  ** current locale.  If the rec passed has an `enum` tag then we interpret
  ** the periods as enum values, otherwise binary on duration values.  If there are
  ** more than max pairs then show only max and add "...". This method assumes
  ** the all time offsets are minutes after given start time, unless the rec passed
  ** has the 'discreteInterval' tag in which case then it is used to determine
  ** the time/duration pairs.
  **
  @NoDoc static Str discretePeriodsDis(Dict rec, DateTime start, Str periods, Int max := 5)
  {
    // check if enum
    Str[]? enums := null
    if (rec.has("enum") && rec["kind"] == "Str")
    {
      try
        enums = rec->enum.toStr.split(',')
      catch (Err e) {}
    }

    interval := 1min
    try
      if (rec.has("discreteInterval")) interval = ((Number)rec->discreteInterval).toDuration
    catch (Err e)
      e.trace

    // iterate time / dur|enum pairs
    s := StrBuf()
    count := 0
    discretePeriods(periods) |t, d|
    {
      ts := start + (interval * t)
      if (count < max)
      {
        if (count > 0) s.add(", ")
        val := enums == null ?
               periodDurToDis(interval * d) :
               (enums.getSafe(d) ?: d.toStr)
        s.add(ts.time.toLocale).addChar(' ').add(val)
      }
      else if (count == max) s.add(" ...")
      count++
    }
    return s.toStr
  }

  private static Str periodDurToDis(Duration d)
  {
    min := d.toMin
    if (min % 60 == 0 && min > 0) return "${min/60}hr"
    return "${min}min"
  }

//////////////////////////////////////////////////////////////////////////
// Grids
//////////////////////////////////////////////////////////////////////////

  **
  ** Default empty grid instance
  **
  @NoDoc static Grid emptyGrid()
  {
    g := emptyGridRef.val
    if (g == null) emptyGridRef.val = g = GridBuilder().addCol("empty").toGrid
    return g
  }
  private static const AtomicRef emptyGridRef := AtomicRef(null)

  **
  ** Return first cell as string or the default value.
  **
  @NoDoc static Str? gridToStrVal(Grid? grid, Str? def := "")
  {
    row := grid?.first
    if (row == null) return def
    col := grid.cols.first
    return row.val(col) as Str ?: def
  }

  **
  ** Construct an empty grid with just the given grid level meta-data.
  ** The meta parameter can be any `makeDict` value.
  **
  static Grid makeEmptyGrid(Obj? meta := null)
  {
    m := makeDict(meta)
    if (m.isEmpty) return emptyGrid
    return GridBuilder().setMeta(m).addCol("empty").toGrid
  }

  **
  ** Construct a grid for an error response.
  **
  static Grid makeErrGrid(Err e, Obj? meta := null)
  {
    tags := toErrMeta(e)
    tags = dictMerge(tags, meta)
    return makeEmptyGrid(tags)
  }

  **
  ** Map an exception to its standard tags:
  **   - 'dis': error display string
  **   - 'err': marker
  **   - 'errTrace': Str stack dump
  **   - 'axonTrace': Axon stack dump (if applicable)
  **   - 'errType': exception type qname
  **
  static Dict toErrMeta(Err e)
  {
    // core tags
    acc := [
      "err": Marker.val,
      "dis": e.toStr,
      "errTrace": toErrTrace(e),
      "errType": e.typeof.qname
    ]

    // ThrowErr.tags
    field := e.typeof.field("tags", false)
    if (field != null)
    {
      tags := field.get(e) as Dict
      if (tags != null) tags.each |v, n| { if (acc[n] == null) acc[n] = v }
    }

    return makeDict(acc)
  }

  **
  ** Get standardized error trace taking into account
  ** axon and remote call stack traces
  **
  @NoDoc static Str toErrTrace(Err e)
  {
    trace := e.traceToStr
    axonTrace := toAuxTrace(e, "axonTrace")
    remoteTrace := toAuxTrace(e, "remoteTrace")
    if (axonTrace != null || remoteTrace != null)
    {
      s := StrBuf()
      s.add("$e.toStr").add("\n")
      if (axonTrace != null) s.add("=== Axon Trace ===\n").add(axonTrace).add("\n")
      if (remoteTrace != null) s.add("=== Remote Trace ===\n").add(remoteTrace).add("\n")
      s.add("=== Fantom Trace ===\n").add(trace)
      trace = s.toStr
    }
    return trace
  }

  private static Str? toAuxTrace(Err? e, Str fieldName)
  {
    while (e != null)
    {
      field := e.typeof.field(fieldName, false)
      if (field != null)
      {
        s := field.get(e) as Str
        if (s == null || s.isEmpty) return null
        return s
      }
      e = e.cause
    }
    return null
  }

  **
  ** Convenience for `makeDictGrid`
  **
  static Grid makeMapGrid(Obj? meta, Str:Obj? row)
  {
    makeDictGrid(meta, makeDict(row))
  }

  **
  ** Convenience for `makeDictsGrid`
  **
  static Grid makeMapsGrid(Obj? meta, [Str:Obj?][] rows)
  {
    makeDictsGrid(meta, makeDicts(rows))
  }

  **
  ** Construct a grid for a Dict row.
  ** The meta parameter can be any `makeDict` value.
  **
  static Grid makeDictGrid(Obj? meta, Dict row)
  {
    if (row.isEmpty) return makeEmptyGrid(meta)
    gb := GridBuilder()
    gb.setMeta(meta)
    cells := Obj?[,]
    if (row.has("id")) { gb.addCol("id"); cells.add(row["id"]) }
    row.each |v, n|
    {
      if (n == "id" || n == "mod") return
      gb.addCol(n)
      cells.add(v)
    }
    if (row.has("mod")) { gb.addCol("mod"); cells.add(row["mod"]) }
    gb.addRow(cells)
    return gb.toGrid
  }

  **
  ** Construct a grid for a list of Dict rows.  The meta parameter
  ** can be any `makeDict` value.  Any null dicts result in an empty
  ** row of all nulls.  If no non-null rows, then return `makeEmptyGrid`.
  **
  static Grid makeDictsGrid(Obj? meta, Dict?[] rows)
  {
    // boundary cases
    if (rows.isEmpty) return makeEmptyGrid(meta)
    if (rows.size == 1 && rows[0] != null) return makeDictGrid(meta, rows.first)

    // first pass finds all the unique columns
    colNames := dictsNames(rows)
    if (colNames.isEmpty) return makeEmptyGrid(meta)

    // build into grid
    gb := GridBuilder()
    gb.setMeta(meta)
    colNames.each |colName| { gb.addCol(colName) }
    gb.addDictRows(rows)
    return gb.toGrid
  }

  **
  ** Construct a grid with one column for a list.  The meta
  ** and colMeta parameters can be any `makeDict` value.
  **
  static Grid makeListGrid(Obj? meta, Str colName, Obj? colMeta, Obj?[] rows)
  {
    gb := GridBuilder()
    gb.setMeta(meta)
    gb.addCol(colName, colMeta)
    rows.each |row| { gb.addRow1(row) }
    return gb.toGrid
  }

  **
  ** Construct a grid for a list of rows, where each row is
  ** a list of cells.  The meta and colMetas parameters can
  ** be any `makeDict` value.
  **
  static Grid makeListsGrid(Obj? meta, Str[] colNames, Obj?[]? colMetas, Obj?[][] rows)
  {
    gb := GridBuilder()
    gb.setMeta(meta)
    colNames.each |colName, i| { gb.addCol(colName, colMetas?.get(i)) }
    rows.each |row| { gb.addRow(row) }
    return gb.toGrid
  }

  **
  ** Flatten a list of grids into a single grid.  Each grid's rows are
  ** appended to a single grid in the order passed.  The resulting grid
  ** columns will be the intersection of all the individual grid columns.
  ** Grid meta and column merged together.
  **
  static Grid gridFlatten(Grid[] grids)
  {
    if (grids.isEmpty) return emptyGrid
    if (grids.size == 1) return grids[0]

    meta := Etc.emptyDict
    cols := Str:Dict[:] { ordered = true }
    grids.each |g|
    {
      meta = dictMerge(g.meta, meta)
      g.cols.each |c| { cols[c.name] = dictMerge(c.meta, cols[c.name]) }
    }

    gb := GridBuilder()
    gb.setMeta(meta)
    cols.each |colMeta, colName| { gb.addCol(colName, colMeta) }
    grids.each |g|
    {
      g.each |row| { gb.addDictRow(row) }
    }
    return gb.toGrid
  }

//////////////////////////////////////////////////////////////////////////
// Coercion
//////////////////////////////////////////////////////////////////////////

  **
  ** Coerce a value to a Ref identifier:
  **   - Ref returns itself
  **   - Row or Dict, return 'id' tag
  **   - Grid return first row id
  **
  static Ref toId(Obj? val)
  {
    if (val is Ref) return val
    if (val is Dict) return ((Dict)val).id
    if (val is Grid) return ((Grid)val).first?.id ?: throw CoerceErr("Grid is empty")
    throw CoerceErr("Cannot coerce to id: ${val?.typeof}")
  }

  **
  ** Coerce a value to a list of Ref identifiers:
  **   - Ref returns itself as list of one
  **   - Ref[] returns itself
  **   - Dict return 'id' tag
  **   - Dict[] return 'id' tags
  **   - Grid return 'id' column
  **
  static Ref[] toIds(Obj? val)
  {
    if (val is Ref) return Ref[val]
    if (val is Dict) return Ref[((Dict)val).id]
    if (val is List)
    {
      list := (List)val
      if (list.isEmpty) return Ref[,]
      if (list.of.fits(Ref#)) return list
      if (list.all |x| { x is Ref }) return Ref[,].addAll(list)
      if (list.all |x| { x is Dict }) return list.map |Dict d->Ref| { d.id }
    }
    if (val is Grid)
    {
      grid := (Grid)val
      if (grid.isEmpty) return Ref[,]
      if (grid.meta.has("navFilter"))
        return Slot.findMethod("legacy::NavFuncs.toNavFilterRecIdList").call(grid)
      ids := Ref[,]
      idCol := grid.col("id")
      grid.each |row|
      {
        id := row.val(idCol) as Ref ?: throw CoerceErr("Row missing id tag")
        ids.add(id)
      }
      return ids
    }
    throw CoerceErr("Cannot convert to ids: ${val?.typeof}")
  }

  **
  ** Coerce a value to a record Dict:
  **   - Row or Dict returns itself
  **   - Grid returns first row (must have at least one row)
  **   - List returns first item (must have at least one item which is Ref or Dict)
  **   - Ref will make a call to read database (must be run in a context)
  **
  static Dict toRec(Obj? val, HaystackContext? cx := null)
  {
    if (val is Dict) return val
    if (val is Grid) return ((Grid)val).first ?: throw CoerceErr("Grid is empty")
    if (val is List) return toRec(((List)val).first ?: throw CoerceErr("List is empty"))
    if (val is Ref)  return refToRec(val, cx)
    throw CoerceErr("Cannot coerce toRec: ${val?.typeof}")
  }

  **
  ** Coerce a value to a list of record Dicts:
  **   - null return empty list
  **   - Ref or Ref[] will read database (must be run in a context)
  **   - Row or Row[] returns itself
  **   - Dict or Dict[] returns itself
  **   - Grid is mapped to list of rows
  **
  static Dict[] toRecs(Obj? val, HaystackContext? cx := null)
  {
    if (val == null) return Dict[,]

    if (val is Dict) return Dict[val]

    if (val is Ref) return Dict[refToRec(val, cx)]

    if (val is Grid)
    {
      grid := (Grid)val
      if (grid.meta.has("navFilter"))
        return Slot.findMethod("legacy::NavFuncs.toNavFilterRecList").call(grid)
      return grid.toRows
    }

    if (val is List)
    {
      list := (List)val
      if (list.isEmpty) return Dict[,]
      if (list.of.fits(Dict#)) return list
      if (list.all |x| { x is Dict }) return Dict[,].addAll(list)
      if (list.all |x| { x is Ref }) return refsToRecs(list, cx)
      throw CoerceErr("Cannot convert toRecs: List of ${list.first?.typeof}")
    }

    throw CoerceErr("Cannot coerce toRecs: ${val?.typeof}")
  }

  ** Coerce a ref to a rec dict
  private static Dict refToRec(Ref id, HaystackContext? cx)
  {
    cx = curContext(cx)
    return cx.deref(id) ?: throw UnknownRecErr("Cannot read id: $id.toCode")
  }

  ** Coerce a list of refs to a list of recs dict
  private static Dict[] refsToRecs(Ref[] ids, HaystackContext? cx)
  {
    cx = curContext(cx)
    return ids.map |id->Dict| { cx.deref(id) ?: throw UnknownRecErr("Cannot read id: $id.toCode") }
  }

  **
  ** Coerce a value to a Grid:
  **   - if grid just return it
  **   - if row in grid of size, return row.grid
  **   - if scalar return 1x1 grid
  **   - if dict return grid where dict is only
  **   - if list of dict return grid where each dict is row
  **   - if list of non-dicts, return one col grid with rows for each item
  **   - if non-zinc type return grid with cols val, type
  **
  static Grid toGrid(Obj? val, Dict? meta := null)
  {
    // if already a Grid
    if (val is Grid) return (Grid)val

    // if a Row in a single row Grid
    if (val is Row)
    {
      grid := ((Row)val).grid
      try
        if (grid.size == 1) return grid
      catch {}
    }

    // if value is a Dict map to a 1 row grid
    if (val is Dict) return makeDictGrid(meta, val)

    // if value is a list
    if (val is List)
    {
      // if list is all dicts, turn into real NxN grid
      list := (List)val
      if (list.all { it is Dict }) return makeDictsGrid(meta, val)

      // otherwise just turn it into a 1 column grid
      gb := GridBuilder().addCol("val")
      list.each |v| { gb.addRow1(toCell(v)) }
      return gb.toGrid
    }

    // scalar translate to 1x1 Grid
    return GridBuilder().setMeta(meta).addCol("val").addRow1(toCell(val)).toGrid
  }

  **
  ** Get value as a grid cell
  **
  @NoDoc static Obj? toCell(Obj? val)
  {
    if (val is Grid) return ((Grid)val).toConst
    if (val == null) return null
    if (Kind.fromVal(val, false) != null) return val
    return XStr.encode(val)
  }

  **
  ** Coerce an object to a DateSpan:
  **   - 'Func': function which evaluates to date range (must be run in a context)
  **   - 'DateSpan': return itself
  **   - 'Date': one day range
  **   - 'Span': return `haystack::Span.toDateSpan`
  **   - 'Str': evaluates to `haystack::DateSpan.fromStr`
  **   - 'Date..Date': starting and ending date (inclusive)
  **   - 'Date..Number': starting date and num of days (day unit required)
  **   - 'DateTime..DateTime': use starting/ending dates; if end is midnight,
  **     then use previous date
  **   - 'Number': convert as year
  **
  static DateSpan toDateSpan(Obj? val, HaystackContext? cx := null)
  {
    if (val is HaystackFunc) val = ((HaystackFunc)val).haystackCall(curContext(cx), Obj#.emptyList)
    if (val is DateSpan) return val
    if (val is Date) return DateSpan(val, DateSpan.day)
    if (val is Span) return ((Span)val).toDateSpan
    if (val is Str) return DateSpan.fromStr(val)
    if (val is ObjRange)
    {
      or := (ObjRange)val
      s := or.start
      e := or.end
      if (s is Date) return DateSpan.make(s, e)
      if (s is DateTime && e is DateTime)
      {
        st := (DateTime)s; sd := st.date
        et := (DateTime)e; ed := et.date
        if (et.isMidnight) ed = ed - 1day
        return DateSpan(sd, ed)
      }
    }
    if (val is Number)
    {
      year := ((Number)val).toInt
      if (1900 < year && year < 2100) return DateSpan.makeYear(year)
    }
    throw CoerceErr("Cannot coerce toDateSpan: $val [${val?.typeof}]")
  }

  **
  ** Coerce an object to a `Span` with optional timezone:
  **   - 'Span': return itself
  **   - 'Span+tz': update timezone using same dates only if aligned to midnight
  **   - 'Str': return `haystack::Span.fromStr` using current timezone
  **   - 'Str+tz': return `haystack::Span.fromStr` using given timezone
  **   - 'DateTime..DateTime': range of two DateTimes
  **   - 'Date..DateTime': start day for date until the end timestamp
  **   - 'DateTime..Date': start timestamp to end of day for end date
  **   - 'DateTime': span of a single timestamp
  **   - 'DateSpan': anything accepted by `toDateSpan` in current timezone
  **   - 'DateSpan+tz': anything accepted by `toDateSpan` using given timezone
  **
  static Span toSpan(Obj? val, TimeZone? tz := null, HaystackContext? cx := null)
  {
    if (val is Span)
    {
      span := (Span)val
      if (tz != null && span.alignsToDates) return span.toDateSpan.toSpan(tz)
      return span
    }
    if (val is Str)
    {
      return Span.fromStr(val, tz ?: TimeZone.cur)
    }
    if (val is ObjRange)
    {
      r := (ObjRange)val
      s := r.start as DateTime
      e := r.end as DateTime
      if (s != null || e != null)
      {
        if (s == null && r.start is Date) s = ((Date)r.start).midnight(e.tz)
        if (e == null && r.end is Date)   e = ((Date)r.end + 1day).midnight(s.tz)
        if (s != null && e != null) return toSpan(Span(s, e), tz)
      }
    }
    if (val is DateTime)
    {
      ts := (DateTime)val
      return Span(ts, ts)
    }
    return toDateSpan(val, cx).toSpan(tz ?: TimeZone.cur)
  }

  ** If explicit context not passed then resolve from actor local
  private static HaystackContext curContext(HaystackContext? cx)
  {
    if (cx == null) cx = Actor.locals[cxActorLocalsKey] as HaystackContext
    if (cx == null) throw Err("No context available")
    return cx
  }

//////////////////////////////////////////////////////////////////////////
// Debug
//////////////////////////////////////////////////////////////////////////

  ** Nullable Duration or Int ticks to debug string:
  **   - null or zero: "never"
  **   - positive is ticks in future: "3min"
  **   - negative is ticks in past: "3min ago"
  **   - over 3hr ago: "4hr ago [22:14 2014-09-05 EDT]"
  @NoDoc static Str debugDur(Obj? dur)
  {
    if (dur == null || dur == 0) return "never"
    d := dur as Duration ?: Duration((Int)dur)
    now := Duration.now
    if (now < d) return (d - Duration.now).toLocale
    ago := now - d
    if (ago < 3hr) return "$ago.toLocale ago"
    ts := (DateTime.now - d).toLocale("hh:mm:ss DD-MMM-YYYY zzz")
    return "$ago.toLocale ago [$ts]"
  }

  ** Format error trace with two char indention.
  @NoDoc static Str debugErr(Err? err, Str flags := "x<>")
  {
    if (err == null) return "null"
    return indent(toErrTrace(err), 2, flags)
  }

  ** Indent every line of the given string.  Flags:
  **   - 'x': strip empty lines
  **   - '<': add leading leading newline
  **   - '>': add trailing newline
  @NoDoc static Str indent(Str str, Int indent := 2, Str flags := ">")
  {
    s := StrBuf()
    if (flags.contains("<")) s.add("\n")
    str.splitLines.each |line|
    {
      if (line.isEmpty && flags.contains("x")) return
      s.add(Str.spaces(indent)).add(line).addChar('\n')
    }
    if (!flags.contains(">") && s.size > 0) s.remove(-1)
    return s.toStr
  }

  ** Format actor msg tuple as "type(id, a=a, b=b, ...)"
  @NoDoc static Str debugMsg(Str type, Obj? id, Obj? a, Obj? b := null, Obj? c := null, Obj? d := null, Obj? e := null)
  {
    s := StrBuf()
    s.add(type).add("(").add(id)
    debugMsgArg(s, "a", a)
    debugMsgArg(s, "b", b)
    debugMsgArg(s, "c", c)
    debugMsgArg(s, "d", d)
    debugMsgArg(s, "e", e)
    return s.add(")").toStr
  }

  private static Void debugMsgArg(StrBuf b, Str name, Obj? arg)
  {
    if (arg == null) return
    b.addChar(' ').add(name).addChar('=')
    try
    {
      s := arg.toStr
      if (s.size <= 64) b.add(s)
      else b.add(s[0..64]).add("...")
    }
    catch (Err e) b.add(e.toStr)
  }

  static Void addArg(StrBuf b, Str name, Obj? arg)
  {
    if (arg == null) return
    b.addChar(' ').add(name).addChar('=')
    try
    {
      s := arg.toStr
      if (s.size <= 64) b.add(s)
      else b.add(s[0..64]).add("...")
    }
    catch (Err e) b.add(e.toStr)
  }

  ** Given command line args, turn into a map:
  **   -foo -bar baz         // input
  **   [foo:true, bar:baz]   // output
  @NoDoc static Str:Str toCliArgsMap(Str[] args)
  {
    acc := Str:Str[:]
    args.each |s, i|
    {
      if (!s.startsWith("-") || s.size < 2) return
      name := s[1..-1]
      val  := "true"
      if (i+1 < args.size && !args[i+1].startsWith("-"))
        val = args[i+1]
     acc[name] = val
    }
    return acc
  }

  ** Format long a long string as a series of lines
  @NoDoc static Str[] formatMultiLine(Str str, Int lineLength := 60)
  {
    lines := Str[,]
    while (!str.isEmpty)
    {
      x := lineLength.min(str.size)
      lines.add(str[0..<x])
      str = str[x..-1]
    }
    return lines
  }

//////////////////////////////////////////////////////////////////////////
// Misc
//////////////////////////////////////////////////////////////////////////

  ** Timestamp format to match build.tsKey
  @NoDoc static const Str tsKeyFormat := "YYMMDDhhmmss"

  ** Actor.locals key for AxonContext, FolioContext, and Context
  @NoDoc const static Str cxActorLocalsKey := "cx"

}