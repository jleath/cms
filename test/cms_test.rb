ENV["RACK_ENV"] = "test"

require "minitest/autorun"
require "minitest/reporters"
require "rack/test"
require "fileutils"

require_relative "../cms"

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

  def create_document(name, content = "")
    File.open(File.join(data_path, name), 'w') do |file|
      file.write(content)
    end
  end

  def test_index
    create_document("about.md")
    create_document("changes.txt")

    get "/"

    assert_equal 200, last_response.status
    assert_equal "text/html;charset=utf-8", last_response["Content-Type"]
    assert_includes last_response.body, "about.md"
    assert_includes last_response.body, "changes.txt"
  end

  def test_viewing_text_document
    create_document("history.txt", "sample text")

    get "/history.txt"

    assert_equal 200, last_response.status
    assert_equal "text/plain", last_response["Content-Type"]
    assert_includes last_response.body, "sample text"
  end

  def test_document_not_found
    get "/notafile.ext"
    assert_equal 302, last_response.status

    get last_response["Location"]
    assert_equal 200, last_response.status
    assert_includes last_response.body, "notafile.ext does not exist"

    get "/"
    refute_includes last_response.body, "does not exist"
  end

  def test_viewing_markdown_document
    create_document("markdown.md", "# Heading 1")

    get "/markdown.md"

    assert_equal 200, last_response.status
    assert_equal "text/html;charset=utf-8", last_response["Content-Type"]
    assert_includes last_response.body, "<h1>Heading 1</h1>"
  end

  def test_file_edit
    create_document("test.txt", "1234")
    
    post "/test.txt", "new_contents" => "5678"
    assert_equal 302, last_response.status

    get last_response["Location"]
    assert_includes last_response.body, "has been updated"
    
    get "/test.txt"
    assert_equal 200, last_response.status
    assert_includes last_response.body, "5678"
  end

  def test_create_and_edit_new_file
    # test attempt to recreate existing file
    create_document("about.md")
    post "/new", "new_name" => "about.md"
    assert_equal 200, last_response.status
    assert_includes last_response.body, "about.md already exists"

    # test attempt to leave filename blank
    post "/new", "new_name" => ""
    assert_equal 200, last_response.status
    assert_includes last_response.body, "A name is required."

    # test successful file creation
    post "/new", "new_name" => "brand_new_file.txt"
    assert_equal 302, last_response.status

    get last_response["Location"]
    assert_equal 200, last_response.status
    assert_includes last_response.body, "brand_new_file.txt was created."

    get "/"
    assert_includes last_response.body, "brand_new_file.txt"
  end
end