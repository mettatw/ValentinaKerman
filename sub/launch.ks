@lazyglobal off.

runoncepath("lib/maneuver").
runoncepath("lib/ship").

// Basic launch + gravity turn
function doLaunchAndGravityTurn {
  parameter parHeight. // in meter
  parameter parHeading is 90.

  // Speed to start the initial turn
  local spdTurnBegin is 2.
  if body:atm:exists {
    // heuristic, may not work on non-kerbin...
    set spdTurnBegin to body:atm:sealevelpressure / 3.
  }

  // Altitude for 45-degree turn
  local altAt45 is parHeight / 4.
  if body:atm:exists {
    // heuristic, may not work on some planet...
    set altAt45 to body:atm:sealevelpressure * 100.
  }

  local altAt0 is parHeight / 2.
  if body:atm:exists {
    // heuristic, may not work on some planet...
    set altAt0 to body:atm:height*0.65.
  }

  function findDeltaETA {
    if eta:periapsis < eta:apoapsis { // we're in trouble, obviously...
      return -30 - (eta:apoapsis - eta:periapsis).
    }
    return eta:apoapsis - 40.
  }

  print "----> LAUNCH alt=" + round(parHeight/1000, 1) + "km".

  set ship:control:pilotmainthrottle to 1.
  sas off.
  rcs off.

  // Variables used in main control loop
  local altTurnBegin is -1.
  local ourSteer is headingUp(0, 90).
  lock steering to ourSteer.
  // Throttle control, setpoint is dETA=0, output is dScaleThrottle
  local pidThrottle is pidLoop(0.05, 0, 0.01, -1, 1).
  set pidThrottle:setpoint to 0.
  // Pitch control, setpoint is dETA=0, output is dPitch
  local pidInvPitch is pidLoop(0.3, 0, 0.05, -10, 10).
  set pidInvPitch:setpoint to 0.

  // Main control loop
  local runMode is 1.
  until runMode = 0 {

    // 1: before gravity turn
    if runMode = 1 {
      if ship:verticalspeed >= spdTurnBegin {
        print "Start turn at alt " + round(ship:altitude/1000,2) + "km".
        set altTurnBegin to ship:altitude.
        set runMode to 2.
      }
    }


    // Common variables for phase 2 and 3
    local angleBaseline is 90. // What angle to add/sub deltas from. This is the deviation from up vector
    local minThrottle is 1. // Minimum possible thrust
    local maxAngle is 90.
    local dAngleMultiplier is 1.

    // 2: turn to 45 degree before specified altitude
    if runMode = 2 {
      if ship:altitude >= altAt45 {
        print "45-degree at alt " + round(ship:altitude/1000,2) + "km".
        set runMode to 3.
      } else {
        set angleBaseline to 45*(ship:altitude - altTurnBegin)/(altAt45 - altTurnBegin).
        set minThrottle to 0.5.
        set maxAngle to 45.
        set dAngleMultiplier to max(0, (ship:altitude - altTurnBegin)/(altAt45 - altTurnBegin)-0.25).
      }
    }

    // 3: turn to 0 degree before specified altitude
    if runMode = 3 {
      if ship:altitude >= altAt0 {
        print "0-degree at alt " + round(ship:altitude/1000,2) + "km".
        set runMode to 4.
      } else {
        set angleBaseline to 45 + 45*(ship:altitude - altAt45)/(altAt0 - altAt45).
        set minThrottle to 0.4.
      }
    }

    // 4: waiting for apoapsis
    if runMode = 4 {
      if ship:orbit:apoapsis >= parHeight {
        print "Apo reached at alt " + round(ship:altitude/1000,2) + "km".
        set runMode to 0.
      } else {
        set angleBaseline to 90.
        set minThrottle to 0.3.
      }

    } // end runMode branch

    // Common Logic: When out of thrust, just stage
    if runMode <> 0 {
      if ship:availablethrust <= 0 and stage:ready {
        stage.
        wait 0.1.
      }
    }

    // Common Logic: throttle / steering control
    if runMode >= 2 {
      local dETA is findDeltaETA().
      local twrMax is ship:availablethrust / ship:mass
        / (body:mu / (ship:altitude+body:radius)^2).

      // Throttle control
      if twrMax > 0 {
        local scaleThrottle is pidThrottle:update(time:seconds, dETA)/2+0.5. // normalize to 0~1
        set ship:control:pilotmainthrottle to (1.5/twrMax) + scaleThrottle*(twrMax-1.5)/twrMax.
        set ship:control:pilotmainthrottle to max(minThrottle, ship:control:pilotmainthrottle).
      }

      // Steering control
      local angleSteer is angleBaseline.
      local angleDelta is -pidInvPitch:update(time:seconds, dETA).
      if angleDelta > 0 {
        set angleSteer to angleBaseline + dAngleMultiplier * angleDelta/2.
      } else {
        set angleSteer to angleBaseline + dAngleMultiplier * angleDelta*2.
      }
      if runMode >= 3 and dETA < -25 { // for safety
        set angleSteer to angleSteer + dETA*1.5.
      }
      set angleSteer to min(maxAngle, angleSteer).
      set angleSteer to max(0, angleSteer).
      set ourSteer to headingUp(parHeading, 90 - angleSteer).
    }

    wait 0.01.
  } // end control loop

  wait until ship:orbit:apoapsis >= parHeight.
  lock steering to lookdirup(ship:velocity:surface, ship:facing:topvector).

  // Just warp until we're out of atmo
  set ship:control:pilotmainthrottle to 0.
  wait 0.2.
  set kuniverse:timewarp:mode to "PHYSICS".
  set kuniverse:timewarp:warp to 3.

  // Adjusting burns
  lock throttle to min(1, max(0, parHeight - ship:orbit:apoapsis + 200)/5000). // full throttle for 4.8km error

  wait until ship:altitude > body:atm:height.
  unlock throttle.
  print "Out of atmo, apo error " + round(ship:orbit:apoapsis - parHeight) + "m".

  set kuniverse:timewarp:mode to "RAILS".
  set kuniverse:timewarp:warp to 0.

  // When out of atmo, check apo again, and continue burn if needed
  if ship:orbit:apoapsis < parHeight {
    lock steering to lookdirup(ship:velocity:orbit, ship:facing:topvector).
    wait 5. // necessary, or it refuse to start when just right out of warping
    set ship:control:pilotmainthrottle to 0.5.
    print "Start refining burn".
    wait until ship:orbit:apoapsis >= parHeight.
  }

  // Ending
  set ship:control:pilotmainthrottle to 0.
  unlock steering.

  planChangeAltitude(180, ship:orbit:apoapsis). // circularize maneuver node
}

