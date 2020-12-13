#!/usr/bin/env ruby
require('date')
require('progress_bar')
require('shellwords')
require('optparse')
require('etc')

##
# File types we want to copy
IMAGE_TYPES = [
  # Cooked file types
  'jpg',
  'jpeg',
  'tif',
  'tiff',
  'heic', # This is the format iPhones shoot in nowadays.

  # Raw file types
  'dng',  # Adobe digital negative (Leica, DJI, Pentax, etc)
  'crw',  # Old Canon (e.g., original rebel)
  'cr2',  # Middle Canon (e.g., 5D Mark III)
  'cr3',  # Latest Canon (e.g., new stuff I haven't played with yet)
  'rw2',  # Panasonic
  'orf',  # Olympus
  'arw',  # Sony
  'nef',  # Nikon
  'x3f',  # Sigma
  'raf',  # Fuji

  # Video types
  'avi',
  'mov',
  'wmv',
  'mp4',
]

##
# Number of seconds between photos to consider it a "new day" for directory purposes
# This is so photos end up in day X's directory if it's technically day X+1 at 12:01 am
# and we're still shooting. If there's a 4 hour break, we assume that I've gone to sleep
# and we're starting a new day.
MINIMUM_DAY_BREAK = 4 * 3600

##
# Class representing the information we have about a camera file.
#
# Mainly this is just the filename and date timestamp.
class CameraFile

  # The current date/time; used for the timestamp sanity check
  @@now_secs = DateTime.now.strftime("%s").to_i

  def initialize(path)
    @path = path
    @filename = File.basename(path)
    # Use the file's create/change time as our image create time.
    # Presumably this will match up with the exif or at least be close enough.
    # We could use exiftool to grab it, but that turned out to be real slow
    # in testing.
    @timestamp = DateTime.parse(File.ctime(path).to_s)

    # Sometimes it's good to do a sanity check. Like, for instance, if
    # DJI can't set their ctimes properly even though the dang drone has
    # a GPS connection which allows it to have atomic-accurate time whenever
    # it's in the air. So if the filesystem timestamp gives me a date in the
    # future, call out to exiftool to get a date from the file itself.
    # This is a little slower, but the number of files broken in this way
    # should be minimal.
    timediff = @@now_secs - @timestamp.strftime("%s").to_i
    if timediff < 0 then
      exiftool_command = %w(exiftool -b -createdate).append(path).shelljoin
      @timestamp = DateTime.strptime(`#{exiftool_command}`, '%Y:%m:%d %H:%M:%S')
    end
  end

  attr_reader :timestamp, :path, :filename

  def secs
    @timestamp.strftime('%s').to_i
  end
end


##
# Halt and catch fire
def panic(error)
  puts(error)
  abort()
end


##
# Find memory cards under the given mountpoint.
def get_memory_cards(media_mountpoint)
  # Look for directories under the media mountpoint with a DCIM directory
  Dir.glob("#{media_mountpoint}/#{Etc.getlogin}/*").select {|mp| File.exist?("#{mp}/DCIM") }
end


##
# Get list of all image/video files in a DCIM directory under the given path.
def get_files_for_card(dir)
  extensions = (IMAGE_TYPES + IMAGE_TYPES.map {|ext| ext.upcase}).join(',')
  # Get all of the image files in the image directories.
  # Pass it through uniq to handle filesystems that ignore or fold case.
  imagefiles = Dir.glob("#{dir}/DCIM/*/*.{#{extensions}}").uniq

  # Return the image paths as Image objects
  imagefiles.map {|path| CameraFile.new(path)}
end


##
# Get the appropriate directory path for the given date under the given base path.
def get_directory_for_date(timestamp, base_path)
  iso = timestamp.strftime('%Y-%m-%d')
  year = timestamp.year
  # If we've already figured out the directory for this date, return it
  @directories ||= Hash.new({})
  return @directories[base_path][iso] if @directories[base_path][iso]

  # Otherwise, look for an existing directory for that date
  existing = Dir.glob("#{base_path}/#{iso}*")[0] || Dir.glob("#{base_path}/#{year}/#{iso}*")[0]
  if existing
    @directories[base_path] = @directories[base_path].merge({iso => existing})
  else
    # No existing directory, so we create one using the iso8601 name in the base path.
    newpath = "#{base_path}/#{iso}"
    Dir.mkdir(newpath)
    @directories[base_path] =  @directories[base_path].merge({iso => newpath})
  end

  @directories[base_path][iso]
end

##
# Get a safe filename to copy to
# Normally, this'll just return the 'to' that you pass in.
# If this returns nil, the file already exists.
# If there's a filename conflict, this will return a safe filename.
#
# This function is dedicated to all of the photos I lost on October 12, 2018,
# due to an annoying confluence of events that lead to my Canon reusing file
# numbers during a single shoot.
def check_dest_filename(from,requested_to,iteration=0)
  # If we're not on our first iteration, add in the iteration number to the filename
  to = iteration == 0 ? requested_to : requested_to.gsub(/\.([^.]+)$+/, ".#{iteration}.\\1")
  # Return the requested filename if it doesn't exist
  return to unless File.exist?(to)
  # Return nil if the filename exists, but they're identical
  return nil if system('cmp', '-s', from, to)
  # There's a different file there that this would clobber if we copy!
  # Find a name that works by inserting a number before the extension.
  return check_dest_filename(from, requested_to, iteration+1)
