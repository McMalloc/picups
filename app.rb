# encoding: UTF-8
require 'sinatra'
require 'json'
require 'slim'

set :bind, '0.0.0.0'

post 'scanimage' do
  @request_payload = JSON.parse request.body.read
  
  @filename = @request_payload["name"]
  @batchcount = @request_payload["batchcount"]
  batchfilename = @filename
  
  if @batchcount > 1
    batchfilename = "#{@filename}%d"
  end
  
  foldername = create_dir
  logger.info "Start scanning, saving to public/scans/#{foldername}/#{@filename}"
  @ret = %x(scanimage --progress --verbose --batch="public/scans/#{foldername}/#{batchfilename}" --batch-count 1 2> public/progress.txt &)
  return @ret
end

get '/' do
  slim :scan
#  @scanner_status = %x(scanimage -L)
end

def create_dir
  time = Time.new
  foldername = "#{time.year}-#{time.month}-#{time.day}-all"
  %x(mkdir public/scans/#{foldername})
  return foldername
end