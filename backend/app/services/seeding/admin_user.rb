module Seeding
  # Creates (or updates the password of) an administrator's login, promoting the account if the email already
  # belongs to an HR login. Credentials come from the caller, never from the source code.
  module AdminUser
    module_function

    def ensure!(email:, password:)
      user = User.find_or_initialize_by(email: email)
      user.password = password
      user.admin = true
      user.save!
      user
    end
  end
end
