//
// Copyright (c) 2026, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   25 Apr 2026  Trevor Adelman  Creation
//

using concurrent
using util
using web
using xeto
using haystack

**
** GithubRepo is a RemoteRepo backed by a public GitHub repository.
** The configured URI is expected to be a GitHub repo URL in the form
** `https://github.com/{owner}/{repo}`.
**
** The repo index is built using the GitHub GraphQL API which requires
** authentication via a personal access token resolved from
** `Env.cur.vars["GITHUB_TOKEN"]` (set in fan.props).
**
** Caching strategy uses two caches:
**   - `manifestRef` (AtomicRef): `Str:Version[]` map of lib names to
**     all available versions sorted latest to oldest.  Built by scanning
**     all release tags.
**   - `libCache` (ConcurrentMap): individual `RemoteLibVersion` instances
**     keyed by `"$name-$version"`.  Lazily loaded with full depends
**     metadata when a specific version is requested.
**
const class GithubRepo : MRemoteRepo
{

//////////////////////////////////////////////////////////////////////////
// Construction
//////////////////////////////////////////////////////////////////////////

  new make(RemoteRepoInit init) : super(init)
  {
    path := init.uri.path
    if (path.size < 2) throw Err("GitHub repo URI must be https://github.com/{owner}/{repo}: $init.uri")
    this.owner = path[0]
    this.repo  = path[1]
  }

  private const Str owner
  private const Str repo
  private const Log log := Log.get("github")
  private const AtomicRef manifestRef := AtomicRef()
  private const ConcurrentMap libCache := ConcurrentMap()

//////////////////////////////////////////////////////////////////////////
// RemoteRepo
//////////////////////////////////////////////////////////////////////////

 ** Ping the GitHub repo and return metadata dict.
  override Dict? ping(Bool checked := true)
  {
    try
    {
      res := graphql(
        "query {
           repository(owner: \"$owner\", name: \"$repo\") {
             name
             description
             defaultBranchRef { name }
             visibility
             url
           }
         }")
      r := repoData(res)
      branch := (r["defaultBranchRef"] as Str:Obj?)?.get("name")
      return Etc.makeDict([
        "name":          r["name"],
        "description":   r["description"],
        "defaultBranch": branch,
        "visibility":    r["visibility"],
        "htmlUrl":       r["url"],
      ])
    }
    catch (Err e)
    {
      if (checked) throw e
      return null
    }
  }

  ** Search the GitHub repo for xetolibs matching the query.
  ** Filters manifest by name, then returns latest version with full depends.
  override RemoteRepoSearchRes search(RemoteRepoSearchReq req)
  {
    manifest := loadManifest
    names := manifest.keys.findAll |n|
    {
      // use a lightweight RemoteLibVersion for matching
      req.matches(RemoteLibVersion(n, Version.defVal))
    }
    libs := names.map |n->LibVersion| { latest(n) }
    return MRemoteRepoSearchRes { it.libs = libs }
  }

  ** List versions for a given library name, sorted latest to oldest.
  override LibVersion[] versions(Str name, Dict? opts := null)
  {
    vers := loadManifest[name]
    if (vers == null) return LibVersion#.emptyList
    list := vers.map |v->LibVersion| { loadLibVersion(name, v) }
    return findAllVersionsWithOpts(list, opts)
  }

  ** Download the source files for a lib as a zip Buf.
  ** Source files are written raw; build.props is included in the zip
  ** so the compiler resolves BuildVar tokens at load time (matches
  ** the OutputZip strategy in xetoc).
  override Buf fetch(Str name, Version version)
  {
    // verify the lib+version exists and get enriched metadata
    ver := this.version(name, version)

    // resolve the git ref for this version
    ref := "v$version"

    // fetch build.props for inclusion in zip
    buildProps := fetchBuildProps(ref)

    // query all files in the lib directory at that ref
    files := fetchLibFiles(name, ref)
    if (files.isEmpty) throw Err("No source files found for $name at $ref in $owner/$repo")

    // zip into a Buf matching OutputZip order: meta.props, build.props, then source
    buf := Buf()
    zip := Zip.write(buf.out)
    try
    {
      // meta.props — required for FileLibVersion.loadZipFile
      writeMetaProps(zip, ver)

      // build.props — must be before xeto files (compiler reads it first)
      if (!buildProps.isEmpty)
        zip.writeNext(`/build.props`).writeProps(buildProps).close

      // source files — written raw, BuildVars resolved by compiler at load time
      files.each |content, fileName|
      {
        out := zip.writeNext(fileName.toUri)
        out.print(content)
        out.close
      }
    }
    finally zip.close
    buf.seek(0)
    return buf.toImmutable
  }

  ** Write meta.props into zip via XetoUtil choke point.
  private Void writeMetaProps(Zip zip, LibVersion ver)
  {
    meta := Etc.dict1x("doc", ver.doc)
    props := XetoUtil.buildLibMetaProps(ver.name, ver.version, ver.depends, meta)
    zip.writeNext(`/meta.props`).writeProps(props).close
  }

  ** Resolve BuildVar tokens in xeto source content using build.props values.
  ** Used only by parseLibMeta which operates on a single file without
  ** build.props context.
  private Str resolveBuildVars(Str content, Str:Str buildProps)
  {
    if (buildProps.isEmpty) return content
    resolved := content
    buildProps.each |val, key| { resolved = resolved.replace("BuildVar \"$key\"", "\"$val\"") }
    return resolved
  }

  ** Fetch build.props for a given git ref via GraphQL.
  private Str:Str fetchBuildProps(Str ref)
  {
    res := graphql(
      "query {
         repository(owner: \"$owner\", name: \"$repo\") {
           object(expression: \"$ref:src/xeto/build.props\") { ... on Blob { text } }
         }
       }")
    blob := repoData(res).get("object") as Str:Obj?
    return parseBuildProps(blob?.get("text") as Str)
  }

//////////////////////////////////////////////////////////////////////////
// Manifest
//////////////////////////////////////////////////////////////////////////

  ** Return map of libs keyed by lib name with available versions
  ** sorted by latest to oldest.  Cached in AtomicRef.
  private Str:Version[] loadManifest()
  {
    cached := manifestRef.val as Str:Version[]
    if (cached != null) return cached

    tags := listReleaseTags
    result := tags.isEmpty ? manifestFromHead : manifestFromTags(tags)
    log.debug("loadManifest: ${result.size} libs from ${tags.size} tags")

    manifestRef.val = result.toImmutable
    return result
  }

  ** Build manifest from release tags: scan all tags, list libs at each.
  private Str:Version[] manifestFromTags(Str[] tags)
  {
    // batch-list lib dirs at every tag
    tagLibs := batchListLibNames(tags)

    acc := Str:Version[][:]
    tags.each |tag|
    {
      ver := parseTagVersion(tag)
      if (ver == null) return
      names := tagLibs[tag] ?: Str[,]
      names.each |n|
      {
        list := acc[n]
        if (list == null) { list = Version[,]; acc[n] = list }
        list.add(ver)
      }
    }

    // sort each list latest to oldest
    acc.each |list| { list.sortr }
    return acc
  }

  ** Build manifest from HEAD (fallback when no releases).
  private Str:Version[] manifestFromHead()
  {
    libNames := batchListLibNames(["HEAD"])["HEAD"] ?: Str[,]
    if (libNames.isEmpty) return Str:Version[][:]

    contents := fetchLibXetoFiles(libNames, "HEAD")
    buildProps := parseBuildProps(contents["build.props"])

    acc := Str:Version[][:]
    libNames.each |name|
    {
      content := contents[name]
      if (content == null) return
      parsed := parseLibMeta(name, content, buildProps)
      if (parsed != null) acc[name] = [parsed.version]
    }
    return acc
  }

//////////////////////////////////////////////////////////////////////////
// Per-Version Cache
//////////////////////////////////////////////////////////////////////////

  ** Lazily load and cache a given name+version instance.
  ** Keyed in ConcurrentMap by "$name-$version".
  private RemoteLibVersion loadLibVersion(Str name, Version ver)
  {
    key := "$name-$ver"
    cached := libCache[key] as RemoteLibVersion
    if (cached != null) return cached
    ref := "v$ver"
    result := fetchAndParseLibVersion(name, ver, ref)
    libCache[key] = result
    return result
  }

  ** Fetch lib.xeto + build.props at a specific ref and parse into RemoteLibVersion.
  private RemoteLibVersion fetchAndParseLibVersion(Str name, Version ver, Str ref)
  {
    // batch-fetch lib.xeto + build.props in one query
    buf := StrBuf()
    buf.add("query { repository(owner: \"$owner\", name: \"$repo\") {\n")
    buf.add("  props: object(expression: \"$ref:src/xeto/build.props\") { ... on Blob { text } }\n")
    buf.add("  lib: object(expression: \"$ref:src/xeto/$name/lib.xeto\") { ... on Blob { text } }\n")
    buf.add("}}")

    r := repoData(graphql(buf.toStr))
    propsContent := (r["props"] as Str:Obj?)?.get("text") as Str
    libContent := (r["lib"] as Str:Obj?)?.get("text") as Str

    buildProps := parseBuildProps(propsContent)

    if (libContent != null)
    {
      parsed := parseLibMeta(name, libContent, buildProps)
      if (parsed != null)
        return RemoteLibVersion(name, ver, parsed.doc, parsed.depends(false))
    }

    // fallback if lib.xeto not found at this ref
    return RemoteLibVersion(name, ver)
  }

//////////////////////////////////////////////////////////////////////////
// GitHub Helpers
//////////////////////////////////////////////////////////////////////////

  ** Batch-query lib directory names under src/xeto/ for multiple git refs.
  private Str:Str[] batchListLibNames(Str[] refs)
  {
    buf := StrBuf()
    buf.add("query { repository(owner: \"$owner\", name: \"$repo\") {\n")
    refs.each |ref|
    {
      alias := toAlias(ref)
      buf.add("  $alias: object(expression: \"$ref:src/xeto\") { ... on Tree { entries { name type } } }\n")
    }
    buf.add("}}")

    r := repoData(graphql(buf.toStr))
    acc := Str:Str[][:]
    refs.each |ref|
    {
      entries := (r[toAlias(ref)] as Str:Obj?)?.get("entries") as List
      names := Str[,]
      entries?.each |e| { map := e as Str:Obj?; if (map != null && map["type"] == "tree") names.add(map["name"]) }
      acc[ref] = names
    }
    return acc
  }

  ** Batch-fetch build.props + all lib.xeto files at a given ref.
  private Str:Str? fetchLibXetoFiles(Str[] libNames, Str ref)
  {
    buf := StrBuf()
    buf.add("query { repository(owner: \"$owner\", name: \"$repo\") {\n")
    buf.add("  buildProps: object(expression: \"$ref:src/xeto/build.props\") { ... on Blob { text } }\n")
    libNames.each |name|
    {
      buf.add("  ${toAlias(name)}: object(expression: \"$ref:src/xeto/$name/lib.xeto\") { ... on Blob { text } }\n")
    }
    buf.add("}}")

    r := repoData(graphql(buf.toStr))
    acc := Str:Str?[:]
    acc["build.props"] = (r["buildProps"] as Str:Obj?)?.get("text") as Str
    libNames.each |name| { acc[name] = (r[toAlias(name)] as Str:Obj?)?.get("text") as Str }
    return acc
  }

  ** Fetch all source files for a lib directory at a given ref.
  private Str:Str fetchLibFiles(Str name, Str ref)
  {
    res := graphql(
      "query {
         repository(owner: \"$owner\", name: \"$repo\") {
           object(expression: \"$ref:src/xeto/$name\") {
             ... on Tree {
               entries { name type object { ... on Blob { text } } }
             }
           }
         }
       }")
    entries := (repoData(res).get("object") as Str:Obj?)?.get("entries") as List
    if (entries == null) return Str:Str[:]

    acc := Str:Str[:]
    entries.each |e|
    {
      map := e as Str:Obj?
      if (map == null || map["type"] != "blob") return
      fileName := map["name"] as Str
      text := (map["object"] as Str:Obj?)?.get("text") as Str
      if (fileName != null && text != null) acc[fileName] = text
    }
    return acc
  }

  ** List release tag names from GitHub, newest first.
  ** Only includes tags matching the `vX.Y.Z` pattern.
  private Str[] listReleaseTags()
  {
    res := graphql(
      "query {
         repository(owner: \"$owner\", name: \"$repo\") {
           releases(first: 100, orderBy: {field: CREATED_AT, direction: DESC}) {
             nodes { tagName }
           }
         }
       }")
    r := repoData(res)
    releases := r.get("releases") as Str:Obj?
    nodes := releases?.get("nodes") as List
    if (nodes == null) return Str[,]

    acc := Str[,]
    nodes.each |n|
    {
      map := n as Str:Obj?
      tag := map?.get("tagName") as Str
      if (tag != null && parseTagVersion(tag) != null) acc.add(tag)
    }
    return acc
  }

  ** Parse build.props content into a key-value map.
  private Str:Str parseBuildProps(Str? content)
  {
    if (content == null) return Str:Str[:]
    return content.in.readProps
  }

  ** Parse lib.xeto content into a RemoteLibVersion via XetoCompiler.
  ** BuildVar tokens are resolved before parsing so the compiler sees plain values.
  private RemoteLibVersion? parseLibMeta(Str libName, Str content, Str:Str buildProps)
  {
    resolved := resolveBuildVars(content, buildProps)
    tempDir := Env.cur.tempDir.plus(`github-${owner}-${repo}-${DateTime.nowTicks}/${libName}/`)
    try
    {
      tempDir.create
      tempDir.plus(`lib.xeto`).out.print(resolved).close

      c := XetoCompiler.init { it.libName = libName; it.input = tempDir.plus(`lib.xeto`) }
      parsed := c.parseLibMeta
      return RemoteLibVersion(parsed.name, parsed.version, parsed.doc, parsed.depends(false))
    }
    catch (Err e)
    {
      log.warn("Failed to parse lib.xeto for $libName in $owner/$repo: $e.msg")
      return null
    }
    finally { try tempDir.parent.delete; catch {} }
  }

  ** Parse a tag like "v5.0.0" into a Version, or return null if not valid.
  private static Version? parseTagVersion(Str tag)
  {
    if (!tag.startsWith("v")) return null
    return Version.fromStr(tag[1..-1], false)
  }

  ** Extract the repository object from a GraphQL response.
  private Str:Obj? repoData(Str:Obj? res)
  {
    data := res["data"] as Str:Obj? ?: throw Err("No data in GraphQL response for $owner/$repo")
    return data["repository"] as Str:Obj? ?: throw Err("No repository in response for $owner/$repo")
  }

  ** Convert a dotted lib name to a valid GraphQL alias (replace dots with underscores).
  private static Str toAlias(Str name) { "lib_" + name.replace(".", "_") }

  ** Clear all caches so the next call re-fetches from GitHub.
  Void clearCache() { manifestRef.val = null; libCache.clear }

  ** Type name to use for a group of repos such as "github"
  override Str? authTokenTypeName() { "github" }

//////////////////////////////////////////////////////////////////////////
// GitHub GraphQL API
//////////////////////////////////////////////////////////////////////////

  private static const Uri graphqlUri := `https://api.github.com/graphql`

  ** Execute a GraphQL query and return the parsed JSON response.
  private Str:Obj? graphql(Str query)
  {
    wc := WebClient(graphqlUri)
    wc.reqHeaders["Authorization"] = "Bearer ${authToken}"
    wc.reqHeaders["Content-Type"]  = "application/json"
    wc.reqHeaders["User-Agent"]    = "github"
    try
    {
      body := JsonOutStream.writeJsonToStr(["query": query])
      wc.postStr(body)
      if (wc.resCode != 200)
        throw Err("GitHub GraphQL error (${wc.resCode}) for $owner/$repo")
      json := JsonInStream(wc.resStr.in).readJson as Str:Obj?
      errs := json?.get("errors") as List
      if (errs != null && !errs.isEmpty)
      {
        msg := (errs.first as Str:Obj?)?.get("message") ?: "Unknown GraphQL error"
        throw Err("GitHub GraphQL: $msg")
      }
      return json ?: throw Err("Empty GraphQL response")
    }
    finally wc.close
  }
}

