# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'tiramizoo/version'

Gem::Specification.new do |spec|
  spec.name          = "tiramizoo"
  spec.version       = Tiramizoo::VERSION
  spec.authors       = ["Tiramizoo"]
  spec.email         = ["tech@tiramizoo.com"]

  spec.summary       = %q{Tiramizoo API}
  spec.description   = %q{Tiramizoo API}
  spec.homepage      = "https://www.tiramizoo.com"

  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "excon"
  spec.add_development_dependency "bundler", "~> 1.10"
  spec.add_development_dependency "rake", "~> 10.0"
end
