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
    # OR trips_table.where(user_id: @current_user[:id].to_a)
    
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
    @posterid = users_table.where(id: @trip[:user_id]).to_a[0][:id]

    likes_table.insert(
        trip_id: params["id"],
        user_id: session["user_id"]
    )

    redirect "/"
end

get "/like/success/:id/profile" do
    puts "params: #{params}"   
    @trip = trips_table.where(id: params[:id]).to_a[0]
    @poster = users_table.where(id: @trip[:user_id]).to_a[0][:name]
    @posterid = users_table.where(id: @trip[:user_id]).to_a[0][:id]

    likes_table.insert(
        trip_id: params["id"],
        user_id: session["user_id"]
    )

    redirect "/user/#{@posterid}"
end

get "/unlike/success/:id" do
    puts "params: #{params}"   

    @trip = trips_table.where(id: params[:id]).to_a[0]
    @poster = users_table.where(id: @trip[:user_id]).to_a[0][:name]
    @posterid = users_table.where(id: @trip[:user_id]).to_a[0][:id]

    likes_table.where(user_id: @current_user[:id], trip_id: params["id"]).delete

    redirect "/"
end

get "/unlike/success/:id/profile" do
    puts "params: #{params}"   

    @trip = trips_table.where(id: params[:id]).to_a[0]
    @poster = users_table.where(id: @trip[:user_id]).to_a[0][:name]
    @posterid = users_table.where(id: @trip[:user_id]).to_a[0][:id]

    likes_table.where(user_id: @current_user[:id], trip_id: params["id"]).delete

    redirect "/user/#{@posterid}"
end

get "/user/:id" do
    puts "params: #{params}"
    
    @usertrips = trips_table.where(user_id: params[:id]).to_a
    @username = users_table.where(id: params[:id]).to_a[0][:name]
    @userid = users_table.where(id: params[:id]).to_a[0][:id]
    @following_list = following_table.where(user_id: @userid).to_a
    @follower_list = following_table.where(target_user: params[:id]).to_a

    if not @current_user
        redirect "/logins/new"
    else 
        view "user_trips"
    end
end

get "/addtrip" do
    view "add_trip"
end

post "/addtrip/create" do
    puts "params: #{params}"
    
    trips_table.insert(
        user_id: session["user_id"],    
        location: params["location"],
        lengthnum: params["lengthnum"],
        lengthunit: params["lengthunit"],
        description: params["description"]               
    )    

    @usertrips = trips_table.where(user_id: @current_user[:id]).to_a
    @username = users_table.where(id: @current_user[:id]).to_a[0][:name]
    @userid = @current_user[:id]

    view "user_trips"
end

get "/follow/user/:id" do
    puts "params: #{params}"

    @following_username = users_table.where(id: params[:id]).to_a[0][:name]
    @following_userid = users_table.where(id: params[:id]).to_a[0][:id]

    following_table.insert(
        user_id: @current_user[:id],   
        target_user: @following_userid      
    )   

    redirect "/user/#{params[:id]}"
end

get "/unfollow/user/:id" do
    puts "params: #{params}"

    following_table.where(user_id: @current_user[:id], target_user: params["id"]).delete

    redirect "/user/#{params[:id]}"
end

get "/trip/:id/edit" do
    puts "params: #{params}"
    @trip = trips_table.where(id: params[:id]).to_a[0]
    view "edit_trip"
end

post "/trip/:id/update" do
    puts "params: #{params}"
    @trip = trips_table.where(id: params[:id]).to_a[0]
    @user = users_table.where(id: @trip[:user_id]).to_a[0]

    trips_table.where(id: params["id"]).update(
        user_id: session["user_id"],    
        location: params["location"],
        lengthnum: params["lengthnum"],
        lengthunit: params["lengthunit"],
        description: params["description"]
    )

    redirect "/user/#{@user[:id]}"
end

get "/trip/:id/destroy" do
    puts "params: #{params}"

    @trip = trips_table.where(id: params[:id]).to_a[0]
    @user = users_table.where(id: @trip[:user_id]).to_a[0]
    
    trips_table.where(id: params["id"]).delete

    redirect "/user/#{@user[:id]}"
end

get "/discover" do
    view "/discover"
end