namespace :gitlab do
  desc "GITLAB | Run both spinach and rspec"
  task test: ['spinach', 'spec']
  task parallel_test: ['parallel:features-spinach','parallel:spec']
end
