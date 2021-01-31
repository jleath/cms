ENV['RACK_ENV'] = 'test'

require 'minitest/autorun'
require 'minitest/reporters'
require 'rack/test'
require 'fileutils'

require_relative '../cms'

Minitest::Reporters.use!

class AppTest < Minitest::Test
  include Rack::Test::Methods

  def app
    Sinatra::Application
  end

  def setup
    FileUtils.mkdir_p(data_path)
  end

  def teardown
    FileUtils.rm_rf(data_path)
  end

  def create_document(name, content = '')
    File.open(File.join(data_path, name), 'w') do |file|
      file.write(content)
    end
  end

  def session
    last_request.env['rack.session']
  end

  def admin_session
    { 'rack.session' => { username: 'admin' } }
  end

  def test_index
    create_document('about.md')
    create_document('changes.txt')

    get '/'

    assert_equal 200, last_response.status
    assert_equal 'text/html;charset=utf-8', last_response['Content-Type']
    assert_includes last_response.body, 'about.md'
    assert_includes last_response.body, 'changes.txt'
  end

  def test_viewing_text_document
    create_document('history.txt', 'sample text')
    get '/history.txt', {}, admin_session
    assert_equal 200, last_response.status
    assert_includes last_response.body, 'sample text'
  end

  def test_document_not_found
    get '/notafile.ext', {}, admin_session
    assert_equal 302, last_response.status
    assert_equal 'notafile.ext does not exist.', session[:message]
  end

  def test_viewing_markdown_document
    create_document('markdown.md', '# Heading 1')
    get '/markdown.md', {}, admin_session
    assert_equal 200, last_response.status
    assert_equal 'text/html;charset=utf-8', last_response['Content-Type']
    assert_includes last_response.body, '<h1>Heading 1</h1>'
  end

  def test_viewing_file_signed_out
    create_document('test.txt')
    get '/test.txt'
    assert_equal 302, last_response.status
    assert_equal 'You must be signed in to do that.', session[:message]
  end

  def test_file_edit
    create_document('test.txt')
    post '/test.txt', { 'new_contents' => '5678' }, admin_session
    assert_equal 302, last_response.status
    assert_equal 'test.txt has been updated.', session[:message]
    get '/test.txt'
    assert_includes last_response.body, '5678'
  end

  def test_file_edit_signed_out
    create_document('test.txt')
    get '/test.txt/edit'
    assert_equal 302, last_response.status
    assert_equal 'You must be signed in to do that.', session[:message]
  end

  def test_new_file_view
    get '/new', {}, admin_session
    assert_equal 200, last_response.status
    assert_includes last_response.body, '<button type="submit"'
  end

  def test_new_file_signed_out
    get '/new'
    assert_equal 302, last_response.status
    assert_equal 'You must be signed in to do that.', session[:message]
  end

  def test_recreate_existing_file
    create_document('about.md')
    post '/new', { 'new_name' => 'about.md' }, admin_session
    assert_includes last_response.body, 'about.md already exists.'
  end

  def test_blank_new_filename
    post '/new', { 'new_name' => '' }, admin_session
    assert_equal 422, last_response.status
    assert_includes last_response.body, 'A name is required.'
  end

  def test_new_file_creation
    post '/new', { 'new_name' => 'brand_new_file.txt' }, admin_session
    assert_equal 302, last_response.status
    assert_equal 'brand_new_file.txt was created.', session[:message]
    get '/'
    assert_includes last_response.body, 'brand_new_file.txt'
  end

  def test_delete_file
    create_document('test.txt')
    post '/test.txt/delete', {}, admin_session
    assert_equal 302, last_response.status
    assert_equal 'test.txt was deleted.', session[:message]
    assert_equal false, File.exist?(File.join(data_path, 'test.txt'))
    get '/'
    refute_includes last_response.body, 'href="/test.txt"'
  end

  def test_delete_file_signed_out
    create_document('test.txt')
    post '/test.txt/delete'
    assert_equal 302, last_response.status
    assert_equal 'You must be signed in to do that.', session[:message]
  end

  def test_delete_nonexistent_file
    post '/nonexistent.txt/delete', {}, admin_session
    assert_equal 302, last_response.status
    assert_equal 'nonexistent.txt does not exist.', session[:message]
  end

  def test_signin_view
    get '/users/signin'
    assert_equal 200, last_response.status
    assert_includes last_response.body, 'Sign In'
  end

  def test_signin_while_signed_in
    get '/users/signin', {}, admin_session
    assert_equal 302, last_response.status
    get last_response['Location']
    assert_equal 200, last_response.status
    assert_includes last_response.body, 'You are already signed in'
  end

  def test_signin_bad_credentials
    post '/users/signin', { 'username' => 'admin', 'password' => 'bad' }
    assert_equal 422, last_response.status
    assert_nil session[:username]
    assert_includes last_response.body, 'Sign In'
    assert_includes last_response.body, 'Invalid Credentials'
  end

  def test_signin_valid_credentials
    post '/users/signin', { 'username' => 'admin', 'password' => 'secret' }
    assert_equal 302, last_response.status
    assert_equal 'Welcome!', session[:message]
    assert_equal 'admin', session[:username]
    get last_response['Location']
    assert_includes last_response.body, 'Signed in as admin'
  end

  def test_signout
    post '/users/signout', {}, admin_session
    assert_equal 302, last_response.status
    assert_equal 'You have been signed out.', session[:message]
    assert_nil session[:username]
    get last_response['Location']
    assert_includes last_response.body, 'Sign In'
  end

  def test_signin_returnto
    create_document('about.md')
    post '/users/signin', { 'username' => 'admin', 'password' => 'secret' },
         { 'rack.session' => { 'returnto' => '/about.md/edit' } }
    assert_equal 302, last_response.status
    assert_equal 'Welcome!', session[:message]
    get last_response['Location']
    assert_includes last_response.body, 'Edit contents of about.md'
  end
end
