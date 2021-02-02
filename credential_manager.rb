require 'bcrypt'

class CredentialManager
  def initialize(env="")
    @env = env
    @path = credential_store_path
    @credentials = load
  end

  def valid?(username, password)
    return false unless user_exists?(username)

    BCrypt::Password.new(password(username)) == password
  end

  def user_exists?(user)
    @credentials.key?(user)
  end

  def close
    File.open(@path, 'w') do |file|
      file.write(YAML.dump(@credentials))
    end
    @credentials = nil
  end

  def cache_password(username, password)
    @credentials[username] = BCrypt::Password.create(password).to_s
  end

  private

  def credential_store_path
    if @env == 'test'
      File.expand_path('../test/users.yaml', __FILE__)
    else
      File.expand_path('../users.yaml', __FILE__)
    end
  end

  def load
    if File.exist?(@path)
      YAML.load_file(@path)
    else
      {}
    end
  end

  def password(username)
    @credentials[username]
  end
end