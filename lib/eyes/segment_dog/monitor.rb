module Eyes
    module SegmentDog
        class Monitor
            def initialize(opts={})
                @opts = opts
            end

            def monit
                Signal.trap('QUIT'){EM.stop;puts "Stop monit #{@opts[:m3u8]}."}
                Signal.trap('INT'){EM.stop;puts "Stop monit #{@opts[:m3u8]}."}
                
                EventMachine.watch_file(@opts[:m3u8], Handler, @opts)
            end
        end
    end
end