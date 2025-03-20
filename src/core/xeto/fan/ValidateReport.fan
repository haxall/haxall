//
// Copyright (c) 2025, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   20 Mar 2025  Brian Frank  Creation
//

using util

**
** ValidateReport bundles a list of validation items
**
@NoDoc @Js
const mixin ValidateReport
{
  ** Subject dicts validated
  abstract Dict[] subjects()

  ** List all validation items
  abstract ValidateItem[] items()

  ** If there one or more error level items
  abstract Bool hasErrs()

  ** Number of error level items
  abstract Int numErrs()

  ** Number of warning level items
  abstract Int numWarns()

  ** Debug dump
  @NoDoc abstract Void dump(Console con := Console.cur)
}

**************************************************************************
** ValidateItem
**************************************************************************

**
** ValidateItem models one warning or error message from validation
**
@Js
const mixin ValidateItem
{
  ** Warning or error level
  abstract ValidateLevel level()

  ** Subject dict.  If validate was called against a
  ** non-dict value then this is an empty dict.
  abstract Dict subject()

  ** Slot of subject or null if on subject itself.
  ** This is dotted path if item is on a nested dict in the subject.
  abstract Str? slot()

  ** Free-form message for validation error
  abstract Str msg()
}

**************************************************************************
** ValidateLevel
**************************************************************************

@Js
enum class ValidateLevel
{
  ** Warning level
  warn,

  ** Error level
  err

  ** Is this the 'err' enum value
  Bool isErr() { this === err }

  ** Is this the 'warn' enum value
  Bool isWarn() { this === warn }
}

