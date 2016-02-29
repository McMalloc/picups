require "yaml"
require "mini_magick"

class String
  # colorization
  def colorize(color_code)
    "\e[#{color_code}m#{self}\e[0m"
  end

  def red
    colorize(31)
  end

  def green
    colorize(32)
  end

  def yellow
    colorize(33)
  end

  def blue
    colorize(34)
  end

  def pink
    colorize(35)
  end

  def light_blue
    colorize(36)
  end
end

@files = Array.new
  Dir["./public/scans/*.tiff"].each_with_index do |path, i|
    metapath = String.new(path)
    metapath.slice!(".tiff")
    thumbpath = String.new(metapath)
    thumbpath.slice! ".tiff"
    thumbpath << ".jpeg"
    
    if !File.exists?(thumbpath)
      puts thumbpath
      MiniMagick::Tool::Convert.new do |convert|
        convert << path
        convert.resize "75x50^"
        convert << thumbpath
      end
    end
    
    thumbpath.slice!("./public/")
    if File.exists?(metapath + ".meta")
      meta = File.read(metapath + ".meta")
      path.slice!("./public/")
      scanned_meta = meta.scan(/(.*)\n/)
      @files[i] = {
          name: scanned_meta[0][0],
          ip: scanned_meta[1][0],
          timestamp: scanned_meta[2][0]
        }
    else
      @files[i] = {
          name: path.scan(/^\.\/(.+\/)*(.+)\/.(.+)$/)[0][2],
          thumbnail: "",
          ip: "-",
          timestamp: "-"
        }
    end
    @files[i][:fpath] = path
      
  end
  
puts @files.to_yaml