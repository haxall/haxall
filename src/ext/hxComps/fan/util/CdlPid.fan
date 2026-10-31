//
// Copyright (c) 2026, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   16 Oct 2026  Lincoln Harmer  Creation
//

using xeto
using haystack

**
** Proportional, integral and derivative controller with output limits,
** integrator anti-windup and an optional reset.  This is the CDL
** `Reals.PID` block, and `Reals.PIDWithReset` when `inReset` is linked.
** Unlike `Pid`, it takes the CDL parameters and executes every cycle.
** `out` is `k*e + I + D` limited to `yMin`..`yMax`, where `e` is
** `(inSetpoint - inMeasurement) / r`, negated when `reverseActing` is
** false.  The integrator stops winding up while `out` is limited.  When
** `inReset` turns true, PI and PID set `I` so the output before the limits
** is `yReset`.  A null or invalid `inReset` is no reset.  `I` bounds a
** stall as `Integrator` does, and `D` takes one as a gap as `Derivative`
** does, with `td/nd` as its time constant.  An execute that does not
** compute is a gap for `D` too: `D` holds and its filter starts again from
** there.
**
** Departures from MBL (the Modelica Buildings Library): `yReset` defaults
** to 0, where CDL defaults it to `xi_start`, a `k` below 1E-13 faults,
** equal `yMin` and `yMax` give that value where MBL rejects them, and
** parameters are checked only for the terms the controller type uses.
**
** A null `inSetpoint` or `inMeasurement` sets `out` to null and an invalid
** one holds the state and `out`.  A fault holds the state and shows the
** last `out`, or NaN, with fault.  An infinite `yMin` or `yMax` is no
** limit on that side, as `Pid` takes any limits.  These settings fault: a
** NaN `yMin` or `yMax`, `yMin` above `yMax`, equal infinite `yMin` and
** `yMax`, an `r` below 1E-13, for PI and PID a `ti` or `ni` below 1E-13 or
** a non-finite `xiStart` or `yReset`, for PD and PID a `td` or `nd` below
** 1E-13 or a non-finite `ydStart`, and inputs with two units.  A non-finite
** valid input or result faults too.
**
@Gen
class CdlPid : HxComp
{
  ** The setpoint, CDL `u_s`
  @Gen virtual StatusNumber? inSetpoint() { get("inSetpoint") }

  ** The measurement, CDL `u_m`, in the unit of `inSetpoint`
  @Gen virtual StatusNumber? inMeasurement() { get("inMeasurement") }

  ** Resets the integrator when it turns true, CDL `trigger`.  Optional.
  @Gen virtual StatusBool? inReset() { get("inReset") }

  ** P, PI, PD or PID
  @Gen virtual PidControllerType controllerType { get {get("controllerType")} set {set("controllerType", it)} }

  ** The gain, CDL `k`.  Positive: use `reverseActing` for direction
  @Gen virtual Float k { get {get("k")} set {set("k", it)} }

  ** The time constant of the integrator, CDL `Ti`
  @Gen virtual Duration ti { get {get("ti")} set {set("ti", it)} }

  ** The time constant of the derivative, CDL `Td`
  @Gen virtual Duration td { get {get("td")} set {set("td", it)} }

  ** The typical range of the control error, CDL `r`
  @Gen virtual Float r { get {get("r")} set {set("r", it)} }

  ** The upper limit of `out`, CDL `yMax`
  @Gen virtual Float yMax { get {get("yMax")} set {set("yMax", it)} }

  ** The lower limit of `out`, CDL `yMin`
  @Gen virtual Float yMin { get {get("yMin")} set {set("yMin", it)} }

  ** `ni*ti` is the time constant of the anti-windup, CDL `Ni`
  @Gen virtual Float ni { get {get("ni")} set {set("ni", it)} }

  ** The higher `nd`, the more ideal the derivative, CDL `Nd`
  @Gen virtual Float nd { get {get("nd")} set {set("nd", it)} }

