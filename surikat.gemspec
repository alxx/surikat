# coding: utf-8
lib = File.expand_path("../lib", __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "surikat/version"

Gem::Specification.new do |spec|
  spec.name          = "surikat"
  spec.version       = Surikat::VERSION
  spec.authors       = ["Alex Deva"]
  spec.email         = ["me@alxx.se"]

  spec.summary       = %q{An API-only, GraphQL centric web framework.}
  spec.description   = %q{Surikat is a web framework that revolves around GraphQL, offering a lot of ready-made functionality such as CRUD operations, automatic query generation, authentication and performance optimisations.}
  spec.homepage      = "https://github.com/alxx/surikat"
  spec.license       = "MIT"

  # Prevent pushing this gem to RubyGems.org. To allow pushes either set the 'allowed_push_host'
  # to allow pushing to a single host or delete this section to allow pushing to any host.
  if spec.respond_to?(:metadata)
    #spec.metadata["allowed_push_host"] = "http://someplace.org"
  else
    raise "RubyGems 2.0 or newer is required to protect against " \
      "public gem pushes."
  end

  spec.files         = `git ls-files -z`.split("\x0").reject do |f|
    f.match(%r{^(test|spec|features)/}) || f.match(/^surikat-.+.gem$/)
  end
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.15"
  #spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "rspec", "~> 3.0"
  spec.add_development_dependency "pry", "~> 0.10"

  spec.add_development_dependency "activesupport", "~> 5.2", ">= 5.2.0"
  spec.add_development_dependency "graphql-libgraphqlparser", "~> 1.2", ">= 1.2.0"
  spec.add_development_dependency "oj", "~> 3.3", ">= 3.3.5"
#  spec.add_development_dependency "standalone_migrations", "~> 5.2", ">= 5.2.5"
#  spec.add_development_dependency "ransack", "~> 1.8", ">= 1.8.2"


end
