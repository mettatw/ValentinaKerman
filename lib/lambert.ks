// Lambert solver
// This file is translated from https://github.com/rodyo/FEX-Lambert/blob/master/lambert.m
// which is authored by Rody P.S. Oldenhuis <oldenhuis@luxspace.lu>
// and licensed under BSD license
@lazyglobal off.

runoncepath("lib/math").

// Also consider the target velocity:
// only find the "prograde" solution, without the need to reverse our flight path
function solveLambertLBPrograde { // (vel1, pos1, pos2, dt, mu, [round=0])
  parameter parPqwVel1.
  parameter parPqwPos1.
  parameter parPqwPos2.
  parameter parDt.
  parameter parMu.
  parameter parM is 0. // number of rounds

  if vdot(parPqwVel1, parPqwPos2) < 0 { // pos2 is in the "retrograde" half-sphere
    return solveLambertLB(parPqwPos1, parPqwPos2, -parDt, parMu, parM).
  } else {
    return solveLambertLB(parPqwPos1, parPqwPos2, parDt, parMu, parM).
  }
}

// Solver based on:
// Gooding, R.H. "A procedure for the solution of Lambert's orbital boundary-value 
// problem." Celestial Mechanics and Dynamical Astronomy, 1990
// Will return a list: [v1, v2]
// Will just return a single -1 if failed
// NOTE: I have no idea how this work at all...
function solveLambertLB { // (pos1, pos2, dt, mu, [round=0])
  parameter parPqwPos1.
  parameter parPqwPos2.
  parameter parDt.
  parameter parMu.
  parameter parM is 0. // number of rounds

  local r1 is parPqwPos1:mag.
  local r2 is parPqwPos2:mag.
  local unitPos1 is parPqwPos1:normalized.
  local unitPos2 is parPqwPos2:normalized.
  // Find tangent direction of these two position
  local plane is vcrs(parPqwPos1, parPqwPos2).
  local unitTan1 is vcrs(plane, unitPos1):normalized.
  local unitTan2 is vcrs(plane, unitPos2):normalized.
  // turn angle
  local dth is vang(parPqwPos1, parPqwPos2).

  local longway is 0.
  if parDt < 0 {
    set longway to 1. set parDt to -parDt.
    set dth to dth - 360.
  }

  // constants
  local c is sqrt(r1^2 + r2^2 - 2*r1*r2*cos(dth)).
  local s is (r1 + r2 + c) / 2.
  local T is sqrt(8*parMu/s^3) * parDt.
  local q is sqrt(r1*r2)/s * cos(dth/2).

  // some initial values
  local T0 is __LancasterBlanchard(0, q, parM)[0].
  local Td is T0 - T.
  local phr is mod(2*arctan2(1 - q^2, 2*q)*constant:degtorad, 2*constant:pi).

  // initial for single revolution case
  local x0 is 0.
  if parM = 0 {
    local x01 is T0*Td/4/T.
    if Td > 0 {
      set x0 to x01.
    } else {
      set x01 to Td/(4 - Td).
      local x02 is -sqrt( -Td/(T+T0/2) ).
      local W is x01 + 1.7*sqrt(2 - phr/constant:pi).
      local x03 is 0.
      if W >= 0 {
        set x03 to x01.
      } else {
        set x03 to x01 + (-W)^(1/16)*(x02 - x01).
      }
      local lambda is 1 + x03*(1 + x01)/2 - 0.03*x03^2*sqrt(1 + x01).
      set x0 to lambda*x03.
    }
        
    // this estimate might not give a solution
    if x0 < -1 { return -1. }.

  } else { // m>0
    print "Error: multi revolution not impemented.".
    return -1.
  }

  // (Halley's method)    
  local x is x0.
  local xp is x0.
  local Tx is 99999.
  from {local itr is 1.} until abs(Tx) < 1e-7 or itr > 12 step {set itr to itr+1.} do {
    local lb3 is __LancasterBlanchard(x, q, parM).
    local T1 is lb3[0].
    local T2 is lb3[1].
    local T3 is lb3[2].

    // find the root of the *difference* between the
    // function value [T_x] and the required time [T]
    set Tx to T1 - T.

    // previous value of x
    set xp to x.
    // main Halley
    set x to x - 2*Tx*T2 / (2*T2^2 - Tx*T3).
    //print itr + ": " + Tx.

    // escape clause??
    if mod(itr, 7) = 0 { set x to (xp+x)/2. }.
  }

  // constants required for this calculation
  local gamma is sqrt(parMu*s/2).
  local sigma is 0.
  local rho is 0.
  local z is 0.
  if c = 0 {
    set sigma to 1.
    set rho to 0.
    set z to abs(x).
  } else {
    set sigma to 2*sqrt(r1*r2/(c^2)) * sin(dth/2).
    set rho to (r1 - r2)/c.
    set z to sqrt(1 + q^2*(x^2 - 1)).
  }

  // Compute radial component
  local Vr1 is gamma*((q*z - x) - rho*(q*z + x)) / r1.
  local Vr2 is -gamma*((q*z - x) + rho*(q*z + x)) / r2.
  local Vt1 is sigma * gamma * (z + q*x) / r1.
  local Vt2 is sigma * gamma * (z + q*x) / r2.

  return list(
    Vr1*unitPos1 + Vt1*unitTan1,
    Vr2*unitPos2 + Vt2*unitTan2
  ).
}

// Return T, Tp, Tpp (two-order derivatives)
function __LancasterBlanchard {
  parameter parX.
  parameter parQ.
  parameter parM.

  // protection against idiotic input
  if parX < -1 { // impossible; negative eccentricity
    set parX to abs(parX) - 2.
  } else if parX = -1 { // impossible; offset x slightly
    set parX to parX + 1e-6.
  }

  local Ee is parX^2 - 1.

  if parX = 1 { // exactly parabolic; solutions known exactly
    return list(
      4/3*(1-parQ^3),
      4/5*(parQ^5-1),
      4/3*(1-parQ^3) + 120/70*(1-parQ^7)
    ).
  } else {
    local y is sqrt(abs(Ee)).
    local z is sqrt(1 + parQ^2*Ee).
    local f is y*(z - parQ*parX).
    local Gg is parX*z - parQ*Ee.

    local d is 0.
    if Ee < 0 {
      set d to arctan2(f, Gg)*constant:degtorad + constant:pi*parM.
    } else if Ee = 0 {
      set d to 0.
    } else {
      set d to ln(max(0.0001, f+Gg)). // prevent log 0 error
    }

    local T1 is 2*(parX - parQ*z - d/y)/Ee.
    local T2 is (4 - 4*parQ^3*parX/z - 3*parX*T1)/Ee.
    local T3 is (-4*parQ^3/z * (1 - parQ^2*parX^2/z^2) - 3*T1 - 3*parX*T2)/Ee.
    return list(T1, T2, T3).
  }
}