  ** The integrator value at the first execute, CDL `xi_start`
  @Gen virtual Float xiStart { get {get("xiStart")} set {set("xiStart", it)} }

  ** The derivative value at the first execute, CDL `yd_start`
  @Gen virtual Float ydStart { get {get("ydStart")} set {set("ydStart", it)} }

  ** True when a rise of `inMeasurement` lowers `out`
  @Gen virtual Bool reverseActing { get {get("reverseActing")} set {set("reverseActing", it)} }

  ** The output before the limits after a reset, CDL `y_reset`
  @Gen virtual Float yReset { get {get("yReset")} set {set("yReset", it)} }

  ** The control output, CDL `y`
  @Gen virtual StatusNumber? out() { get("out") }

  new make()
  {
  }

  private Bool initialized

  ** Integrator state, CDL I.y
  private Float xi

  ** Derivative filter state, CDL D.x
  private Float xd

  ** inReset at the last execute where it was valid
  private Bool lastReset

  ** A rise of inReset not yet taken by a computing execute
  private Bool pendingReset

  ** Last computed out, NaN before the first one
  private Float lastOut := Float.nan

  ** Last derivative term D, the value a gap holds
  private Float yd

  ** Did the last execute compute, or overflow on a normal step, so the
  ** next one may step the filter from its kept state
  private Bool valid

  ** One clock per term, so each judges a stall as `Integrator` and
  ** `Derivative` do
  private CycleClock clockI := CycleClock()
  private CycleClock clockD := CycleClock()

  ** CDL min = 100*Constants.eps on k, Ti, Td, r, Ni and Nd
  private static const Float minParam := 1E-13f

  ** CDL Constants.eps
  private static const Float eps := 1E-15f

  override Void onExecute()
  {
    // a PID moves with constant inputs, so execute on every cycle
    execute

    // consume the step whether or not this execute computes.  The
    // integral bounds a stall, and the derivative takes it as a gap,
    // since a slope across it would be invented.
    now := cx.now
    dtI := CycleClock.sec(clockI.bounded(clockI.step(now)))
    dtD := CycleClock.sec(clockD.step(now, CycleClock.ticks(secs(td) / nd)))
    gapD := clockD.stalled || !valid
    this.valid = false

    // latch a rise even while the comp does not compute.  A when clause
    // does not fire at init, so no rise before the first computing one.
    rs := inReset
    rv := rs != null && rs.status.isValid ? rs.val : null
    if (rv != null)
    {
      if (initialized && rv && !lastReset) this.pendingReset = true
      this.lastReset = rv
    }

    sp := inSetpoint
    me := inMeasurement
    if (sp == null || me == null) return set("out", null)

    type  := controllerType
    withI := type === PidControllerType.pi || type === PidControllerType.pid
    withD := type === PidControllerType.pd || type === PidControllerType.pid

    // configuration faults are checked before the invalid rule
    status := sp.status.merge(me.status)
    if (isFault(withI, withD, sp.num.unit, me.num.unit))
      return writeHeld(status.set(Status.fault))

    if (!status.isValid)
    {
      o := out
      if (o != null) set("out", StatusNumber(o.num, status))
      return
    }

    // PID.mo: errors scaled by revAct/r
    s   := sp.num.toFloat
    m   := me.num.toFloat
    rev := reverseActing ? 1f : -1f
    e   := rev * s / r - rev * m / r
    p   := k * e

    // Derivative.mo with k = k*Td and T = Td/Nd
    kd := k * secs(td)
    tf := (secs(td) / nd).max(100f * eps)

    // initial equations I.y = xi_start and D.x = u - T*y_start/k
    xi0 := initialized ? xi : xiStart
    xd0 := initialized ? xd : (kd.abs < eps ? e : e - tf * ydStart / kd)
    if (!initialized) { dtI = 0f; dtD = 0f; gapD = false }

    // derivative filter, backward Euler: x' = (e - x)/Tf.  Without D the
    // filter rests at e, in case D is switched on later.  On a gap D
    // holds and the filter starts again so it goes on from the held D.
    xd1 := e
    d   := 0f
    if (withD)
    {
      if (gapD)
      {
        d = yd
        xd1 = kd.abs < eps ? e : e - tf * d / kd
      }
      else
      {
        h := dtD / tf
        xd1 = (xd0 + h * e) / (1f + h)
        d = kd / tf * (e - xd1)
      }
    }

    // PIDWithReset.mo: when trigger then reinit(I.y, y_reset - (P + D))
    rise := pendingReset
    xi1  := xi0
    if (withI) xi1 = rise ? yReset - (p + d) : integrate(xi0, p + d, e, dtI)
    u := p + d + (withI ? xi1 : 0f)

    // a non-finite input or result faults and keeps the state.  xd1 is
    // checked too, since a filter restarted on a gap does not reach d.
    // As in Derivative, an overflow on a normal step is retried as a
    // step, while a non-finite input or a gap leaves the next one a gap.
    if (!finite(u) || !finite(xd1))
    {
      this.valid = !gapD && finite(s) && finite(m)
      return writeHeld(status.set(Status.fault))
    }

    this.initialized = true
    this.xi = xi1
    this.xd = xd1
    this.yd = d
    this.valid = true
    this.pendingReset = false
    y := u > yMax ? yMax : (u < yMin ? yMin : u)
    this.lastOut = y
    set("out", StatusNumber(Number(y), status))
  }

