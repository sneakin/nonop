Gem::Specification.new do |s|
  s.name        = '9prb'
  s.version     = '0.1.0'
  s.licenses    = ['MIT']
  s.summary     = "A pure Ruby 9p library."
  #s.description = "Much longer explanation of the example!"
  s.authors     = ["Nolan Eakins <sneakin@semanticgap.com>"]
  s.email       = 'support@semanticgap.com'
  s.files       = [ "lib/**/*.rb" ]
  s.homepage    = 'https://oss.semanticgap.com/ruby/9prb'
  s.metadata    = {
    "source_code_uri" => "https://github.com/sneakin/9prb"
  }
  s.executables = [ 'bin/9pserve' ]
  s.require_paths = [ 'lib' ]
  s.add_dependency 'sg'
  s.add_dependency 'rdoc'
  s.add_dependency 'rspec'
end
