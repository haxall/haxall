//
// Copyright (c) 2026, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   16 Aug 2026  Brian Frank  Creation
//

**
** LibFilePattern is a path used to select files from a lib's source
** directory.  A pattern takes one of three forms:
**
**   - Directory: "/img" or "/res/icons" matches every file in that
**     directory's subtree (recursive)
**   - File: "/logo.svg" or "/res/logo.svg" matches exactly one file
**   - Extension: "/*.svg" or "/res/*.svg" matches files with that
**     extension directly in the named directory (non-recursive)
**
** Patterns are written the same way a lib file is addressed: rooted at
** the lib with a leading slash, so "/res/logo.svg" is both the pattern
** and the uri it selects.  The "*" wildcard may appear only as the whole
** final section in the form "*.ext".  A pattern has no trailing slash,
** no "..", and no backslashes.  Whether a plain pattern names a directory
** or file is resolved against the actual source tree when the pattern is
** applied; a pattern that matches nothing is an error.
**
@Js @NoDoc
const class LibFilePattern
{
  ** Parse from string, or raise ParseErr/return null if malformed
  static new fromStr(Str s, Bool checked := true)
  {
    err := patternErr(s)
    if (err == null) return makePattern(s)
    if (checked) throw ParseErr("Invalid lib file pattern '$s': $err")
    return null
  }

  ** If the given string is not a valid pattern return an error message,
  ** otherwise return null.  See the class doc for the three forms.
  static Str? patternErr(Str s)
  {
    if (s.isEmpty) return "pattern cannot be the empty string"
    if (!s.startsWith("/")) return "pattern must start with '/'"
    if (s.size == 1) return "pattern cannot be just '/'"
    if (s.endsWith("/")) return "pattern cannot end with '/'"
    if (s.contains("\\")) return "pattern cannot contain '\\'"

    // the leading slash roots the pattern, so the first split is empty
    segs := s[1..-1].split('/')
    for (i := 0; i < segs.size; ++i)
    {
      seg := segs[i]
      last := i == segs.size - 1
      if (seg.isEmpty) return "pattern cannot contain an empty path section"
      if (seg == "..") return "pattern cannot contain '..'"

      // the wildcard is only allowed to lead the final section as "*.ext"
      star := seg.index("*")
      if (star == null) continue
      if (!last) return "wildcard is only allowed in the final path section"
      if (star != 0 || !seg.startsWith("*.") || seg.size < 3)
        return "wildcard must be the whole final section as '*.ext'"
      if (seg[2..-1].contains("*")) return "pattern cannot contain more than one wildcard"
    }
    return null
  }

  ** Return if the given string is a valid pattern
  static Bool isPattern(Str s) { patternErr(s) == null }

  ** Decode the given lib meta tag into its patterns, empty if undefined.
  ** The scalar binding has already decoded each item, so this is just a
  ** typed view of the meta list.
  static LibFilePattern[] listFromMeta(Dict meta, Str tag)
  {
    list := meta.get(tag) as List
    if (list == null) return LibFilePattern#.emptyList
    return LibFilePattern[,].addAll(list)
  }

  private new makePattern(Str s)
  {
    this.pattern = s
    star := s.index("*")
    if (star == null)
    {
      this.subtree = s + "/"
    }
    else
    {
      this.dotExt = s[star+1..-1]
      this.dir    = dirOf(s)
    }
  }

  ** The pattern as authored
  const Str pattern

  ** Suffix which matches the subtree of a directory pattern, else null
  private const Str? subtree

  ** ".ext" of the wildcard form matched against the path tail, else null
  private const Str? dotExt

  ** Directory the wildcard form selects within, else null
  private const Str? dir

  ** Does this pattern select the given lib relative uri.  The uri must be
  ** lib relative with a leading slash such as `/doc/index.md`, which is
  ** the form produced by `LibSrcFiles` and exposed by `Lib.files`.
  ** A pattern without a wildcard matches either the file of that exact
  ** path or every file under it, since which one it names is decided by
  ** the source tree rather than by the pattern.
  Bool matches(Uri uri)
  {
    path := uri.toStr
    if (!path.startsWith("/")) throw ArgErr("Uri must be lib relative with leading slash: $uri")

    // "/*.ext" and "/dir/*.ext" select by extension within exactly one
    // directory, so the path must sit directly in that directory
    if (dotExt != null) return path.endsWith(dotExt) && dirOf(path) == dir

    // without a wildcard the pattern is either the file itself or the
    // directory holding it
    return path == pattern || path.startsWith(subtree)
  }

  ** Everything through the last slash of a rooted path
  private static Str dirOf(Str path) { path[0..path.indexr("/")] }

  ** The pattern as authored
  override Str toStr() { pattern }

  ** Equality is by pattern string
  override Bool equals(Obj? that)
  {
    that is LibFilePattern && ((LibFilePattern)that).pattern == pattern
  }

  ** Hash of the pattern string
  override Int hash() { pattern.hash }
}

