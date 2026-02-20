# frozen_string_literal: true
ruby ">= 3.2"

# stdlib gems for Ruby 3.4/4.0+
gem "ostruct", require: false
gem "ruby-progressbar"
gem "base64"
gem "bigdecimal"
gem "webrick"

# local gems in UDB
gem "idlc", path: "tools/ruby-gems/idlc"
gem "idl_highlighter", path: "tools/ruby-gems/idl_highlighter"
gem "udb", path: "tools/ruby-gems/udb"
gem "udb-gen", path: "tools/ruby-gems/udb-gen"
gem "udb_helpers", path: "tools/ruby-gems/udb_helpers"

source "https://rubygems.org"

gem "activesupport"
gem "asciidoctor-diagram", "~> 2.2"
gem "asciidoctor-pdf"
gem "concurrent-ruby", require: "concurrent"
gem "concurrent-ruby-ext"
gem "json_schemer", "~> 1.0"
gem "rake", "~> 13.0"
gem "sorbet-runtime"
gem "ttfunk", "1.7" # needed to avoid having asciidoctor-pdf dependencies pulling in a buggy version of ttunk (1.8)
gem "write_xlsx"
gem "yard"

group :development do
  gem "awesome_print"
  gem "debug"
  gem "rdbg"
  gem "rubocop-github"
  gem "rubocop-minitest"
  gem "rubocop-performance"
  gem "rubocop-sorbet"
  # gem "ruby-prof"
  gem "sorbet"
  gem "spoom"
  gem "tapioca", "= 0.16.11", require: false
end

group :development, :test do
  gem "minitest"
  gem "simplecov"
  gem "simplecov-cobertura"
end
