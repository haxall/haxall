//
// Copyright (c) 2026, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   27 Jun 2025  Brian Frank  Back from Laguna
//

using xeto

**
** Text wraps a string for display with localization macro support.
** ```
** Localization "$<key>"       // for keys in "pi" pod itself
** Localization "$<pod::key>"  // for keys in other pods
** ```
**
@Js @Gen
const mixin Text
{
  ** Same as [empty]
  static Text defVal() { empty }

  ** Empty string
  static const Text empty := MText.make("")

  ** Create from string value
  static new fromStr(Str s) { MText.fromStr(s) }

  ** Coerce from any value:
  ** - Null returns empty string
  ** - Text returns itself
  ** - Str returns [fromStr]
  ** - Dict returns [fromDict]
  ** - Return [haystack::Etc.valToDis]
  static Text fromData(Obj? val, Dict? meta := null)
  {
    if (val == null || val == "") return defVal
    if (val is Str) return fromStr(val)
    if (val is Text) return (Text)val
    if (val is Dict) return fromDict(val)
    return fromStr(XetoEnv.cur.valToDis(val, meta))
  }

  ** Map text from record or meta dict:
  **   - look for text tag, only use it if not empty
  **   - fallback to def if provided
  **   - fallback to Dict.dis
  static Text? fromDict(Dict dict, Str? def := null)
  {
    x := dict["text"]
    if (x != null && !x.toStr.isEmpty) return fromData(x)
    return Text(def ?: dict.dis)
  }

  ** Convenience for fromDictTag with "title"
  @NoDoc static Text? dictToTitle(Dict dict, Str? def)
  {
    fromDictTag(dict, "title", def)
  }

  ** Convenience for fromDictTag with "subtitle"
  @NoDoc static Text? dictToSubtitle(Dict dict, Str? def)
  {
    fromDictTag(dict, "subtitle", def)
  }

  ** Map text from dict using tag name:
  **   - look for text tag, only use it if not empty
  **   - fallback dis if not null
  **   - return null
  @NoDoc static Text? fromDictTag(Dict dict, Str name, Str? def := null)
  {
    x := dict[name]
    if (x != null && !x.toStr.isEmpty) return fromData(x)
    if (def != null) return Text(def)
    return null
  }

  ** Text to display
  abstract Str dis()

  ** Text pattern
  abstract Str pattern()

  ** Return pattern (not dis)
  override final Str toStr() { pattern }

  ** Is this the blank / empty string
  Bool isBlank() { pattern.isEmpty }

  ** Trim display text to null
  @NoDoc Str? trimToNull() { dis.trimToNull }

  ** Return if this a match string segements
  @NoDoc virtual Bool isMatch() { false }

  ** If this a string to highlight specific chars for a auto-complete match
  ** then return segments where odd indices are are matching segments.  If
  ** the first char(s) is a match, then the first segment will be an empty
  ** string.  Raise exception if isMatch returns false.
  @NoDoc virtual Str[] matchSegments() { throw UnsupportedErr() }

}

**************************************************************************
** MText
**************************************************************************

**
** Text implementation
**
@NoDoc @Js
final const class MText : Text
{
  static new fromStr(Str s)
  {
    if (s.isEmpty) return defVal
    return make(s)
  }

  internal new make(Str pattern)
  {
    this.pattern    = pattern
    this.macroIndex = findMacroStart(pattern, 0) ?: -1
  }

  override const Str pattern

  const Int macroIndex

  Bool isMacro() { macroIndex >= 0 }

  override Int hash() { pattern.hash }

  override Bool equals(Obj? that)
  {
    a := this
    b := that as MText
    if (b == null) return false
    return a.pattern == b.pattern
  }

  override Str dis()
  {
    isMacro ? eval : pattern
  }

  private Str eval()
  {
    // lookup s)tart $< and e) >
    Int? s := macroIndex
    e := findMacroEnd(pattern, s)
    if (e == null) return pattern

    // handle common case where whole pattern is the key
    if (s == 0 && e == pattern.size-1) return locale(pattern[s+2..<e])

    // complex macro
    buf := StrBuf()
    buf.add(pattern[0..<s])
    while (true)
    {
      buf.add(locale(pattern[s+2..<e]))
      news := findMacroStart(pattern, e+1)
      newe := findMacroEnd(pattern, news)
      if (news == null || newe == null) break
      buf.add(pattern[e+1..<news])
      s = news; e = newe;
    }
    buf.add(pattern[e+1..-1])
    return buf.toStr
  }

  private static Str locale(Str key)
  {
    colons := key.index("::")
    if (colons == null) return Text#.pod.locale(key, key)

    pod  := key[0..<colons]
    name := key[colons+2..-1]
    return Pod.find(pod, false)?.locale(name, null) ?: key
  }

  static Int? findMacroStart(Str pattern, Int start)
  {
    i := pattern.index("\$<", start)
    if (i == null) return null
    if (i > 0 && pattern[i-1] == '\\') return findMacroStart(pattern, i+2)
    return i
  }

  static Int? findMacroEnd(Str pattern, Int? start)
  {
    if (start == null) return null
    return pattern.index(">", start+2)
  }
}

**************************************************************************
** MatchText
**************************************************************************

**
** String of text styled to highlight specific chars for a match.
** The text is modeled as list of segments where odd indices are
** are matching segments.  If the first char(s) is a match, then
** the first segment will be an empty string.
**
@NoDoc @Js
const class MatchText : Text
{
  new make(Str[] segs) { matchSegments = segs }

  override Str pattern() { matchSegments.join("_") }

  override Str dis() { pattern }

  override Bool isMatch() { true }

  const override Str[] matchSegments

  override Int hash() { matchSegments.hash }

  override Bool equals(Obj? that)
  {
    a := this
    b := that as MatchText
    if (b == null) return false
    return a.matchSegments == b.matchSegments
  }
}

