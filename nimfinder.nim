## NimFinder - JXL Image Converter and Viewer
## A cross-platform tool for converting images to JPEG XL and viewing JXL files

import nigui
import std/[os, osproc, strutils, strformat]

# Constants
const
  AppTitle = "NimFinder - JXL Image Tool"
  DefaultQuality = 85
  SupportedInputFormats = [".png", ".jpg", ".jpeg", ".gif", ".bmp", ".ppm", ".pgm"]
  JxlExtension = ".jxl"

# Global state
var
  currentImagePath: string = ""
  tempDecodedPath: string = ""
  qualityValue: int = DefaultQuality
  loadedImage: Image = nil

# Check if libjxl tools are available
proc checkJxlTools(): bool =
  try:
    let cjxlResult = execCmd("cjxl --version >nul 2>&1")
    let djxlResult = execCmd("djxl --version >nul 2>&1")
    result = cjxlResult == 0 and djxlResult == 0
  except OSError:
    result = false

# Convert an image to JXL format
proc convertToJxl(inputPath: string, quality: int): tuple[success: bool,
    outputPath: string, message: string] =
  let outputPath = inputPath.changeFileExt(JxlExtension)
  let qualityArg = "-q " & $quality
  let cmd = "cjxl " & quoteShell(inputPath) & " " & quoteShell(outputPath) &
      " " & qualityArg

  let (output, exitCode) = execCmdEx(cmd)
  if exitCode == 0:
    result = (true, outputPath, "Successfully converted to: " & outputPath)
  else:
    result = (false, "", "Conversion failed: " & output)

# Decode a JXL file to a temporary PNG for viewing
proc decodeJxlToTemp(jxlPath: string): tuple[success: bool, tempPath: string,
    message: string] =
  let tempDir = getTempDir()
  let tempPath = tempDir / "nimfinder_preview_" & extractFilename(
      jxlPath).changeFileExt(".png")
  let cmd = "djxl " & quoteShell(jxlPath) & " " & quoteShell(tempPath)

  let (output, exitCode) = execCmdEx(cmd)
  if exitCode == 0:
    result = (true, tempPath, "Decoded JXL successfully")
  else:
    result = (false, "", "Decoding failed: " & output)

# Check if file is a JXL
proc isJxlFile(path: string): bool =
  path.toLowerAscii().endsWith(JxlExtension)

# Check if file is a supported input format
proc isSupportedInput(path: string): bool =
  let ext = path.toLowerAscii().splitFile().ext
  ext in SupportedInputFormats

# Clean up temporary files
proc cleanup() =
  if tempDecodedPath.len > 0 and fileExists(tempDecodedPath):
    try:
      removeFile(tempDecodedPath)
    except:
      discard

# Format file size nicely
proc formatSize(bytes: BiggestInt): string =
  if bytes > 1024*1024:
    result = fmt"{bytes div (1024*1024)} MB"
  elif bytes > 1024:
    result = fmt"{bytes div 1024} KB"
  else:
    result = fmt"{bytes} bytes"

