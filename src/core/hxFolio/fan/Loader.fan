//
// Copyright (c) 2016, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   16 Feb 2016  Brian Frank  Creation
//

using concurrent
using xeto
using haystack
using folio
using hxStore

**
** Loader reads blobs into data strutures for the in-memory index
**
internal class Loader
{
  new make(FolioConfig config)
  {
    this.config = config
  }

  This load()
  {
    loadBlobs
    loadRecs
    return this
  }

  private Void loadBlobs()
  {
    blobs = Store.open(config.dir, toStoreConfig(config.opts))
  }

  private static StoreConfig toStoreConfig(Dict opts)
  {
    StoreConfig
    {
      if (opts.has("hisPageSize")) it.hisPageSize = ((Number)opts->hisPageSize).toDuration
    }
  }

  private Void loadRecs()
  {
    blobs.each |b|
    {
      try
      {
        if (b.meta.size == 0) loadRec(b)
      }
      catch (Err e) throw err("Cannot load rec blob: $b", e)
    }
  }

  private Void loadRec(Blob blob)
  {
    blob.read(buf)
    dict := reader.readDict
    rec := Rec(blob, dict)
    byId.add(rec.id, rec)
    byHandle.add(rec.handle, LoaderRec(rec))
  }

  Ref internRef(Str id)
  {
    ref := refs[id]
    if (ref == null)
    {
      ref = Ref(id)
      if (ref.isRel)
      {
        // turn proj relative refs into absolute refs
        if (config.idPrefix != null)
        {
          ref = ref.toAbs(config.idPrefix)
          refs[id] = ref
        }
      }
      refs[ref.id] = ref
    }
    return ref
  }

  private Err err(Str msg, Err? cause := null)
  {
    LoadErr(msg, cause)
  }

  const FolioConfig config
  Buf buf := Buf(4096)
  BrioReader reader := LoaderBrioReader(this, buf.in) // reuse for interning
  Str:Ref refs := [:]
  ConcurrentMap byId := ConcurrentMap() // Ref:Rec
  Int:LoaderRec byHandle := [:]
  Store? blobs
}

**************************************************************************
** LoaderRec
**************************************************************************

internal class LoaderRec
{
  new make(Rec rec) { this.rec = rec }
  const Rec rec
}

**************************************************************************
** LoaderBrioReader
**************************************************************************

internal class LoaderBrioReader : BrioReader
{
  new make(Loader l, InStream in) : super(in) { loader = l }
  Loader loader
  override Ref internRef(Str id, Str? dis) { loader.internRef(id) }
}