  ** IntegratorWithReset.mo der(y) = k/Ti * (e - (u - lim(u))/(k*Ni)) by
  ** backward Euler.  The implicit anti-windup term is piecewise linear
  ** in xi, so it is solved exactly: unlimited, at yMax, or at yMin.
  private Float integrate(Float xi0, Float pd, Float e, Float dt)
  {
    if (dt <= 0f) return xi0
    tiSecs := secs(ti)
    a  := dt * k / tiSecs
    b  := dt / (tiSecs * ni)
    xu := xi0 + a * e
    vu := pd + xu
    if (vu > yMax) return (xu + b * (yMax - pd)) / (1f + b)
    if (vu < yMin) return (xu + b * (yMin - pd)) / (1f + b)
    return xu
  }

  ** The asserts and min bounds of PID.mo, for the terms the type uses.
  ** Equal limits are allowed, and an infinite limit is no limit, but equal
  ** infinite limits would put an infinity into the state.
  private Bool isFault(Bool withI, Bool withD, Unit? su, Unit? mu)
  {
    if (yMin.isNaN || yMax.isNaN || yMin > yMax || (yMin == yMax && !finite(yMax))) return true
    if (!pos(k) || !pos(r)) return true
    if (withI && (!pos(secs(ti)) || !pos(ni) || !finite(xiStart) || !finite(yReset))) return true
    if (withD && (!pos(secs(td)) || !pos(nd) || !finite(ydStart))) return true
    return su != null && mu != null && su != mu
  }

  ** At least CDL's 100*eps and finite; false for NaN
  private static Bool pos(Float x) { x >= minParam && x < Float.posInf }

  private static Bool finite(Float x) { !x.isNaN && x != Float.posInf && x != Float.negInf }

  ** Write the last out, or NaN before the first one, with status
  private Void writeHeld(Status status)
  {
    set("out", StatusNumber(Number(lastOut), status))
  }

  private static Float secs(Duration d) { d.ticks.toFloat / 1E9f }
}

**
** The terms a CdlPid uses: P, PI, PD or PID
**
@Gen
enum class PidControllerType
{
  ** proportional
  p,

  ** proportional and integral
  pi,

  ** proportional and derivative
  pd,

  ** proportional, integral and derivative
  pid
}
