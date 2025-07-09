//
// Copyright (c) 2021, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   18 May 2021  Brian Frank  Creation
//    8 Jul 2025  Brian Frank  Redesign from HxRuntime
//

using concurrent
using xeto
using haystack
using folio

**
** Proj is the API to work with a project database
**
const mixin Proj
{
  ** Project name
  abstract Str name()

  ** Project id which is always formatted as "p:{name}"
  abstract Ref id()

  ** Project metadata
  abstract Dict meta()

  ** Base directory for project
  abstract File dir()

  ** Folio database
  abstract Folio db()

  ** Xeto namespace
  abstract Namespace ns()

  ** Xeto library managment APIs
  abstract ProjLibs libs()

  ** Extension management APIs
  abstract ProjExts exts()
}

**************************************************************************
** ProjLibs
**************************************************************************

**
** Project Xeto namespace library management
**
const mixin ProjLibs
{
  ** List of Xeto libraries installed in the project
  abstract ProjLib[] list()

  ** Lookup an project library by name.  If not found then
  ** return null or raise UnknownLibErr based on checked flag.
  abstract ProjLib? get(Str name, Bool checked := true)

  ** Check if there is an enabled library with given name
  abstract Bool has(Str name)

  ** List all the libs installed
  abstract ProjLib[] installed()

  ** Return status grid of project libs
  @NoDoc abstract Grid status(Bool installed := false)
}

**************************************************************************
** ProjExts
**************************************************************************

**
** Project extension management
**
const mixin ProjExts
{
  ** List of extensions currently enabled sorted by qname
  abstract Ext[] list()

  ** Lookup an extension by spec qname.  If not found then
  ** return null or raise UnknownExtErr based on checked flag.
  abstract Ext? get(Str qname, Bool checked := true)

  ** Check if there is an enabled extension with given name
  abstract Bool has(Str qname)

  ** Actor thread pool to use for extension background processing
  abstract ActorPool actorPool()

  ** Return status grid of enabled extensions
  @NoDoc abstract Grid status()
}

