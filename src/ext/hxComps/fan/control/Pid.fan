//
// Copyright (c) 2026, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   19 Oct 2026  Jason Briggs  Creation
//

using xeto
using haystack

**
** A PID control loop.It drives out to hold controlledVariable at setpoint:
**
**   error = controlledVariable - setpoint    (direct)
**   error = setpoint - controlledVariable    (reverse)
**   out   = bias + Kp * (error + Ki * ∫error dt + Kd * d(error)/dt)
**
** Ki is in repeats per minute and Kd is in seconds. The loop runs only at
** freq, not when an input changes. Out is held between minimumOutput and
** maximumOutput, and the integral stops growing while out is held at a
** limit. Changing Kp or Ki does not bump out.
**
** If controlledVariable or setpoint has an invalid status, or is NaN or
** infinite, then out and the integral hold their last values and the input
** status is propagated to out (fault for NaN or infinite). When loopEnable
** is false, out is set by disableAction and the loop resumes from that
** value when it is enabled again.
**
@Gen
class Pid : HxComp
{
  ** The loop output, between minimumOutput and maximumOutput
  @Gen virtual StatusNumber? out() { get("out") }

  ** The value being controlled, such as a discharge air temp
  @Gen virtual StatusNumber? controlledVariable { get {get("controlledVariable")} set {set("controlledVariable", it)} }

  ** The value the loop holds controlledVariable at
  @Gen virtual StatusNumber? setpoint { get {get("setpoint")} set {set("setpoint", it)} }

  ** False or an invalid status disables the loop; unlinked it runs
  @Gen virtual StatusBool? loopEnable { get {get("loopEnable")} set {set("loopEnable", it)} }

  ** Direct raises out as controlledVariable rises above setpoint;
  ** reverse raises out as it falls below
  @Gen virtual PidAction loopAction { get {get("loopAction")} set {set("loopAction", it)} }

  ** What out is set to while the loop is disabled
  @Gen virtual PidDisableAction disableAction { get {get("disableAction")} set {set("disableAction", it)} }

  ** Proportional gain (Kp)
  @Gen virtual Float proportionalConstant { get {get("proportionalConstant")} set {set("proportionalConstant", it)} }

  ** Integral gain (Ki) in repeats per minute; 0 turns it off
  @Gen virtual Float integralConstant { get {get("integralConstant")} set {set("integralConstant", it)} }

  ** Derivative gain (Kd) in seconds; 0 turns it off
  @Gen virtual Float derivativeConstant { get {get("derivativeConstant")} set {set("derivativeConstant", it)} }

  ** Out when the error is zero and nothing has been integrated
  @Gen virtual Float bias { get {get("bias")} set {set("bias", it)} }

  ** The highest out may go
  @Gen virtual Float maximumOutput { get {get("maximumOutput")} set {set("maximumOutput", it)} }

  ** The lowest out may go
  @Gen virtual Float minimumOutput { get {get("minimumOutput")} set {set("minimumOutput", it)} }

  ** How often the loop runs
  @Gen virtual Duration freq { get {get("freq")} set {set("freq", it)} }

  ** Integral term in output units: the running sum of Kp * Ki * error * dt.
  ** Keeping it in output units means a change to Kp or Ki does not bump out.
  private Float integral := 0f

  ** Error and time of the last run, for dt and the derivative
  private Float? lastErr
  private Int? lastTicks

  override Duration? onExecuteFreq()
  {
    freq := this.freq
    if (freq == 0sec) return null
    return freq
  }

  ** The loop runs only on the freq timer, never because a slot changed
  override Void onChangeFw(CompChangeEvent e) {}

  override Void onChange(CompChangeEvent e)
  {
    // ensure the loop runs at most once a second
    if ("freq" == e.name && freq < 1sec) freq = 1sec
  }

  override Void onExecute()
  {
    cv := controlledVariable
    sp := setpoint
    enable := loopEnable

    // disabled: out is set by disableAction
    if (enable != null && (!enable.bool || !enable.status.isValid)) return disabled(enable, cv, sp)

    // if either input is unlinked, out is null
    if (cv == null || sp == null) { reset; return set("out", null) }

    // an invalid, NaN, or infinite input holds out and the integral,
    // and the next good run starts fresh so the gap is not integrated
    status := cv.status.merge(sp.status).merge(enable?.status)
    if (!isFinite(cv) || !isFinite(sp)) status = status.set(Status.fault)
    if (!status.isValid)
    {
      lastErr = null
      lastTicks = null
      return set("out", StatusNumber(out?.num ?: Number(minimumOutput), status))
    }

    // error, signed so a positive error raises out
    err := loopAction == PidAction.direct
      ? cv.num.toFloat - sp.num.toFloat
      : sp.num.toFloat - cv.num.toFloat

    // minutes since the last run; the first run has none
    now := cx.now.ticks
    dt := lastTicks == null ? 0f : (now - lastTicks).toFloat / 1min.ticks.toFloat

    kp  := proportionalConstant
    ki  := integralConstant
    max := maximumOutput
    min := minimumOutput

    // proportional and derivative terms; Kd is in seconds
    p := kp * err
    d := dt > 0f && lastErr != null ? kp * derivativeConstant * (err - lastErr) / (dt * 60f) : 0f

    // integrate only with an integral gain, but never past the
    // amount that puts out at a limit (anti-windup)
    if (ki == 0f)
    {
      integral = 0f
    }
    else
    {
      prev := integral
      integral += kp * ki * err * dt
      v := bias + p + integral + d
      if (v > max && integral > prev) integral = (max - bias - p - d).max(prev)
      if (v < min && integral < prev) integral = (min - bias - p - d).min(prev)
    }

    // out, held between the limits
    v := bias + p + integral + d
    if (v > max) v = max
    if (v < min) v = min

    // two runs at the same instant leave dt and the derivative alone
    if (dt > 0f || lastTicks == null) { lastErr = err; lastTicks = now }

    set("out", StatusNumber(Number(v), status))
  }

  ** Set out by disableAction and preload the integral so the loop
  ** resumes from that value when it is enabled again
  private Void disabled(StatusBool enable, StatusNumber? cv, StatusNumber? sp)
  {
    Float? v := null
    switch (disableAction)
    {
      case PidDisableAction.zero:     v = 0f
      case PidDisableAction.hold:     v = out?.num?.toFloat
      case PidDisableAction.minValue: v = minimumOutput
      case PidDisableAction.maxValue: v = maximumOutput
    }

    reset
    if (v == null) return set("out", null)
    integral = v - bias
    set("out", StatusNumber(Number(v), enable.status.merge(cv?.status).merge(sp?.status)))
  }

  ** Clear the integral and the last run
  private Void reset()
  {
    integral  = 0f
    lastErr   = null
    lastTicks = null
  }

  private static Bool isFinite(StatusNumber x)
  {
    f := x.num.toFloat
    return !f.isNaN && f != Float.posInf && f != Float.negInf
  }
}

**************************************************************************
** PidAction
**************************************************************************

**
** Which way a Pid drives out
**
@Gen
enum class PidAction
{
  ** Out rises as controlledVariable rises above setpoint (cooling)
  direct,

  ** Out rises as controlledVariable falls below setpoint (heating)
  reverse
}

**************************************************************************
** PidDisableAction
**************************************************************************

**
** What a Pid sets out to while the loop is disabled
**
@Gen
enum class PidDisableAction
{
  ** Out is set to zero
  zero,

  ** Out keeps its last value
  hold,

  ** Out is set to minimumOutput
  minValue,

  ** Out is set to maximumOutput
  maxValue
}
