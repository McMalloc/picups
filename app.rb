# encoding: UTF-8
require 'sinatra'
require 'json'
require 'slim'
require 'mini_magick'
require 'csv'
require './csvfiles'

# require './scannedfiles'
enable :sessions

set :bind, '0.0.0.0'

configure do
  set :info, %x(hostname)
  set :lsusb, %x(lsusb)
end

get '/i' do
  "#{settings.lsusb}"
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
  
  @ret = %x(scanimage -l 0mm -t 0mm -x 210mm -y 297mm --resolution #{params[:dpi]} --format=tiff --progress --verbose --batch="public/scans/#{@secret}/#{@batchfilename}.tiff" --batch-count #{@batchcount} 2> progress.txt)
  
  if request.cookies.has_key? "sessionid"
    if File.exists?("sessions/#{request.cookies["sessionid"]}_scans.csv")
#      @no_of_docs = %x{wc -l sessions/#{request.cookies["sessionid"]}_scans.csv}.split.first
    end
    @scans = CSV.open("sessions/#{request.cookies["sessionid"]}_scans.csv", "ab") do |csv|
      csv << [params[:name], @batchcount, request.ip, Time.now, @secret, @salt]
    end
  end
  
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
  @files = Array.new
  if File.exists? "sessions/#{request.cookies["sessionid"]}_scans.csv"
    CSV.foreach("sessions/#{request.cookies["sessionid"]}_scans.csv") do |row|
      # row [0] name
      # row [1] Batchcount
      # row [2] IP
      # row [3] Datum
      # row [4] Session ID
      # row [5] Salt
      url = "scans/#{row[4]}/#{row[5]}#{row[0]}.tiff";
      thumb_url = "thumbs/#{row[4]}_#{row[5]}#{row[0]}_thumb.jpeg";

      @files.push({
        name: row[0],
        ip: row[2],
        date: row[3],
        thumb_url: thumb_url,
        url: url
        })
    end

    @files.each do |f|
      if !File.exists?("public/#{f[:thumb_url]}") && File.exists?("public/#{f[:thumb_url]}")
        MiniMagick::Tool::Convert.new do |convert|
          convert << "public/#{f[:url]}"
          convert.resize "150x100^"
          convert << "public/#{f[:thumb_url]}"
        end
      end
    end
  end
  
  if request.xhr?
    slim :preview, :layout => false 
  else 
    slim :preview
  end
end

post '/process' do
  @proc_url = "public/processed/#{params[:sessionid]}_#{params[:salt]}#{params[:name]}.#{params[:type]}"
  MiniMagick::Tool::Convert.new do |convert|
    convert << params[:url]
    convert.resize "750x500"
    params[:type] == "pdf" ? convert.threshold("#{params[:threshold]}%") : ""
    convert << @proc_url
  end

  return @proc_url
end

post '/switch_thumb' do
  MiniMagick::Tool::Convert.new do |convert|
    convert << "public/#{params[:url]}"
    convert.resize "150x100^"
    params[:thresholded] ? convert.threshold("30%") : ""
    convert << "public/thumbs/#{params[:thumb_url]}"
  end

  return @proc_url
end

helpers do
  def generate_secret(n)
    pool = ('a'..'z').to_a + ('A'..'Z').to_a + ('0'..'9').to_a
    pool.shuffle[0,n].join
  end
end
