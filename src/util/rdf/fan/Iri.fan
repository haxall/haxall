//
// Copyright (c) 2019, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   24 Jan 2019  Matthew Giannini  Creation
//

**
** IRI
**
@Js final const class Iri
{

//////////////////////////////////////////////////////////////////////////
// Constructor
//////////////////////////////////////////////////////////////////////////

  ** Create an Iri for a blank node. You may provide a label, or one will be
  ** automatically generated using `Uuid`. RDF writers *may* choose to omit
  ** the label during serialization if it is parseable as a `Uuid`.
  **
  ** Two blank nodes with the same label are considered equal.
  **
  ** Note: Technically, an IRI is *not* a blank node; they are two distinct types
  ** of resources. But we put a restriction on our IRI implementation such that all
  ** IRIs with ns '_:' are blank nodes.
  static Iri bnode(Str label := Uuid().toStr)
  {
    Iri("_:${label}")
  }

  new makeNs(Str ns, Str name) : this.make("${ns}${name}")
  {
  }

  ** Make an `Iri` from a `Uri`. You should **never** use this constructor
  ** if the 'uri' is intended to represent a prefixed IRI because a `Uri` will
  ** normalize its scheme. Becaues of this normalization, the following is true:
  **
  **   // because `phIoT::elec`.toStr == "phiot:elec"
  **   Iri(`phIoT:elec`) != Iri("phIoT:elec")
  **   Iri(`phIoT:elec`) == Iri("phiot:elec")
  **
  ** You have been warned.
  **
  new makeUri(Uri uri) : this.make(uri.toStr)
  {
  }

  new make(Str iri)
  {
    if (!iri.containsChar(':')) throw ArgErr("Not a valid IRI: $iri")

    this.iri = iri
    this.nameIdx = toNameIdx(iri)
  }

  private static Int toNameIdx(Str iri)
  {
    idx := iri.index("#")
    if (idx == null) idx = iri.indexr("/")
    if (idx == null) idx = iri.indexr(":")
    if (idx == null) throw ArgErr("No namespace separator found in IRI: $iri")
    return idx + 1
  }

//////////////////////////////////////////////////////////////////////////
// Fields
//////////////////////////////////////////////////////////////////////////

  private const Str iri

  ** The index in 'iri' where the local name starts
  private const Int nameIdx

//////////////////////////////////////////////////////////////////////////
// IRI
//////////////////////////////////////////////////////////////////////////

  ** Get the IRI namespace
  Str ns() { iri[0..<nameIdx] }

  ** Get the IRI local name
  Str name() { iri[nameIdx..-1] }

  ** Get the `Iri` as a `Uri`. Note, because of `Uri` normalization
  ** it is possible that two *un-equal* `Iri`s will yield equivalent `Uri`s
  Uri uri() { iri.toUri }

  ** Is this a blank node?
  Bool isBlankNode() { ns == "_:" }

  ** If the current `ns` contains a prefix in the given map, then return a new `Iri`
  ** that uses the prefix. Otherwise, return this.
  Iri prefixIri([Str:Str] prefixMap)
  {
    // blank nodes are not prefixable
    if (isBlankNode) return this

    return prefixMap.eachWhile |namespace, prefix|
    {
      return this.ns == namespace ? Iri("${prefix}:", this.name) : null
    } ?: this
  }

  ** If the current `ns` prefix is mapped in the given map, then return a new `Iri`
  ** that is the expansion of the prefix. Otherwise, return this.
  Iri fullIri([Str:Str] prefixMap)
  {
    // blank nodes are not prefixable
    if (isBlankNode) return this
    myPrefix := this.ns[0..<-1]
    expanded := prefixMap[myPrefix]
    if (expanded == null) return this
    return Iri(expanded, this.name)
  }

//////////////////////////////////////////////////////////////////////////
// Obj
//////////////////////////////////////////////////////////////////////////

  override Int compare(Obj obj)
  {
    that := obj as Iri
    if (that == null) return super.compare(that)
    return this.uri <=> that.uri
  }

  override Int hash() { iri.hash }

  override Bool equals(Obj? obj)
  {
    if (this === obj) return true
    that := obj as Iri
    if (that == null) return false
    return this.iri == that.iri
  }

  override Str toStr() { iri }
}