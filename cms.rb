require 'bcrypt'
require 'sinatra'
require 'sinatra/reloader' if development?
require 'tilt/erubis'
require 'redcarpet'
require 'yaml'

configure do
  enable :sessions
  set :session_secret, 'secret'
end

helpers do
  def at_index?
    request.fullpath == '/'
  end

  def at_signin?
    request.fullpath == '/users/signin'
  end
end

get '/' do
  @files = Dir.glob(File.join(data_path, '*')).map { |path| File.basename(path) }
  erb :index
end

get '/users/signin' do
  if user_signed_in?
    session[:message] = 'You are already signed in.'
    redirect '/'
  end
  erb :signin
end

get '/new' do
  require_signin
  erb :new_document
end

get '/:filename' do
  require_signin
  path = File.join(data_path, params[:filename])
  if File.exist?(path)
    load_file_content(path)
  else
    session[:message] = "#{params[:filename]} does not exist."
    redirect '/'
  end
end

get '/:filename/edit' do
  require_signin
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

get '/users/new' do
  erb :create_account
end

post '/new' do
  require_signin
  filename = params[:new_name]
  path = File.join(data_path, filename)
  if filename.nil? || filename.empty?
    session[:message] = 'A name is required.'
    status 422
    erb :new_document
  elsif File.exist?(path)
    session[:message] = "#{filename} already exists."
    erb :new_document
  else
    File.write(path, '')
    session[:message] = "#{filename} was created."
    redirect '/'
  end
end

post '/:filename' do
  require_signin
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

post '/:filename/delete' do
  require_signin
  filename = params[:filename]
  path = File.join(data_path, filename)
  if File.exist?(path)
    File.delete(path)
    session[:message] = "#{filename} was deleted."
  else
    session[:message] = "#{filename} does not exist."
  end
  redirect '/'
end

post '/users/signin' do
  username = params[:username]
  password = params[:password]
  signin_and_redirect(username) if valid_credentials?(username, password)

  status 422
  session[:message] = 'Invalid Credentials'
  erb :signin
end

post '/users/signout' do
  require_signin
  session.delete(:username)
  session[:message] = 'You have been signed out.'
  redirect '/users/signin'
end

post '/users/new' do
  credentials = load_credential_store
  if params[:password1] != params[:password2]
    session[:message] = "Passwords do not match. Try again."
    status 422
    erb :create_account
  elsif credentials.key?(params[:username])
    session[:message] = "That username already exists. Try again."
    status 422
    erb :create_account
  else
    encrypted = BCrypt::Password.create(params[:password1])
    credentials[params[:username]] = encrypted.to_s
    dump_credential_store(credentials)
    signin_and_redirect(params[:username])
  end
end

def data_path
  if ENV['RACK_ENV'] == 'test'
    File.expand_path('../test/data', __FILE__)
  else
    File.expand_path('../data', __FILE__)
  end
end

def credential_store_path
  if ENV['RACK_ENV'] == 'test'
    File.expand_path('../test/users.yaml', __FILE__)
  else
    File.expand_path('../users.yaml', __FILE__)
  end
end

def load_credential_store
  YAML.load_file(credential_store_path)
end

def dump_credential_store(credential_hash)
  File.open(credential_store_path, 'w') do |file|
    file.write(YAML.dump(credential_hash))
  end
end

def load_file_content(path)
  content = File.read(path)
  case File.extname(path)
  when '.html'
    erb content
  when '.md'
    erb render_markdown(content)
  else
    erb "<pre>#{content}</pre>"
  end
end

def render_markdown(text)
  markdown = Redcarpet::Markdown.new(Redcarpet::Render::HTML)
  markdown.render(text)
end

def valid_credentials?(username, password)
  credential_store = YAML.load_file(credential_store_path)
  return false unless credential_store.keys.include?(username)
  BCrypt::Password.new(credential_store[username]) == password
end

def user_signed_in?
  !!session[:username]
end

def require_signin
  return if user_signed_in?

  session[:message] = 'You must be signed in to do that.'
  session[:returnto] = request.path_info
  redirect '/users/signin'
end

def signin_and_redirect(username)
  session[:username] = username
  session[:message] = 'Welcome!'
  if session[:returnto]
    redirect session.delete(:returnto)
  else
    redirect '/'
  end
end
