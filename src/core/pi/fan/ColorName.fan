//
// Copyright (c) 2026, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   29 Aug 2026  Brian Frank  Creation
//

using xeto

**
** Palette color name.
**
@Js @Gen
enum class ColorName
{
  ** Slate
  slate,

  ** Gray
  gray,

  ** Zinc
  zinc,

  ** Neutral
  neutral,

  ** Stone
  stone,

  ** Red - errors
  red,

  ** Orange - warnings, faults
  orange,

  ** Amber
  amber,

  ** Yellow - down
  yellow,

  ** Lime
  lime,

  ** Green - ok, success
  green,

  ** Emerald
  emerald,

  ** Teal
  teal,

  ** Cyan
  cyan,

  ** Sky
  sky,

  ** Blue - informational
  blue,

  ** Indigo
  indigo,

  ** Violet
  violet,

  ** Purple - abnormal
  purple,

  ** Fuchsia
  fuchsia,

  ** Pink
  pink,

  ** Rose
  rose


  ** Coerce to color name instance
  @NoDoc static ColorName? coerce(Obj? x, ColorName? def := null)
  {
    if (x is ColorName) return x
    if (x is Str) return fromStr(x.toStr, false) ?: def
    return def
  }

  ** CSS hex color: the Tailwind 500 shade the palette names come from,
  ** for renderers without a theme such as Fresco and server generated
  ** icons; Ion resolves names through its own style theme
  @NoDoc Str hex() { hexes[name] }

  private static const Str:Str hexes := [
    "slate":   "#64748b",
    "gray":    "#6b7280",
    "zinc":    "#71717a",
    "neutral": "#737373",
    "stone":   "#78716c",
    "red":     "#ef4444",
    "orange":  "#f97316",
    "amber":   "#f59e0b",
    "yellow":  "#eab308",
    "lime":    "#84cc16",
    "green":   "#22c55e",
    "emerald": "#10b981",
    "teal":    "#14b8a6",
    "cyan":    "#06b6d4",
    "sky":     "#0ea5e9",
    "blue":    "#3b82f6",
    "indigo":  "#6366f1",
    "violet":  "#8b5cf6",
    "purple":  "#a855f7",
    "fuchsia": "#d946ef",
    "pink":    "#ec4899",
    "rose":    "#f43f5e",
  ]
}

