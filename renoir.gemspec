# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'renoir/version'

Gem::Specification.new do |spec|
  spec.name          = "renoir"
  spec.version       = Renoir::VERSION
  spec.authors       = ["Hiroshi Saito"]
  spec.email         = ["saito.die@gmail.com"]

  spec.summary       = %q{Reliable Redis Cluster client library}
  spec.description   = %q{Reliable Redis Cluster client library.}
  spec.homepage      = "https://github.com/saidie/renoir"
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0").reject do |f|
    f.match(%r{^(test|spec|features)/})
  end
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency 'redis', "~> 3.2"

  spec.add_development_dependency "bundler", "~> 1.13"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "minitest", "~> 5.0"
end
