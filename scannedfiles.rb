get '/scannedfiles' do
  @files = Array.new
  Dir["./public/scans/*.tiff"].each_with_index do |path, i|
    metapath = String.new(path)
    metapath.slice!(".tiff")
    thumbpath = String.new(metapath)
    thumbpath.slice! ".tiff"
    thumbpath << "_thumb.jpeg"
    
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
      puts scanned_meta
      @files[i] = {
          name: scanned_meta[0][0],
          ip: scanned_meta[1][0],
          timestamp: scanned_meta[2][0]
        }
    else
      @files[i] = {
          name: path.scan(/^\.\/(.+\/)*(.+)\/.(.+)$/)[0][2],
          ip: "-",
          timestamp: "-"
        }
    end
    @files[i][:fpath] = path
    @files[i][:thumbpath] = thumbpath
      
  end
  
  if request.xhr?
  # renders :template_partial without layout.html
    slim :scannedfiles, :layout => false
  else 
    # renders as normal inside layout.html
    slim :scannedfiles
  end
end