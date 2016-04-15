# encoding: UTF-8
require 'sinatra'
require 'json'
require 'slim'
require 'mini_magick'
require 'csv'

# require './scannedfiles'
enable :sessions

set :bind, '0.0.0.0'

configure do
  set :info, %x(hostname)
  set :lsusb, %x(lsusb)
end

get '/i' do
  "#{settings.info}: #{settings.lsusb}"
end

get "/" do
  redirect "/scan"
end

post '/scanimage' do
  logger.info "Incoming: #{params}"
  
  @salt = generate_secret(4)
  @secret = request.cookies["sessionid"]
  @filename = @salt + params[:name]
  @batchcount = params[:batchcount]
  @batchfilename = @filename
  
  if Integer(@batchcount) > 1
    batchfilename = "#{@filename}%d"
  end
  
#  @ret = %x(scanimage -l 0mm -t 0mm -x 210mm -y 297mm --resolution #{params[:dpi]} --format=tiff --progress --verbose --batch="public/scans/#{@secret}/#{@batchfilename}.tiff" --batch-count #{@batchcount} 2> progress.txt)
  
  status 202
end

get '/progress' do
  response.headers['Content-Type'] = "application/json"
  @return = {
    timestamp: Time.now
    }
  
  @output = File.read('progress.txt').gsub /\r/, "\n"
  @lastupdate = @output.scan(/.*Progress: \d+.\d+%\n/).last
  @return[:progress] = @lastupdate.to_s.match(/\d+.\d+/).to_s.to_f
  
  @matched = @output.match /.*(Progress: \d+.\d+%\n)+/
  @output.gsub! /.*(Progress: \d+.\d+%\n)+/, "<strong>#{@lastupdate.to_s}</strong>"
  @output.gsub! /\n/, "<br />"
  @return[:html] = @output
  
  return @return.to_json
end

get '/scan' do
  @secret = generate_secret(12)
  if !(request.cookies.has_key? "sessionid")
    response.set_cookie('sessionid', value: @secret, expires: Time.now + 3600*24*30)
    %x(mkdir public/scans/#{@secret})
  end
  slim :scan
#  @scanner_status = %x(scanimage -L)
end

get '/print' do
  @printerinfo = %x(lpstat -p)
  slim :print
end

post '/print' do
  File.open('prints/' + params['document'][:filename], "w") do |f|
    f.write(params['document'][:tempfile].read)
    %x(lpr prints/#{params['document']})
  end
  return "The file was successfully uploaded!"
end

get '/preview' do
  if params[:id]
    @files = %x(find public/scans/#{params[:id]} -name "*.tiff").split
    %x(mkdir public/scans/#{params[:id]}/proc)
  else
    @files = Array.new
  end
  @fpaths = Array.new
  
  @files.each do |f|
    if !File.exists?("#{f}_thumb.jpg") && File.exists?(f)
      MiniMagick::Tool::Convert.new do |convert|
        convert << f
        convert.resize "150x100^"
        convert << "#{f}_thumb.jpg"
      end
    end
    
    @fpaths.push({
      thumb: f.slice(7..-1) + "_thumb.jpg",
      name: f.slice(30 .. -1).split(".")[0],
      source: f
      })
  end
  
  if request.xhr?
    slim :preview, :layout => false 
  else 
    slim :preview
  end
end

post '/switch_thumb' do
  thumb = params[:thumb]
  puts params
  MiniMagick::Tool::Convert.new do |convert|
    convert << params[:source]
    convert.resize "150x100^"
    params[:thresholded] == "true" ? convert.threshold("30%") : ""
    convert << "public/" + params[:thumb]
  end

  return thumb
end

post "/getimages" do
  request.body.rewind
  @files = JSON.parse request.body.read
  @workdir = @files[0]['url'].slice(0, 25).split(".")[0]
  @servedir = @workdir.slice(7..-1)
  @procdir = @workdir + "/proc/"
  @files.each do |f|
    MiniMagick::Tool::Convert.new do |convert|
      convert << f['url']
      f['thresholded'] ? convert.threshold("30%").compress("zip") : ""
      convert << "#{@procdir}#{f['name']}.#{f['format']}"
    end
  end
  %x(zip -rj #{@workdir}/images.zip #{@workdir}/proc)
  content_type 'text/plain'
  "#{@servedir}/images.zip"
end

helpers do
  def generate_secret(n)
    pool = ('a'..'z').to_a + ('A'..'Z').to_a + ('0'..'9').to_a
    pool.shuffle[0,n].join
  end
end

get "/*" do
  "Sorry, da ist was schief gelaufen."
end
