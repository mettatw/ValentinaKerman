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
