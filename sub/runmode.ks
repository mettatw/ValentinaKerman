// Execute node script
@lazyglobal off.

function mainLoopRoot {
  parameter parLexProgram. // an lexicon of number -> [desc, func]

  if ship:rootpart:tag = "" {
    set ship:rootpart:tag to "0".
  }

  local maxMode is 0.
  for i in parLexProgram:keys {
    if i > maxMode {set maxMode to i.}.
  }

  print "====> BEGIN AT " + ship:rootpart:tag.

  until ship:rootpart:tag:tonumber > maxMode {
    if parLexProgram:haskey(ship:rootpart:tag:tonumber) {
      local thisPair is parLexProgram[ship:rootpart:tag:tonumber].
      print "". // empty line
      print "====> RUN " + ship:rootpart:tag + " " + thisPair[0].
      thisPair[1]().
    }

    set ship:rootpart:tag to (ship:rootpart:tag:tonumber + 1):tostring.
  }
}

function addRMStdLaunch { // (lex, num, km, azimuth)
  parameter parLexProgram.
  parameter parStartNum.
  parameter parAltitudeInKm.
  parameter parAzimuth is 90.

  set parLexProgram[parStartNum] to list("Pre-launch countdown", {
    print "Ready to launch T-15".
    from {local i is 15.} until i = 0 step {set i to i-1.} do {
      if i<=5 or i=10 { print i. }.
      wait 1.
    }
  }).

  set parLexProgram[parStartNum+10] to list("Launch", {
    doLaunchAndGravityTurn(parAltitudeInKm*1000, parAzimuth).
  }).

}

function addRMStdManu { // (lex, num, desc, maneuver-method, plan-func)
  parameter parLexProgram.
  parameter parStartNum.
  parameter parDesc.
  parameter parMethod. // 0=wait, 1=warp
  parameter parFunc.

  set parLexProgram[parStartNum] to list("Plan " + parDesc, parFunc).
  set parLexProgram[parStartNum+10] to list("Exec " + parDesc, {
    if not hasnode {
      set ship:rootpart:tag to parStartNum:tostring.
      reboot.
    }
    runNode(parMethod).
  }).
}
