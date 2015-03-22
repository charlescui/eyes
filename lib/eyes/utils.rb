module Eyes
    class Utils
        def self.log(msg)
            puts "Eyes [#{$$}] - #{Time.now} : #{msg}" if $DEBUG
        end
    end
end