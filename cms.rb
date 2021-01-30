require 'sinatra'
require 'sinatra/reloader' if development?
require 'tilt/erubis'
require 'redcarpet'

markdown = Redcarpet::Markdown.new(Redcarpet::Render::HTML)

configure do
  enable :sessions
  set :session_secret, "secret"
end

get '/' do
  @files = Dir.glob(File.join(data_path, "*")).map { |path| File.basename(path) }
  erb :index
end

get '/new' do
  erb :new_document
end

get '/:filename' do
  path = File.join(data_path, params[:filename])
  if File.exist?(path)
    load_file_content(path)
  else
    session[:message] = "#{params[:filename]} does not exist."
    redirect '/'
  end
end

get '/:filename/edit' do
  @filename = params[:filename]
  path = File.join(data_path, @filename)
  if File.exist?(path)
    @contents = File.read(path)
  else
    session[:message] = "#{@filename} does not exist."
    redirect '/'
  end
  erb :edit 
end

post '/new' do
  filename = params[:new_name]
  path = File.join(data_path, filename)
  if filename.nil? || filename.empty?
    session[:message] = "A name is required."
    erb :new_document
  elsif File.exist?(path)
    session[:message] = "#{filename} already exists."
    erb :new_document
  else
    File.write(path, "")
    session[:message] = "#{filename} was created."
    redirect '/'
  end
end

post '/:filename' do
  filename = params[:filename]
  path = File.join(data_path, filename)
  new_contents = params[:new_contents]
  if File.exist?(path)
    if File.writable?(path)
      if File.read(path) != new_contents
        File.write(path, new_contents)
        session[:message] = "#{filename} has been updated."
      else
        session[:message] = "No changes made to #{filename}."
      end
    else
      session[:message] = "Unable to save #{filename}."
    end
  else
    session[:message] = "#{filename} does not exist."
  end
  redirect '/'
end

def data_path
  if ENV["RACK_ENV"] == "test"
    File.expand_path("../test/data", __FILE__)
  else
    File.expand_path("../data", __FILE__)
  end
end

def load_file_content(path)
  content = File.read(path)
  case File.extname(path)
  when '.txt'
    headers['Content-Type'] = 'text/plain'
    content
  when '.md'
    erb render_markdown(content)
  end
end

def render_markdown(text)
  markdown = Redcarpet::Markdown.new(Redcarpet::Render::HTML)
  markdown.render(text)
end