# frozen_string_literal: true

require "rake/testtask"

Rake::TestTask.new(:test) do |t|
  t.libs << "test"
  t.libs << "lib"
  t.test_files = FileList["test/**/*_test.rb"]
end

task default: :test

desc "Build the gem into the pkg directory"
task :build do
  FileUtils.mkdir_p("pkg")
  system("gem build frausto.gemspec -o pkg/frausto.gem")
end

desc "Build and install the gem locally for testing"
task install: :build do
  system("gem install pkg/frausto.gem")
end

desc "Uninstall, rebuild, and reinstall the gem"
task :reinstall do
  system("gem uninstall frausto -x --force") # -x removes executables, --force skips confirmation
  Rake::Task[:install].invoke
end
