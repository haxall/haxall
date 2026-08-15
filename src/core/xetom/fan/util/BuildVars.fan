//
// Copyright (c) 2026, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   15 Aug 2026  Brian Frank  Creation
//

using util
using xeto

**
** BuildVars models the "build.props" build variables of a source
** environment.  It is the choke point for reading that file and for
** the rules which apply to it: user variables are prefixed by lib name
** and substituted into source via `sys::BuildVar`, while names prefixed
** by "xeto." and "sys." are reserved to configure the compiler itself.
**
** Reserved names are never packaged into a xetolib and are never visible
** to `vars`, so a build variable and a build setting cannot be confused
** for one another.
**
@Js
const class BuildVars
{

//////////////////////////////////////////////////////////////////////////
// Construction
//////////////////////////////////////////////////////////////////////////

  ** Empty build vars
  static const BuildVars empty := make(Str:Str[:])

  ** Read build vars from a "build.props" file; returns `empty` if the
  ** file does not exist or cannot be parsed
  static BuildVars read(File file)
  {
    if (!file.exists) return empty
    try
      return make(file.readProps)
    catch (Err e)
      { Console.cur.err("ERROR: cannot parse $file", e); return empty }
  }

  ** Read build vars inherited across an environment path.  Each path dir
  ** may define "src/xeto/build.props" and entries earlier in the path
  ** override those later in the path.
  static BuildVars load(File[] path)
  {
    acc := Str:Str[:]
    acc.ordered = true
    path.eachr |dir| { acc.setAll(read(dir + propsFileName).props) }
    return make(acc)
  }

  ** From an already parsed props map
  new make(Str:Str props)
  {
    this.props = props.toImmutable
    this.srcExclude = parseSrcExclude(props)
  }

  ** Path of the build vars file relative to an environment dir
  const static Uri propsFileName := `src/xeto/build.props`

//////////////////////////////////////////////////////////////////////////
// Access
//////////////////////////////////////////////////////////////////////////

  ** All names to values including reserved names
  const Str:Str props

  ** Is this the empty build vars
  Bool isEmpty() { props.isEmpty }

  ** Lookup a build variable value by name or null if undefined.  Reserved
  ** names are included; use `vars` for just the user variables.
  Str? get(Str name) { props.get(name) }

  ** User variables available for `sys::BuildVar` substitution; this
  ** excludes the reserved names which configure the build itself
  once Str:Str vars()
  {
    props.findAll |v, n| { !isReserved(n) }.toImmutable
  }

  ** Debug string
  override Str toStr() { props.toStr }

//////////////////////////////////////////////////////////////////////////
// Reserved Names
//////////////////////////////////////////////////////////////////////////

  ** Is the given name reserved to configure the build itself.  We reserve
  ** both prefixes even though only "sys" is a lib name; user variables use
  ** their own lib prefix.
  static Bool isReserved(Str name)
  {
    name.startsWith("xeto.") || name.startsWith("sys.")
  }

  ** Build var which excludes source directories from the packaged lib
  const static Str srcExcludeVar := "xeto.srcExclude"

//////////////////////////////////////////////////////////////////////////
// srcExclude
//////////////////////////////////////////////////////////////////////////

  ** Lib root directory names to exclude from the lib source walk; see
  ** `LibSrcFiles`.  Empty if `srcExcludeVar` is undefined.
  const Str[] srcExclude

  ** Parse `srcExcludeVar` into lib root dir names.  Value is a semicolon
  ** separated list where every entry must end with "/".  Bad entries are
  ** logged and skipped rather than raised: this is parsed while booting
  ** sys from source, where a compiler error yields a confusing NullErr
  ** instead of our message.  The exclude simply does not happen, so the
  ** build still fails loudly downstream if the dir cannot be packaged.
  private static Str[] parseSrcExclude(Str:Str props)
  {
    s := props[srcExcludeVar]?.trim
    if (s == null || s.isEmpty) return Str#.emptyList

    acc := Str[,]
    s.split(';').each |entry|
    {
      if (entry.isEmpty) return
      if (!entry.endsWith("/")) return srcExcludeErr(entry, "must end with '/'")
      name := entry[0..-2]
      if (name.isEmpty || name.contains("/")) return srcExcludeErr(entry, "must be a lib root dir name")
      acc.add(name)
    }
    return acc.toImmutable
  }

  private static Void srcExcludeErr(Str entry, Str msg)
  {
    Console.cur.err("ERROR: invalid $srcExcludeVar entry '$entry': $msg")
  }

}

