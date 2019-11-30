# frozen_string_literal: true
# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'dataflow/embulk/version'

Gem::Specification.new do |spec|
  spec.name          = 'dataflow-embulk'
  spec.version       = Dataflow::Embulk::VERSION
  spec.authors       = ['Eurico Doirado']
  spec.email         = ['eurico@phybbit.com']

  spec.summary       = "dataflow-rb's extension that supports interacting with Embulk"
  spec.description   = "dataflow-rb's extension that supports interacting with Embulk"
  spec.homepage      = 'https://phybbit.com'
  spec.license       = 'MIT'

  spec.files         = `git ls-files -z`.split("\x0").reject do |f|
    f.match(%r{^(test|spec|features)/})
  end
  spec.bindir        = 'exe'
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  spec.required_ruby_version = '>= 2.3.0'

  spec.add_development_dependency 'bundler',    '~> 1.14'
  spec.add_development_dependency 'rake',       '~> 10.0'
  spec.add_development_dependency 'rspec',      '~> 3.0'
  spec.add_development_dependency 'pry-byebug', '~> 3.4'
  spec.add_development_dependency 'dotenv',     '~> 2.1'

  spec.add_dependency 'dataflow-rb', '>= 0.10'
end
