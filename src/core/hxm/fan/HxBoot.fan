//
// Copyright (c) 2025, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//    8 Jul 2025  Brian Frank  Creation
//

using xeto
using haystack
using folio
using hx

**
** Base class for all bootstrap project loaders
**
abstract class HxBoot
{

//////////////////////////////////////////////////////////////////////////
// Constructor
//////////////////////////////////////////////////////////////////////////

  ** Constructor
  new make(Str name, File dir)
  {
    // validate and normalize dir
    if (!dir.isDir) dir = dir.uri.plusSlash.toFile
    dir = dir.normalize
    if (!dir.exists) throw ArgErr("Dir does not exist: $dir")

    // valid name
    if (!Etc.isTagName(name)) throw ArgErr("Invalid proj name: $name")

    this.name = name
    this.dir  = dir
  }

//////////////////////////////////////////////////////////////////////////
// Configuration
//////////////////////////////////////////////////////////////////////////

  ** Project name
  const Str name

  ** Project directory
  const File dir

  ** System version
  abstract Version version()

  ** Logger to use for bootstrap
  abstract Log log()

  ** Xeto environment
  virtual XetoEnv xetoEnv() { XetoEnv.cur }

  ** List of xeto lib names which are required to be installed.
  virtual Str[] requiredLibs()
  {
    [
    "sys",
    "sys.files",
    ]
  }

//////////////////////////////////////////////////////////////////////////
// Public
//////////////////////////////////////////////////////////////////////////

  ** Initialize the project but do not start it
  MHxProj init()
  {
    this.ns   = initNamespace
    this.db   = initFolio
    this.meta = initMeta
    return initProj
  }

//////////////////////////////////////////////////////////////////////////
// Overrides
//////////////////////////////////////////////////////////////////////////

  ** Create project namespace
  virtual HxNamespace initNamespace()
  {
    MHxNamespace.load(xetoEnv.repo, requiredLibs)
  }

  ** Open project folio database
  abstract Folio initFolio()

  ** Ensure projMeta exists and has current version
  virtual Dict initMeta()
  {
    // setup the tags we want for projMeta
    tags := ["projMeta": Marker.val, "version": version.toStr]

    // update rec and set back to projMeta field so HxdRuntime can init itself
    return initRec("projMeta", db.read(Filter.has("projMeta"), false), tags)
  }

  ** Create HxProj implementation
  virtual MHxProj initProj()
  {
    MHxProj(this)
  }

//////////////////////////////////////////////////////////////////////////
// Utils
//////////////////////////////////////////////////////////////////////////

  ** Ensure given record exists and has given tags
  Dict initRec(Str summary, Dict? rec, Str:Obj changes := [:])
  {
    if (rec == null)
    {
      log.info("Create $summary")
      return db.commit(Diff(null, changes, Diff.add.or(Diff.bypassRestricted))).newRec
    }
    else
    {
      changes = changes.findAll |v, n| { rec[n] != v }
      if (changes.isEmpty) return rec
      log.info("Update $summary")
      return db.commit(Diff(rec, changes)).newRec
    }
  }

//////////////////////////////////////////////////////////////////////////
// Internal Fields
//////////////////////////////////////////////////////////////////////////

  internal MHxNamespace? ns
  internal Folio? db
  internal Dict? meta
}

