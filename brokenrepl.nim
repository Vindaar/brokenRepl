import replstore
import shell
import strutils, tables, os
import hotcodereloading

# BUG: rdstdin does not compile with HCR (or nimrtl?)
#import rdstdin

const replStart = """
#*** import the hotcodereloading stdlib module ***
import hotcodereloading
$# # imports

proc update*() =
  # call to reload
  performCodeReload()

$# # new globals
"""

const upCodeStart = """
# proc newCode*() =
afterCodeReload:
  echo "Code start"
  let d = @[1,2,3]; echo d
"""
template readStdin(line: untyped): untyped =
  stdout.write("> ")
  stdin.readLine(line)

writeFile("replstore.nim", replStart % ["", ""] & upCodeStart)


proc writeReplLine(tab: var Table[string, string], line: string) =
  tab["upProc"] = tab["upProc"] & "  " & line & "\n"
proc writeGlobal(tab: var Table[string, string], line: string) =
  tab["globals"] = tab["globals"] & line & "\n"
proc writeImports(tab: var Table[string, string], line: string) =
  tab["imports"] = tab["imports"] & line & "\n"

proc replFile(tab: Table[string, string]): string =
  result = tab["skel"] % [tab["imports"], tab["globals"]] & "\n" & tab["upProc"]

proc writeReplFile(tab: Table[string, string]) =
  var f = open("replstore.nim", fmWrite)
  echo "open"
  let content = replFile(tab)
  f.write(content)
  #f.write(file & "\n" & upProc & "\n" & globals)
  echo "write"
  f.close()
  echo "done"

#const validCheck = """
#import macros
#let x = parseStmt("$#")
#"""
const validCheck = """
import macros
macro t(): untyped =
  let x = parseStmt("$#")
t()
"""
proc lineValid(line: string): bool =
  var f = open("tmpValid.nim", fmWrite)
  f.write(validCheck % [line.replace("\"", "\\\"")])
  f.close()
  let res = shellVerbose:
    nim check tmpValid.nim
  result = res[1] == 0
  if not result:
    echo "Invalid input: ", line
    echo "Shell output: ", res[0]
    echo "Exit code: ", res[1]

#proc writeGlobal(line: string) =
#  var f = open("replstore.nim", fmAppend)
#  echo "open"
#  f.write(line & "\n")
#  echo "write"
#  f.close()
#  echo "done"


proc main() =
  var line = ""
  var file = replStart
  var filetab = initTable[string, string]()
  filetab["skel"] = replStart
  filetab["globals"] = ""
  filetab["upProc"] = upCodeStart
  filetab["imports"] = ""
  var oldWorking = filetab
  while readStdin(line):
    if line == "quit":
      break
    # dump line to replstore.nim
    # check validity of line
    if lineValid(line):
      if "echo" in line:
        writeReplLine(filetab, line)
      elif "let" in line or "var" in line or "proc" in line:
        #writeReplLine(upProc, line)# & "; echo " & $line[4])
        writeGlobal(filetab, line)# & "; echo " & $line[4])
      elif "import" in line:
        writeImports(filetab, line)
      else:
        writeReplLine(filetab, line)
      writeReplFile(filetab)
      let res = shellVerbose:
        # can also just recompile `replstore.nim`, but then we have to call `newCode` to run
        # stuff. HCR otherwise thinks there was no change
        nim c "--hotcodereloading:on" brokenrepl.nim # replstore.nim
      if res[1] != 0:
        echo "Invalid last entry: ", res[1], " ", res[0]
        filetab = oldWorking
        copyFile("repl.nim", "repl_broken.nim")
        writeReplFile(filetab)
      else:
        oldWorking = filetab
        performCodeReload()
        #update()
        # now call new code
        #newCode()

main()
