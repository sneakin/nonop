Gem::Specification.new do |s|
  s.name        = 'nonop'
  s.version     = '0.1.0'
  s.licenses    = ['MIT']
  s.summary     = "A pure Ruby 9p library."
  #s.description = "Much longer explanation of the example!"
  s.authors     = ["Nolan Eakins <sneakin@semanticgap.com>"]
  s.email       = 'support@semanticgap.com'
  s.files       = %w{ README.md COPYING } +
    Dir.glob('bin/{nonop,server,cat,put,ls,mkdir}') +
    Dir.glob("lib/**/*.rb")
  s.homepage    = 'https://oss.semanticgap.com/ruby/nonop'
  s.metadata    = {
    "source_code_uri" => "https://github.com/sneakin/nonop"
  }
  s.executables = [ 'nonop' ]
  s.require_paths = [ 'lib' ]
  s.add_dependency 'sg-gem'
  s.add_dependency 'org-ruby'
  s.add_dependency 'rake'
  s.add_dependency 'rdoc'
  s.add_dependency 'rspec'
  s.add_development_dependency 'solargraph'
  s.add_development_dependency 'simplecov'
end