# Main application
proc main() =
  # Check for libjxl tools
  if not checkJxlTools():
    app.init()
    let errWin = newWindow(AppTitle & " - Error")
    errWin.width = 500
    errWin.height = 180

    let errContainer = newLayoutContainer(Layout_Vertical)
    errContainer.padding = 20
    errWin.add(errContainer)

    let errLabel = newLabel("Error: libjxl tools (cjxl, djxl) not found in PATH.")
    errContainer.add(errLabel)

    let errLabel2 = newLabel("Please install libjxl from:")
    errContainer.add(errLabel2)

    let errLabel3 = newLabel("https://github.com/libjxl/libjxl/releases")
    errContainer.add(errLabel3)

    errWin.show()
    app.run()
    return

  # Initialize NiGui
  app.init()

  # Create main window
  let window = newWindow(AppTitle)
  window.width = 900
  window.height = 700

  # Main vertical layout
  let mainContainer = newLayoutContainer(Layout_Vertical)
  mainContainer.padding = 10
  mainContainer.spacing = 10
  window.add(mainContainer)

  # Top toolbar row 1
  let toolbar = newLayoutContainer(Layout_Horizontal)
  toolbar.spacing = 10
  mainContainer.add(toolbar)

  # Open button
  let openButton = newButton("Open Image")
  openButton.minWidth = 110
  toolbar.add(openButton)

  # Quality label and input
  let qualityLabel = newLabel("Quality:")
  toolbar.add(qualityLabel)

  let qualityInput = newTextBox($DefaultQuality)
  qualityInput.minWidth = 50
  qualityInput.maxWidth = 60
  toolbar.add(qualityInput)

  let qualityHint = newLabel("(1-100)")
  toolbar.add(qualityHint)

  # Convert button
  let convertButton = newButton("Convert to JXL")
  convertButton.minWidth = 130
  convertButton.enabled = false
  toolbar.add(convertButton)

  # Image preview area - using a Control with onDraw
  let previewControl = newControl()
  previewControl.widthMode = WidthMode_Expand
  previewControl.heightMode = HeightMode_Expand
  mainContainer.add(previewControl)

  # Draw handler for the preview control
  previewControl.onDraw = proc(event: DrawEvent) =
    let canvas = event.control.canvas

    # Fill with dark background
    canvas.areaColor = rgb(40, 44, 52)
    canvas.fill()

    if loadedImage != nil:
      # Center the image in the control
      let ctrlW = event.control.width
      let ctrlH = event.control.height
      let imgW = loadedImage.width
      let imgH = loadedImage.height

      # Calculate scaling to fit
      let scaleX = ctrlW.float / imgW.float
      let scaleY = ctrlH.float / imgH.float
      let scale = min(min(scaleX, scaleY), 1.0)           # Don't upscale

      let drawW = int(imgW.float * scale)
      let drawH = int(imgH.float * scale)
      let x = (ctrlW - drawW) div 2
      let y = (ctrlH - drawH) div 2

      # Draw the image scaled
      canvas.drawImage(loadedImage, x, y, drawW, drawH)
    else:
      # Draw placeholder text
      canvas.textColor = rgb(150, 150, 150)
      canvas.fontSize = 16
      let text = "Open an image to preview it here"
      let textW = canvas.getTextWidth(text)
      let x = (event.control.width - textW) div 2
      let y = event.control.height div 2
      canvas.drawText(text, x, y)

  # Status bar
  let statusBar = newLayoutContainer(Layout_Horizontal)
  statusBar.spacing = 10
  mainContainer.add(statusBar)

  let statusLabel = newLabel("Ready - Supports PNG, JPG, GIF, BMP. Open a JXL to view it.")
  statusBar.add(statusLabel)

  # Helper to load and display an image
  proc loadAndDisplayImage(imagePath: string) =
    if imagePath.len == 0 or not fileExists(imagePath):
      statusLabel.text = "Error: File not found"
      return

    try:
      # Free old image if exists
      if loadedImage != nil:
        loadedImage = nil

      # Load new image
      loadedImage = newImage()
      loadedImage.loadFromFile(imagePath)

      # Force redraw
      previewControl.forceRedraw()

      # Update file info
      let fileSize = getFileSize(imagePath)
      statusLabel.text = fmt"Loaded: {extractFilename(imagePath)} ({formatSize(fileSize)}) - {loadedImage.width}x{loadedImage.height}"
    except CatchableError as e:
      statusLabel.text = "Error loading image: " & e.msg

  # Open button handler
  openButton.onClick = proc(event: ClickEvent) =
    let dialog = newOpenFileDialog()
    dialog.title = "Open Image"
    dialog.multiple = false
    dialog.run()

    if dialog.files.len > 0:
      let selectedPath = dialog.files[0]

      # Clean up previous temp file
      cleanup()

      if isJxlFile(selectedPath):
        # Decode JXL for viewing
        statusLabel.text = "Decoding JXL file..."
        let (success, decodedPath, message) = decodeJxlToTemp(selectedPath)

        if success:
          currentImagePath = selectedPath
          tempDecodedPath = decodedPath
          loadAndDisplayImage(decodedPath)
          convertButton.enabled = false
          statusLabel.text = fmt"Viewing JXL: {extractFilename(selectedPath)}"
        else:
          statusLabel.text = message

      elif isSupportedInput(selectedPath):
        # Regular image - display directly
        currentImagePath = selectedPath
        loadAndDisplayImage(selectedPath)
        convertButton.enabled = true
        statusLabel.text = fmt"Loaded: {extractFilename(selectedPath)} - Click 'Convert to JXL' to convert"
      else:
        statusLabel.text = "Unsupported file format: " & extractFilename(selectedPath)

  # Convert button handler
  convertButton.onClick = proc(event: ClickEvent) =
    if currentImagePath.len == 0:
      return

    # Parse quality value
    try:
      qualityValue = parseInt(qualityInput.text)
      if qualityValue < 1: qualityValue = 1
      if qualityValue > 100: qualityValue = 100
    except:
      qualityValue = DefaultQuality
      qualityInput.text = $DefaultQuality

    statusLabel.text = fmt"Converting to JXL (quality: {qualityValue})..."

    let (success, outputPath, message) = convertToJxl(currentImagePath, qualityValue)

    if success:
      # Show size comparison
      let originalSize = getFileSize(currentImagePath)
      let jxlSize = getFileSize(outputPath)
      let ratio = (jxlSize.float / originalSize.float) * 100
      statusLabel.text = fmt"{message} | Size: {formatSize(jxlSize)} ({ratio:.1f}% of original)"
    else:
      statusLabel.text = message

  # Show window and run
  window.show()
  app.run()

  # Cleanup on exit
  cleanup()

# Entry point
when isMainModule:
  main()
