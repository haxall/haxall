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
      f := toConfigFile(dir)
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
          uri     := v.toUri
          prefix  := "repo." + name + "."
          meta    := XetoUtil.propsToDict(prefix, props, ["uri"])
          workDir := propToDir.getChecked(n)
          register(name, uri, meta, workDir)
        }
        catch (Err e)
        {
          Console.cur.err("ERROR: cannot init xeto remote repo: $name", e)
        }
      }
    }
  }

  override RemoteRepo? def(Bool checked := true)
  {
    def := list.first
    if (def != null) return def
    if (checked) throw Err("No remote repos configured")
    return null
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

  override RemoteRepo? get(Str name, Bool checked := true)
  {
    r := byName.get(name)
    if (r != null) return r
    if (checked) throw UnresolvedErr("Unknown remote repo: $name")
    return null
  }

  override RemoteRepo? getByUri(Uri uri, Bool checked := true)
  {
    r := byUri.get(uri)
    if (r != null) return r
    if (checked) throw UnresolvedErr("Unknown remote repo: $uri")
    return null
  }

  override RemoteRepo add(Str name, Uri uri, Dict meta, Dict? opts := null)
  {
    if (opts == null) opts = Etc.dict0
    pathDir := opts.get("pathDir") as File ?: env.workDir

    r := register(name, uri, meta, pathDir)
    saveConfigFile(r, false)
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
    saveConfigFile(r, true)
  }

  private RemoteRepo register(Str name, Uri uri, Dict meta, File workDir)
  {
    if (name == "local" || uri == `local:/`) throw Err("Cannot register local")
    if (!Etc.isTagName(name)) throw Err("Invalid repo name: $name")
    if (byName.get(name) != null) throw Err("Duplicate repo name: $name")
    if (byUri.get(uri) != null) throw Err("Duplicate repo uri: $uri")

    init := RemoteRepoInit(env, name, uri, meta, workDir)
    r := MRemoteRepo.create(init)
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

  private Void saveConfigFile(RemoteRepo repo, Bool remove)
  {
    name   := repo.name
    prefix := "repo.${name}."
    file   := toConfigFile(repo.pathDir)
    lines  := file.exists ? file.readAllLines : Str[,]


    // remove any lines with prefix
    lines = lines.findAll |line|  { !line.startsWith(prefix) }

    // append new/updated repo lines
    if (!remove)
    {
      if (lines.last?.trimToNull != null) lines.add("")

      lines.add(prefix+"uri=" + repo.uri)
      XetoUtil.dictToProps(prefix, repo.meta).each |v, n|
      {
        lines.add("$n=$v")
      }
    }

    // rewrite the file
    file.out.print(lines.join("\n")).close
  }

  private static File toConfigFile(File pathDir)
  {
    pathDir + `etc/xeto/config.props`
  }

  private const ConcurrentMap byName := ConcurrentMap()
  private const ConcurrentMap byUri  := ConcurrentMap()
  private const AtomicRef defNameRef := AtomicRef()
  private const AtomicRef listRef    := AtomicRef()
}

