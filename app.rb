# Set up for the application and database. DO NOT CHANGE. #############################
require "sinatra"                                                                     #
require "sinatra/reloader" if development?                                            #
require "sequel"                                                                      #
require "logger"                                                                      #
require "twilio-ruby"                                                                 #
require "bcrypt"                                                                      #
connection_string = ENV['DATABASE_URL'] || "sqlite://#{Dir.pwd}/development.sqlite3"  #
DB ||= Sequel.connect(connection_string)                                              #
DB.loggers << Logger.new($stdout) unless DB.loggers.size > 0                          #
def view(template); erb template.to_sym; end                                          #
use Rack::Session::Cookie, key: 'rack.session', path: '/', secret: 'secret'           #
before { puts; puts "--------------- NEW REQUEST ---------------"; puts }             #
after { puts; }                                                                       #
#######################################################################################

trips_table = DB.from(:trips)
users_table = DB.from(:users)
following_table = DB.from(:following)
likes_table = DB.from(:likes)

before do
    @current_user = users_table.where(id: session["user_id"]).to_a[0]
end

get "/" do
    puts "params: #{params}"

    @users_table = users_table
    pp @users_table
    @feed = trips_table.all.to_a
    pp @feed

    view "feed"
end

get "/users/new" do
    view "new_user"
end

post "/users/create" do
    puts "params: #{params}"

    existing_user = users_table.where(email: params["email"]).to_a[0]
    if existing_user
        view "error"
    else
        users_table.insert(
            name: params["name"],
            email: params["email"],
            password: BCrypt::Password.create(params["password"])
        )

        redirect "/signup/success"
    end
end

get "/signup/success" do
    view "new_user_success"
end

get "/logins/new" do
    view "new_login"
end

post "/logins/create" do
    puts "params: #{params}"

    # step 1: user with the params["email"] ?
    @user = users_table.where(email: params["email"]).to_a[0]

    if @user
        # step 2: if @user, does the encrypted password match?
        if BCrypt::Password.new(@user[:password]) == params["password"]
            # set encrypted cookie for logged in user
            session["user_id"] = @user[:id]
            redirect "/"
        else
            view "error"
        end
    else
        view "error"
    end
end

get "/logout" do
    # remove encrypted cookie for logged out user
    session["user_id"] = nil
    redirect "/logins/new"
end

get "/like/success/:id" do
    puts "params: #{params}"   
    
    @trip = trips_table.where(id: params[:id]).to_a[0]
    @poster = users_table.where(id: @trip[:user_id]).to_a[0][:name]

    likes_table.insert(
        trip_id: params["id"],
        user_id: session["user_id"]
    )

    view "like_success"
end

get "/unlike/success/:id" do
    puts "params: #{params}"   
    
    @trip = trips_table.where(id: params[:id]).to_a[0]
    @poster = users_table.where(id: @trip[:user_id]).to_a[0][:name]

    likes_table.insert(
        trip_id: params["id"],
        user_id: session["user_id"]
    )

    view "unlike_success"
end