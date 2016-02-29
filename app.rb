# encoding: UTF-8
require 'sinatra'
require 'json'
require 'slim'
require 'mini_magick'
require 'csv'

require './scannedfiles'
enable :sessions

set :bind, '0.0.0.0'

post '/scanimage' do
  logger.info "Incoming: #{params}"
  
  @salt = generate_secret(4)
  @filename = @salt + params[:name]
  @batchcount = params[:batchcount]
  batchfilename = request.cookies["sessionid"] + "_" + @filename
  
  if Integer(@batchcount) > 1
    batchfilename = "#{@filename}%d"
  end
  
  @ret = %x(scanimage -l 0mm -t 0mm -x 210mm -y 297mm --resolution #{params[:dpi]} --format=tiff --progress --verbose --batch="public/scans/#{batchfilename}.tiff" --batch-count #{@batchcount} 2> progress.txt)
  
  if request.cookies.has_key? "sessionid"
    if File.exists?("sessions/#{request.cookies["sessionid"]}_scans.csv")
#      @no_of_docs = %x{wc -l sessions/#{request.cookies["sessionid"]}_scans.csv}.split.first
    end
    @scans = CSV.open("sessions/#{request.cookies["sessionid"]}_scans.csv", "ab") do |csv|
      csv << [params[:name], @batchcount, request.ip, Time.now, request.cookies["sessionid"], @salt]
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
  if !(request.cookies.has_key? "sessionid")
    response.set_cookie('sessionid', value: generate_secret(12))
  end
  slim :scan
#  @scanner_status = %x(scanimage -L)
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
      url = "scans/#{row[5]}#{row[0]}.tiff";
      thumb_url = get_thumb_url(row[0], row[4], row[5]);

      @files.push({
        name: row[0],
        ip: row[2],
        date: row[3],
        thumb_url: thumb_url,
        url: url
        })
    end

    @files.each do |f|
      if !File.exists?("public/#{f[:thumb_url]}")
		generate_thumb(f[:url], f[:thumb_url], false)
      end
    end
  end
  
  if request.xhr?
    slim :preview, :layout => false 
  else 
    slim :preview
  end
end

post '/getimages' do
	request.body.rewind
  @request_payload = JSON.parse request.body.read

  %x(mkdir public/processed/#{request.cookies["sessionid"]})
  
  @request_payload.each do |req| 
    MiniMagick::Tool::Convert.new do |convert|
      convert << "public/#{req["url"]}"
      req[:thresholded] ? convert.threshold("20%") : ""
      convert << "public/processed/#{request.cookies["sessionid"]}/#{req["name"]}.#{req["format"]}"
    end
  end

  %x(zip Scans_#{request.cookies["sessionid"]} public/processed/#{request.cookies["sessionid"]}/*)
  return "processed/#{request.cookies['sessionid']}/Scans_#{request.cookies['sessionid']}.zip"
end

post '/switch_thumb' do
    puts params
    generate_thumb(params[:url], params[:thumb_url], params[:thresholded].to_bool)
    return params[:thumb_url]
end

helpers do
	def generate_thumb(url, thumb_url, threshold)
		MiniMagick::Tool::Convert.new do |convert|
          convert << "public/#{url}"
          convert.resize "300x150^"
          if threshold
            convert.threshold("20%")
          end
          convert << "public/#{thumb_url}"
        end
	end

	def get_thumb_url(name, sessionid, salt)
		return "/thumbs/#{sessionid}_#{salt}#{name}_thumb.jpeg"
	end

	def get_proc_url(name, sessionid, salt, type)
		return "/processed/#{sessionid}_#{salt}#{name}_thumb.#{type}"
	end

  def generate_secret(n)
    pool = ('a'..'z').to_a + ('A'..'Z').to_a + ('0'..'9').to_a
    pool.shuffle[0,n].join
  end
end

class String
  def to_bool
    return true   if self == true   || self =~ (/(true|t|yes|y|1)$/i)
    return false  if self == false  || self =~ (/(false|f|no|n|0)$/i)
    raise ArgumentError.new("invalid value for Boolean: \"#{self}\"")
  end
end
