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

  ** Return "name-version"
  override abstract Str toStr()

  ** Is this a sys only library
  @NoDoc abstract Bool isSysOnly()

  ** Get this exact version as LibDepend instance
  @NoDoc LibDepend asDepend()
  {
    LibDepend(name, LibDependVersions(version))
  }

  ** File used to load this lib if backed by the file system.  If we are
  ** using the source then return the source directory, otherwise return
  ** the xetolib zip file found in "lib/xeto".  If the version is not backed
  ** by a file then raise exception or return null based on checked flag.
  @NoDoc abstract File? file(Bool checked := true)

  ** Does the file represent a source directory under "src/xeto".
  ** False means this version was loaded from xetolib zip file.
  @NoDoc abstract Bool isSrc()

  ** Iterate every ".xeto" source file in this library
  @NoDoc abstract Void eachSrcFile(|File| f)

  ** Is this a shim lib version for a lib not found in the installation
  @NoDoc abstract Bool isNotFound()

  ** Order a list of versions by their dependencies.  Raise exception if
  ** the given list does not satisify all the internal dependencies or
  ** has circular dependencies.
  static LibVersion[] orderByDepends(LibVersion[] libs)
  {
    errs := Str:Err[:]
    ordered := checkDepends(libs, errs)
    if (!errs.isEmpty) throw errs.vals.first
    return ordered
  }

  ** Order a list of versions by their dependencies and check for errors.
  ** Populate the errs map with lib names that have errors such as an
  ** unmet depends.  Libs with errors are added to end of the ordered list.
  @NoDoc static LibVersion[] checkDepends(LibVersion[] libs, Str:Err errs)
  {
    // build map by name
    byName := Str:LibVersion[:]
    libs.each |x| { byName.add(x.name, x) }

    // check internal version constraints
    unmet := LibDepend[,]
    libs.each |x|
    {
      // handle not found shim
      if (x.isNotFound)
      {
        errs[x.name] = UnknownLibErr("Lib '$x.name' not found")
        return
      }

      // check depends
      unmet.clear
      x.depends.each |d|
      {
        m := byName[d.name]
        if (m == null || !d.versions.contains(m.version))
          unmet.add(d)
      }

      if (!unmet.isEmpty)
      {
        // build list of missing names or name+version
        strs := unmet.map |d->Str| { byName.containsKey(d.name) ? d.toStr : d.name }
        errs[x.name] = DependErr("Lib '$x.name' has missing depends: " + strs.sort.join(", "))
      }
    }

    // sort those not in error by dependency order
    left := libs.findAll { errs[it.name] == null }.sort
    ordered := LibVersion[,]
    ordered.capacity = libs.size
    while (!left.isEmpty)
    {
      // find next that doesn't have depends in left list
      i := left.findIndex |x| { noDependsInLeft(left, x) }
      if (i == null)
        break
      else
        ordered.add(left.removeAt(i));
    }

    // mark those left as circular dependencies
    left.each |x|
    {
      errs[x.name] = DependErr("Lib '$x.name' has circular depends")
    }

    // add those in error (sorted)
    errs.keys.sort.each |name| { ordered.add(byName.getChecked(name)) }

    // return ordered list
    return ordered
  }

  private static Bool noDependsInLeft(LibVersion[] left, LibVersion x)
  {
    x.depends.all |d| { left.all |q| { q.name != d.name } }
  }
}

