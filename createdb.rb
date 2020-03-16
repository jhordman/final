# Set up for the application and database. DO NOT CHANGE. #############################
require "sequel"                                                                      #
connection_string = ENV['DATABASE_URL'] || "sqlite://#{Dir.pwd}/development.sqlite3"  #
DB = Sequel.connect(connection_string)                                                #
#######################################################################################

# Database schema - this should reflect your domain model
DB.create_table! :trips do
  primary_key :id
  foreign_key :user_id
  String :location
  String :lengthnum
  String :lengthunit
  String :description, text: true
end

DB.create_table! :users do
  primary_key :id
  String :name
  String :email
  String :password
end

DB.create_table! :following do
  primary_key :id
  foreign_key :user_id
  String :target_user
end

DB.create_table! :likes do
  primary_key :id
  foreign_key :trip_id
  foreign_key :user_id
end

# Insert initial (seed) data
trips_table = DB.from(:trips)
users_table = DB.from(:users)
likes_table = DB.from(:likes)
following_table = DB.from(:following)

trips_table.insert(user_id: 1,
                    location: "China",
                    lengthnum: 2,
                    lengthunit: "Weeks",
                    description: "I visited amazing places and discovered all sorts of cool things.")

users_table.insert(name: "Marco Polo",
                    email: "marcopolo@gmail.com",
                    password: "silkroad")

puts "Success!"