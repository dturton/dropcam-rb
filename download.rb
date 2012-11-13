require File.join(File.dirname(__FILE__), 'dropcam.rb')


api = Dropcam::API.new("<USERNAME>","<PASSWORD>")
all_cameras = api.cameras
all_cameras.each { |cam|
  puts cam.name
  if cam.write_current_image()
    puts "Image Written!"
  end
}