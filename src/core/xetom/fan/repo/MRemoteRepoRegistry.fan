//
// Copyright (c) 2026, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   24 Apr 2026  Brian Frank  Creation
//

using concurrent
using util
using xeto
using haystack

**
** RemoteRepoRegistry implementation
**
@Js
const class MRemoteRepoRegistry : RemoteRepoRegistry
{
  new make(MEnv env)
  {
    this.env = env
    load
  }

  const MEnv env

  Void load()
  {
    byName.clear
    byUri.clear
    defNameRef.val = null

    // we do our own props using env path and keep track of dir
    props := Str:Str[:]
    propToDir := Str:File[:]
    env.path.each |dir|
    {
      f := dir + `etc/xeto/config.props`
      try
      {
        if (!f.exists) return
        f.readProps.each |v, n|
        {
          props[n] = v
          propToDir[n] = dir
        }
      }
      catch (Err e)
      {
        Console.cur.err("ERROR: cannot read props: $f.osPath", e)
      }
    }

    // now process
    props.each |v, n|
    {
      if (n == "repo.default") { defNameRef.val = v; return }

      if (n.startsWith("repo.") && n.endsWith(".uri"))
      {
        name := n[5 .. -5]
        try
        {
          uri := v.toUri
          meta := Str:Obj[:]
          prefix := "repo." + name + "."
          props.each |n2, v2|
          {
            if (n2.startsWith(prefix) && n2 != n)
              meta.set(n2[prefix.size+1..-1], v2)
          }
          workDir := propToDir.getChecked(n)
          register(name, uri, Etc.dictFromMap(meta), workDir)
        }
        catch (Err e)
        {
          Console.cur.err("ERROR: cannot init xeto remote repo: $name", e)
        }
      }
    }
  }

  override RemoteRepo[] list()
  {
    list := listRef.val as RemoteRepo[]
    if (list == null)
    {
      list = (RemoteRepo[])byName.vals(RemoteRepo#)
      list.sort |a, b| { a.name <=> b.name }
      def := list.find { it.name == defNameRef.val }
      if (def != null) list.moveTo(def, 0)
      listRef.val = list = list.toImmutable
    }
    return list
  }

  override RemoteRepo? get(Str name, Bool check := true)
  {
    r := byName.get(name)
    if (r != null) return r
    throw UnresolvedErr("Unknown remote repo: $name")
    return null
  }

  override RemoteRepo? getByUri(Uri uri, Bool check := true)
  {
    r := byUri.get(uri)
    if (r != null) return r
    throw UnresolvedErr("Unknown remote repo: $uri")
    return null
  }

  override RemoteRepo add(Str name, Uri uri, Dict meta, Dict? opts := null)
  {
    if (opts == null) opts = Etc.dict0
    pathDir := opts.get("pathDir") as File ?: Env.cur.workDir

    r := register(name, uri, meta, pathDir)
    return r
  }

  override Void remove(Str name, Dict? opts := null)
  {
    if (opts == null) opts = Etc.dict0
    anyPath := opts.has("anyPathDir")

    r := get(name)
    if (r.pathDir != env.workDir && !anyPath)
      throw Err("Must use anyPathDir option to remove from non-workDir [$name]")

    unregister(name)
  }

  private RemoteRepo register(Str name, Uri uri, Dict meta, File workDir)
  {
    if (name == "local" || uri == `local:/`) throw Err("Cannot register local")
    if (!Etc.isTagName(name)) throw Err("Invalid repo name: $name")
    init := RemoteRepoInit(name, uri, meta, workDir)
    r := AbstractRemoteRepo(init) // TODO
    byName.add(name, r)
    byUri.add(uri, r)
    listRef.val = null
    return r
  }

  private Void unregister(Str name)
  {
    r := get(name, false)
    if (r == null) return
    byName.remove(r.name)
    byUri.remove(r.uri)
    listRef.val = null
  }

  private const ConcurrentMap byName := ConcurrentMap()
  private const ConcurrentMap byUri  := ConcurrentMap()
  private const AtomicRef defNameRef := AtomicRef()
  private const AtomicRef listRef    := AtomicRef()
}

