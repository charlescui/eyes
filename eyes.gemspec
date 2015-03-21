# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'eyes/version'

Gem::Specification.new do |spec|
  spec.name          = "eyes"
  spec.version       = Eyes::VERSION
  spec.authors       = ["cuizheng"]
  spec.email         = ["zheng.cuizh@gmail.com"]
  spec.description   = %q{video streaming and storage }
  spec.summary       = %q{video streaming and storage }
  spec.homepage      = ""
  spec.license       = "MIT"

  spec.files         = `git ls-files`.split($/)
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.3"
  spec.add_development_dependency "rake"

  spec.add_runtime_dependency 'rest-client', '>= 1.6.7'
  spec.add_runtime_dependency 'eventmachine'
end
