# encoding: UTF-8
require 'sinatra'
require 'json'
require 'slim'

set :bind, '0.0.0.0'

post '/scanimage' do
#  @request_payload = JSON.parse request.body.read
  logger.info "Incoming: #{params}"
  
  @filename = generate_filename params[:name]
#  @filename = @request_payload["name"]
  @batchcount = params[:batchcount]
#  @batchcount = @request_payload["batchcount"]
  batchfilename = @filename
  
  if Integer(@batchcount) > 1
    batchfilename = "#{@filename}%d"
  end
  
  logger.info "Start scanning, saving to public/scans/#{@filename}"
  @ret = %x(scanimage -l 0mm -t 0mm -x 210mm -y 297mm --resolution #{params[:dpi]} --format=tiff --progress --verbose --batch="public/scans/#{batchfilename}.tiff" --batch-count #{@batchcount} 2> progress.txt &)
  %x(echo "#{params[:name]}\n#{request.ip}\n#{Time.now}" > public/scans/#{batchfilename}.meta)
  
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
  @return[:scanner_status] = @output.to_s.match(/\d(?=\))/).to_s
  
  @matched = @output.match /.*(Progress: \d+.\d+%\n)+/
  @output.gsub! /.*(Progress: \d+.\d+%\n)+/, "<strong>#{@lastupdate.to_s}</strong>"
  @output.gsub! /\n/, "<br />"
  @return[:html] = @output
  
  return @return.to_json
end

get '/scannedfiles' do
  @files = Dir["./public/scans/*.tiff"].each do |path| path.slice! "./public/" end
  slim :scannedfiles
end

get '/' do
  slim :scan
#  @scanner_status = %x(scanimage -L)
end

def generate_filename(passed_name)
  time = Time.now
  return "#{time.year}-#{time.month}-#{time.day}_#{time.hour}.#{time.min}.#{time.sec}_#{passed_name}"
end