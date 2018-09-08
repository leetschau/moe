import os
import sequtils
import terminal
import strformat
import strutils
import editorstatus
import ui
import fileutils
import editorview
import gapbuffer
import exmode
import unicodeext

proc deleteFile(status: var EditorStatus, dirList: seq[(PathComponent, string)], currentLine: int) =
  let command = getCommand(status.commandWindow, proc (window: var Window, command: seq[Rune]) =
    window.erase
    window.write(0, 0, fmt"Delete file? 'y' or 'n': {$command}")
    window.refresh
  )

  if (command[0] == ru"y" or command[0] == ru"yes") and command.len == 1:
    if dirList[currentLine][0] == pcDir:
      removeDir(dirList[currentLine][1])
    else:
      removeFile(dirList[currentLine][1])
  else:
    return

  status.commandWindow.erase
  status.commandWindow.write(0, 0, "Deleted "&dirList[currentLine][1])
  status.commandWindow.refresh

proc refreshDirList(): seq[(PathComponent, string)] =
  result = @[(pcDir, "../")]
  for list in walkDir("./"):
    result.add list

proc writeFileNameCurrentLine(win: var Window, dirList: seq[(PathComponent, string)], currentLine, startIndex: int) =
  win.write(currentLine, 0, substr(dirList[currentLine + startIndex][1], 2), brightWhiteGreen)

proc writeDirNameCurrentLine(win: var Window, dirList: seq[(PathComponent, string)], currentLine, startIndex: int) =
  if currentLine == 0 and startIndex == 0:    # "../"
    win.write(currentLine, 0, dirList[currentLine][1], brightWhiteGreen)
  else:
    win.write(currentLine, 0, substr(dirList[currentLine + startIndex][1], 2) & "/", brightWhiteGreen)

proc writePcLinkToDirNameCurrentLine(win: var Window, dirList: seq[(PathComponent, string)], currentLine, startIndex: int) =
  win.write(currentLine, 0, substr(dirList[currentLine + startIndex][1], 2) & "@", whiteCyan)

proc writeFileNameHalfwayCurrentLine(win: var Window, dirList: seq[(PathComponent, string)], currentLine, startIndex: int) =
  win.write(currentLine, 0, substr(dirList[currentLine + startIndex][1], 2, terminalWidth() - 2), brightWhiteGreen)

proc writeDirNameHalfwayCurrentLine(win: var Window, dirList: seq[(PathComponent, string)], currentLine, startIndex: int) =
  if currentLine== 0:    # "../"
    win.write(currentLine, 0, substr(dirList[currentLine][1], 2, terminalWidth() - 2), brightWhiteGreen)
  else:
    win.write(currentLine, 0, substr(dirList[currentLine + startIndex][1], 2, terminalWidth() - 2) & "/~", brightWhiteGreen)

proc writePcLinkToDirNameHalfwayCurrentLine(win: var Window, dirList: seq[(PathComponent, string)], currentLine, startIndex: int) =
  win.write(currentLine, 0, substr(dirList[currentLine + startIndex][1], 2, terminalWidth() - 2) & "@~", whiteCyan)

proc writeFileName(win: var Window, index, startIndex: int, dirList: seq[(PathComponent, string)]) =
  win.write(index, 0, substr(dirList[index + startIndex][1], 2))

proc writeDirName(win: var Window, index, startIndex: int, dirList: seq[(PathComponent, string)]) =
  if index == 0:    # "../"
    win.write(index, 0, dirList[index][1], brightGreenDefault)
  else:
    win.write(index, 0, substr(dirList[index + startIndex][1], 2) & "/", brightGreenDefault)

proc writePcLinkToDirName(win: var Window, index, startIndex: int, dirList: seq[(PathComponent, string)]) =
  win.write(index, 0, substr(dirList[index + startIndex][1], 2) & "@", cyanDefault)

proc writeFileNameHalfway(win: var Window, index, startIndex: int, dirList: seq[(PathComponent, string)]) =
  win.write(index, 0, substr(dirList[index + startIndex][1], 2, terminalWidth() - 2) & "~")

proc writeDirNameHalfway(win: var Window, index, startIndex: int, dirList: seq[(PathComponent, string)]) =
  if index == 0:    # "../"
    win.write(index, 0, substr(dirList[index][1], 0, terminalWidth() - 2) & "~", brightGreenDefault)
  else:
    win.write(index, 0, substr(dirList[index + startIndex][1], 2, terminalWidth() - 2) & "/~", brightGreenDefault)

proc writePcLinkToDirNameHalfway(win: var Window, index, startIndex: int, dirList: seq[(PathComponent, string)]) =
  win.write(index, 0, substr(dirList[index + startIndex][1], 2, terminalWidth() - 2) & "@~", cyanDefault)


