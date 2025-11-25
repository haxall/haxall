//
// Copyright (c) 2023, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   16 Jan 2023  Brian Frank  Creation
//

using util

**
** Versioned library module of specs and defs.
**
** Lib dict representation:
**   - id: Ref "lib:{name}"
**   - spec: Ref "sys::Lib"
**   - loaded: marker tag if loaded into memory
**   - meta
**
@Js
const mixin Lib : Dict
{

  ** Return "lib:{name}" as identifier
  abstract override Ref id()

  ** Dotted name of the library
  abstract Str name()

  ** Meta data for library
  abstract Dict meta()

  ** Version of this library
  abstract Version version()

  ** List the dependencies
  abstract LibDepend[] depends()

  ** List the top level specs (types and global slots)
  abstract Spec[] specs()

  ** Lookup a top level spec in this library by simple name (type or global slot)
  abstract Spec? spec(Str name, Bool checked := true)

  ** List the type specs
  abstract Spec[] types()

  ** Lookup a type spec in this library by simple name
  abstract Spec? type(Str name, Bool checked := true)

  ** Iterate the type specs
  abstract Void eachType(|Spec| f)

  ** Iterate the type specs until callback returns non-null
  @NoDoc abstract Obj? eachTypeWhile(|Spec->Obj?| f)

  ** List the mixins in this library
  abstract Spec[] mixins()

  ** Lookup the mixin for the given type in this library
  abstract Spec? mixinFor(Spec type, Bool checked := true)

  ** List the instance data dicts declared in this library
  abstract Dict[] instances()

  ** Lookup an instance dict by its simple name
  abstract Dict? instance(Str name, Bool checked := true)

  ** Iterate the instances
  abstract Void eachInstance(|Dict| f)

  ** Funcs declared by this lib under the 'Funcs' mixin.
  @NoDoc abstract SpecMap funcs()

  ** Is this the 'sys' library
  @NoDoc abstract Bool isSys()

  ** Does this library contain markdown resource files
  @NoDoc abstract Bool hasMarkdown()

  ** File location of definition or unknown
  @NoDoc abstract FileLoc loc()

  ** Access all the resource files contained by this library.  Resources
  ** are any files included in the libs's zip file excluding xeto files.
  ** This API is only available in server environments.
  abstract LibFiles files()

}

**************************************************************************
** LibFiles
**************************************************************************

**
** Access to file resources packaged with library.
**
@Js
const mixin LibFiles
{
  ** Return if this API is supported, will be false in browser environments.
  abstract Bool isSupported()

  ** List resource files in this library.
  abstract Uri[] list()

  ** Get a file in this library (treat this file as readonly)
  abstract File? get(Uri uri, Bool checked := true)
}

