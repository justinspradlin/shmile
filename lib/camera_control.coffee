EventEmitter = require("events").EventEmitter
spawn = require("child_process").spawn
exec = require("child_process").exec
im = require("imagemagick")

###
# Interface to gphoto2 via the command line.
#
# It's highly fragile and prone to failure, so if anyone wants
# to take a crack at redoing the node-gphoto2 bindings, be my
# guest...
###
class CameraControl
  saving_regex: /Saving file as ([^.jpg]+)/g
  captured_success_regex: /New file is in/g

  constructor: (
    @filename="%m-%y-%d_%H:%M:%S.jpg",
    @cwd="public/photos",
    @web_root_path="/photos") ->

  init: ->
    exec "killall PTPCamera"
    emitter = new EventEmitter()
    emitter.on "snap", (onCaptureSuccess, onSaveSuccess) =>
      emitter.emit "camera_begin_snap"
      capture = spawn("gphoto2", [ "--capture-image-and-download",
                                   "--force-overwrite",
                                   "--filename=" + @filename ],
        cwd: @cwd
      )
      capture.stdout.on "data", (data) =>
        if @captured_success_regex.exec(data.toString())
          emitter.emit "camera_snapped"
          onCaptureSuccess() if onCaptureSuccess?

        saving = @saving_regex.exec(data.toString())
        if saving
          fname = saving[1] + ".jpg"
          
          # Generate a thumbnail to minimize bandwidth issues
          # on slower networks - Don't send 7MB JPGs to an iPAD on an ad-hoc network
          # because they will not load in the app fast enough to view them
          input_file = @cwd + "/" + fname
          output_file = @cwd + "/thumbs/" + fname
          resizeCompressArgs = [ "-resize", "400x600", "-quality", "80", input_file, output_file ]
          
          im.convert resizeCompressArgs, (e, out, err) ->
            throw err  if err
            emitter.emit(
              "photo_saved",
              fname,
              input_file,
              output_file,
              "/photos/thumbs/" + fname
            )
          onSaveSuccess() if onSaveSuccess?
    emitter

module.exports = CameraControl
