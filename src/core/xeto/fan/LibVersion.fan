//
// Copyright (c) 2024, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   4 Apr 2024  Brian Frank  Creation
//

**
** Xeto library name, version, and dependencies
**
@Js
const mixin LibVersion
{
  ** Library dotted name
  abstract Str name()

  ** Library version
  abstract Version version()

  ** Dependencies of this library
  abstract LibDepend[] depends()

  ** Summary information or empty string if not available
  abstract Str doc()

  ** Sort by name, then version
  override final Int compare(Obj that)
  {
    a := this
    b := (LibVersion)that
    cmp := a.name <=> b.name; if (cmp != 0) return cmp
    return a.version <=> b.version
  }

  ** File used to load this lib if backed by the file system.  If we are
  ** using the source then return the source directory, otherwise return
  ** the xetolib zip file found in "lib/xeto".  If the version is not backed
  ** by a file then raise exception or return null based on checked flag.
  @NoDoc abstract File? file(Bool checked := true)

  ** Does the file represent a source directory under "src/xeto"
  @NoDoc abstract Bool isSrc()

  ** Order a list of versions by their dependencies.  Raise exception if
  ** the given list does not satisify all the internal dependencies or
  ** has circular dependencies.
  static LibVersion[] orderByDepends(LibVersion[] libs)
  {
    // check internal version constraints
    byName := Str:LibVersion[:]
    libs.each |x| { byName.add(x.name, x) }
    libs.each |x|
    {
      x.depends.each |d|
      {
        m := byName[d.name]
        if (m == null || !d.versions.contains(m.version))
          throw makeDependErr("$x dependency: $d [$m]")
      }
    }

    // sort by dependency order
    left := libs.dup.sort
    ordered := LibVersion[,]
    ordered.capacity = libs.size
    while (!left.isEmpty)
    {
      // find next that doesn't have depends in left list
      i := left.findIndex |x| { noDependsInLeft(left, x) }
      if (i == null) throw makeDependErr("Circular depends")
      ordered.add(left.removeAt(i));
    }
    return ordered
  }

  // TODO: change Err to DependErr when we move from haystack
  private static Err makeDependErr(Str msg) { Type.find("haystack::DependErr").make([msg]) }

  private static Bool noDependsInLeft(LibVersion[] left, LibVersion x)
  {
    x.depends.all |d| { left.all |q| { q.name != d.name } }
  }
}

