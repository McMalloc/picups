# encoding: UTF-8
require 'sinatra'
require 'json'
require 'slim'
require 'mini_magick'

set :bind, '0.0.0.0'

post '/scanimage' do
  logger.info "Incoming: #{params}"
  
  @filename = generate_filename params[:name]
  @batchcount = params[:batchcount]
  batchfilename = @filename
  
  if Integer(@batchcount) > 1
    batchfilename = "#{@filename}%d"
  end
  
  logger.info "Start scanning, saving to public/scans/#{@filename}"
  @ret = %x(scanimage -l 0mm -t 0mm -x 210mm -y 297mm --resolution #{params[:dpi]} --format=tiff --progress --verbose --batch="public/scans/#{batchfilename}.tiff" --batch-count #{@batchcount} 2> progress.txt)
  %x(echo "#{params[:name]}\n#{request.ip}\n#{Time.now}" > public/scans/#{batchfilename}.meta)
  
  status 202
end

get "/getimage" do
  MiniMagick::Tool::Convert.new do |convert|
    convert << params[:file]
    params[:type] == "text" ? convert.threshold("20%") : ""
    convert << "public/processed/#{params[:name]}.#{params[:format]}"
  end
  return "/processed/#{params[:name]}.#{params[:format]}"
end

get '/progress' do
  response.headers['Content-Type'] = "application/json"
  @return = {
    timestamp: Time.now
    }
  
  @output = File.read('progress.txt').gsub /\r/, "\n"
  @lastupdate = @output.scan(/.*Progress: \d+.\d+%\n/).last
  @return[:progress] = @lastupdate.to_s.match(/\d+.\d+/).to_s.to_f
  @return[:scanner_status] = @output.to_s.match(/\d(?=\))/).to_s
  
  @matched = @output.match /.*(Progress: \d+.\d+%\n)+/
  @output.gsub! /.*(Progress: \d+.\d+%\n)+/, "<strong>#{@lastupdate.to_s}</strong>"
  @output.gsub! /\n/, "<br />"
  @return[:html] = @output
  
  return @return.to_json
end

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

get '/scan' do
  slim :scan
#  @scanner_status = %x(scanimage -L)
end

def generate_filename(passed_name)
  time = Time.now
  return "#{time.year}-#{time.month}-#{time.day}_#{time.hour}.#{time.min}.#{time.sec}_#{passed_name}"
end