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
    props := Env.cur.props(Pod.find("xeto"), `config.props`, 0ms)
    props.each |v, n|
    {
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
          register(name, uri, Etc.dictFromMap(meta))
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
    byName.vals(RemoteRepo#)
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

  override RemoteRepo add(Str name, Uri uri, Dict meta)
  {
    register(name, uri, meta)
  }

  override Void remove(Str name)
  {
    unregister(name)
  }

  private RemoteRepo register(Str name, Uri uri, Dict meta)
  {
    if (name == "local" || uri == `local:/`) throw Err("Cannot register local")
    if (!Etc.isTagName(name)) throw Err("Invalid repo name: $name")
    init := RemoteRepoInit(name, uri, meta)
    r := AbstractRemoteRepo(init) // TODO
    byName.add(name, r)
    byUri.add(uri, r)
    return r
  }

  private Void unregister(Str name)
  {
    r := get(name, false)
    if (r == null) return
    byName.remove(r.name)
    byUri.remove(r.uri)
  }

  private const ConcurrentMap byName := ConcurrentMap()
  private const ConcurrentMap byUri := ConcurrentMap()
}

