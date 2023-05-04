require 'faker'
require_relative 'relation'

# Creates a relation `users.db` filled with 2000 fake user records

fields = {
  id: DataTypes::INTEGER,
  first_name: DataTypes::STRING,
  last_name: DataTypes::STRING,
  username: DataTypes::STRING,
  passcode: DataTypes::STRING,
  city: DataTypes::STRING,
  state: DataTypes::STRING,
  karma: DataTypes::INTEGER
}

Relation.create('users', fields)

users = Relation.from_db_file('users.db')

2000.times do |n|
  users.insert(
    {
      id: n+1,
      first_name: Faker::Name.first_name,
      last_name: Faker::Name.last_name,
      username: Faker::Twitter.screen_name,
      passcode: Faker::Alphanumeric.alphanumeric(number: 10),
      city: Faker::Address.city,
      state: Faker::Address.state_abbr,
      karma: rand(1000000)
    }
  )
end