proc writeFillerView(win: var Window, dirList: seq[(PathComponent, string)], currentLine, startIndex: int) =

  for i in 0 ..< dirList.len - startIndex:
    let index = i
    if dirList[index][1].len > terminalWidth():
      if dirList[index][0] == pcFile:
        writeFileNameHalfway(win, index, startIndex, dirList)
      elif dirList[index][0] == pcDir:
        writeDirNameHalfway(win, index, startIndex, dirList)
      elif dirList[index][0] == pcLinkToDir or dirList[i][0] == pcLinkToFile:
        writePcLinkToDirNameHalfway(win, index, startIndex, dirList)
    else:
      if dirList[index + startIndex][0] == pcFile:
        writeFileName(win, index, startIndex, dirList)
      elif dirList[index + startIndex][0] == pcDir:
        writeDirName(win, index, startIndex, dirList)
      elif dirList[index + startIndex][0] == pcLinkToDir or dirList[index + startIndex][0] == pcLinkToFile:
        writePcLinkToDirName(win, index, startIndex, dirList)

  # write current line
  if dirList[currentLine][1].len > terminalWidth():
    if dirList[currentLine][0] == pcFile:
      writeFileNameHalfwayCurrentLine(win, dirList, currentLine, startIndex)
    elif dirList[currentLine][0] == pcDir:
      writeDirNameHalfwayCurrentLine(win, dirList, currentLine, startIndex)
    elif dirList[currentLine][0] == pcLinkToDir or dirList[currentLine][0] == pcLinkToFile:
      writePcLinkToDirNameHalfwayCurrentLine(win, dirList, currentLine, startIndex)
  else:
    if dirList[currentLine][0] == pcFile:
      writeFileNameCurrentLine(win, dirList, currentLine, startIndex)
    elif dirList[currentLine][0] == pcDir:
      writeDirNameCurrentLine(win, dirList, currentLine, startIndex)
    elif dirList[currentLine][0] == pcLinkToDir or dirList[currentLine][0] == pcLinkToFile:
      writePcLinkToDirNameCurrentLine(win, dirList, currentLine, startIndex)
    
  win.refresh

proc filerMode*(status: var EditorStatus) =
  setCursor(false)
  var viewUpdate = true
  var DirlistUpdate = true
  var dirList = newSeq[(PathComponent, string)]()
  var currentLine = 0
  var startIndex = 0

  while status.mode == Mode.filer:
    if DirlistUpdate:
      dirList = @[]
      dirList.add refreshDirList()
      viewUpdate = true
      DirlistUpdate = false

    if viewUpdate:
      status.mainWindow.erase
      writeStatusBar(status)
      status.mainWindow.writeFillerView(dirList, currentLine, startIndex)
      viewUpdate = false

    let key = getKey(status.mainWindow)
    if key == ord(':'):
      status.changeMode(Mode.ex)
    elif isResizekey(key):
      status.resize(terminalHeight(), terminalWidth())
      viewUpdate = true

    elif key == 'D':
      deleteFile(status, dirList, currentLine)
      DirlistUpdate = true
      viewUpdate = true
    elif (key == 'j' or isDownKey(key)) and currentLine + startIndex < dirList.len - 1:
      if currentLine == terminalHeight() - 3:
        inc(startIndex)
      else:
        inc(currentLine)
      viewUpdate = true
    elif (key == ord('k') or isUpKey(key)) and (0 < currentLine or 0 < startIndex):
      if 0 < startIndex and currentLine == 0:
        dec(startIndex)
      else:
        dec(currentLine)
      viewUpdate = true
    elif key  == ord('g'):
      currentLine = 0
      startIndex = 0
      viewUpdate = true
    elif isEnterKey(key):
      if dirList[currentLine][0] == pcFile:
        status = initEditorStatus()
        status.filename = substr(dirList[currentLine][1], 2).toRunes
        status.buffer = openFile(status.filename)
        status.view = initEditorView(status.buffer, terminalHeight()-2, terminalWidth()-status.buffer.len.intToStr.len-2)
        setCursor(true)
      elif dirList[currentLine][0] == pcDir:
        setCurrentDir(dirList[currentLine][1])
        currentLine = 0
        DirlistUpdate = true
      elif dirList[currentLine][0] == pcLinkToDir:
        setCurrentDir(expandsymLink(dirList[currentLine][1]))
        currentLine = 0
        DirlistUpdate = true
      elif dirList[currentLine][0] == pcLinkToFile:
        status = initEditorStatus()
        status.filename = toRunes(expandsymLink(dirList[currentLine][1]))
        status.buffer = openFile(status.filename)
        status.view = initEditorView(status.buffer, terminalHeight()-2, terminalWidth()-status.buffer.len.intToStr.len-2)
        setCursor(true)
  setCursor(true)
