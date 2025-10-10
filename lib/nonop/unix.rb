module NonoP::Unix
  class DBFile
    attr_reader :path
    
    def initialize path
      @path = path
    end

    def each
      return to_enum(__method__) unless block_given?
      File.readlines(path).each do |l|
        yield(l.split(':'))
      end
    end

    include Enumerable

    def find_by key, value
      find { _1[key] == value }
    end
  end

  class Passwd
    def each
      return to_enum(__method__) unless block_given?
      Etc.endpwent
      while e = Etc.getpwent
        yield(e)
      end
    end

    include Enumerable

    def find_by key, value
      find { _1[key] == value }
    end
  end
end
