module Seeding
  # Creates (or updates the password of) the HR manager's login. Credentials come from the caller,
  # never from the source code.
  module HrUser
    module_function

    def ensure!(email:, password:)
      user = User.find_or_initialize_by(email: email)
      user.password = password
      user.save!
      user
    end
  end
end
