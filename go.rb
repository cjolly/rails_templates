gem "haml-rails"
gem "compass"

gem "unicorn", :group => :development
gem "capistrano", :group => :development

gem 'rspec', :group => :test
gem 'rspec-rails', :group => :test
gem "factory_girl_rails", :group => :test

gem 'cucumber', :group => :test
gem 'cucumber-rails', :group => :test

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
generate "cucumber:install --capybara --rspec"

run "compass init rails --using=blueprint --sass-dir=app/stylesheets --css-dir=public/stylesheets"

inside("app/views/layouts") do
  run "rm application.html.erb"
  get "https://github.com/cjolly/rails3_template/raw/master/assets/application.html.haml", "application.html.haml"
end

append_file 'public/robots.txt', <<-ROBOTS_TXT

User-agent: *
Allow: /
ROBOTS_TXT

# git :init
# git :add => '.'
# git :commit => '-am "Initial commit"'

say "#{app_const} Generated!"