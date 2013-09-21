inject_into_file 'Gemfile', after: %(source 'https://rubygems.org'\n) do <<-'STR'
ruby '2.0.0'
STR
end

gem 'haml-rails'
gem 'unicorn'
gem 'draper'
gem 'newrelic_rpm'
gem 'lograge'
gem 'rack-timeout'
gem 'rails_12factor', group: :production

gem 'rspec-rails', :group => [:test, :development]
gem_group :test do
  gem "activerecord-nulldb-adapter"
end

run "bundle install"

application  <<-GENERATORS
config.generators do |g|
  g.template_engine :haml
  g.test_framework  :rspec, :fixture => true, :views => false
  g.integration_tool :rspec, :fixture => true, :views => true
  g.fixture_replacement :factory_girl, :dir => "spec/support/factories"
end
GENERATORS

generate "rspec:install"

run "rm public/index.html"
inside("app/views/layouts") do
  run "rm application.html.erb"
  create_file "application.html.haml", <<-APPLICATION_STR
!!!
%html
  %head
    %title= @page_title
    %meta{:charset => 'UTF-8'}
    %meta{:name => 'description', :content => @meta_decription}

    = stylesheet_link_tag 'application'
    = javascript_include_tag 'application'

  %body
    #main{role: 'main'}
      .container
        = yield
    %footer#footer
      .container

APPLICATION_STR
end

create_file 'config/unicorn.rb', <<-UNICORN
# https://devcenter.heroku.com/articles/rails-unicorn
worker_processes Integer(ENV["WEB_CONCURRENCY"] || 3)
timeout Integer(ENV["UNICORN_TIMEOUT"] || 15)
preload_app true

# https://devcenter.heroku.com/articles/forked-pg-connections
before_fork do |server, worker|

  Signal.trap 'TERM' do
    puts 'Unicorn master intercepting TERM and sending myself QUIT instead'
    Process.kill 'QUIT', Process.pid
  end

  defined?(ActiveRecord::Base) and
    ActiveRecord::Base.connection.disconnect!
end

after_fork do |server, worker|

  Signal.trap 'TERM' do
    puts 'Unicorn worker intercepting TERM and doing nothing. Wait for master to send QUIT'
  end

  defined?(ActiveRecord::Base) and
    ActiveRecord::Base.establish_connection
end
UNICORN

create_file 'Procfile', <<-PROCFILE
web: bundle exec unicorn -p $PORT -c config/unicorn.rb
PROCFILE

initializer 'timeout.rb', <<-TIMEOUT_STR
Rack::Timeout.timeout = Integer(ENV["RACK_TIMEOUT"] || 10)

# Don't log to stdout in test env. Very noisy.
if Rails.env.test?
  Rack::Timeout.unregister_state_change_observer(:logger)
end
TIMEOUT_STR

inject_into_file 'app/controllers/application_controller.rb', after: "  protect_from_forgery with: :exception\n" do <<-CONTROLLER_STR

  # https://github.com/roidrage/lograge/issues/23
  # http://apidock.com/rails/v3.2.8/ActionController/Instrumentation/append_info_to_payload
  def append_info_to_payload(payload)
    super
    payload[:request_id] = request.env['HTTP_HEROKU_REQUEST_ID']
  end

CONTROLLER_STR
end

application(nil, env: "production") do
  %(  # https://github.com/roidrage/lograge
  config.lograge.enabled = true
  config.lograge.custom_options = lambda do |event|
    {
      user: event.payload[:user],
      request_id: event.payload[:request_id]
    }
  end)
end

append_file 'public/robots.txt', <<-ROBOTS_TXT

User-agent: *
Allow: /
ROBOTS_TXT

git :init

say "#{app_const} Generated!"
