#*** import the hotcodereloading stdlib module ***
import hotcodereloading
 # imports

proc update*() =
  # call to reload
  performCodeReload()

 # new globals

# proc newCode*() =
afterCodeReload:
  echo "Code start"
  let d = @[1,2,3]; echo d
  echo "ok"