end

##
# Unmount cards
#
# Ideally, this should also clean up annoying Sony garbage, but I can't figure
# out a good way to do that safely.
def cleanup_card(dir)
  system('umount', dir)
end


##
# Mockup copy function for testing. Just outputs the command that *would* be run to a file.
def operation_mock(from, to)
  `echo mv #{from} #{to} >> /home/allanc/cmnt_test_run`
end

##
# Copy function
def operation_copy(from, to)
  # If we don't have a destination filename, that indicates that the file is
  # already there, so just return without doing anything.
  return if !to
  system('cp', from, to)
end

##
# Move function
def operation_move(from, to)
  return if !to
  system('mv', from, to)
end

##
# Get the command line options.
def get_options()
  options = {
    :main => '/mnt/pictures/allanc/Pictures',
    :bak  => '/mnt/pictures-bak/allanc/Pictures',
    :media => '/media',
    :mock => false,
  }
  OptionParser.new do |opts|
    opts.banner = "Usage: #{$0} [options]"
    opts.on('--main=MAIN', 'Main pictures directory') { |main|  options[:main]  = main }
    opts.on('--bak=BAK', 'Backup pictures directory') { |bak|   options[:bak]   = bak  }
    opts.on('--media=MEDIA', 'Media automount point') { |media| options[:media] = media }
    opts.on('--mock', 'Mock the actual transfers, output a log in the given file') { options[:mock] = true }
  end.parse!

  return options
end


##
# Main logic of the script
def main
  options = get_options()

  # Make sure the RAIDs are mounted
  panic("Pictures RAID not working?!?") if !File.exist?("#{options[:main]}/raid-sanity-main")
  panic("Backup RAID not working?!?") if !File.exist?("#{options[:bak]}/raid-sanity-backup")

  # Get the list of memory cards currently attached
  cards = get_memory_cards(options[:media])
  panic("No cards found (did you remember to poke the keyboard?)") if cards.length == 0

  cardlist_text = cards.map {|card| File.basename(card)}.join(', ')
  puts("Found card#{cards.length == 1 ? '' : 's'}: #{cardlist_text}")

  # Get the list of camera files in all of the currently-mounted cards
  camerafiles = []
  cards.each do |card|
    tmp_files = get_files_for_card(card)
    puts("No files found on card #{File.basename(card)}. Is that okay?") if tmp_files.length === 0
    camerafiles += tmp_files
  end
  abort() unless camerafiles.length > 0

  # Sort by timestamp
  camerafiles = camerafiles.sort { |a, b| a.timestamp <=> b.timestamp }

  operations = options[:mock] ?
  [
    {
      :title => 'Test mockup...',
      :op => :operation_mock,
      :base_path => options[:main],
    },
  ] :
  [
    {
      :title => 'Copy to Pictures...',
      :op => :operation_copy,
      :base_path => options[:main],
    },
    {
      :title => 'Move to Backup...',
      :op => :operation_move,
      :base_path => options[:bak],
    }
  ]


  operations.each do |step|
    title     = step[:title]
    operation = step[:op]
    base_path = step[:base_path]

    # prefill the "last timestamp" as the epoch so that we'll always meet the
    # minimum day break time.
    last_ts = DateTime.new()

    # This will be the list of directories we copied files to,
    # along with the number of files copied to each. Set up the hash
    # with a '0' default so we can += without having to check.
    output_dirs = Hash.new(0)

    # Our current destination directory
    dest_dir = nil

    # Set up the progress bar.
    progress_bar = ProgressBar.new(camerafiles.count, :bar, :counter, :percentage, :eta)

    puts(title)
    camerafiles.each do |camerafile|
      # Figure out if we're updating the destination directory or continuing
      # with where we copied the previous file.
      time_delta = camerafile.secs - last_ts.strftime('%s').to_i
      dest_dir = get_directory_for_date(camerafile.timestamp, base_path) if !dest_dir || time_delta > MINIMUM_DAY_BREAK
      output_dirs[dest_dir] += 1

      # Get our source and destination paths
      from = camerafile.path
      to = check_dest_filename(from, "#{dest_dir}/#{File.basename(camerafile.path)}")
      # Run the operation, be it copy or move
      send(operation, from, to)

      last_ts = camerafile.timestamp

      # Tick the progress bar.
      progress_bar.increment!
    end

    # Report on the affected files
    output_dirs.each do |dir, file_count|
      puts "#{file_count} files => #{dir}"
    end
  end

  cards.each {|card| cleanup_card(card) }
end

# Set everything in motion.
main
