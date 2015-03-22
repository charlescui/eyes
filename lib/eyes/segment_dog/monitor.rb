module Eyes
    module SegmentDog
        class Monitor
            def initialize(opts={})
                @m3u8 = opts[:m3u8]
                @fnreg = opts[:fnreg]
                @last_ts = opts[:last_ts]
            end

            def monit
                opts = {
                    :m3u8 => @m3u8,
                    :fnreg => @fnreg,
                    :last_ts => @last_ts
                }
                Signal.trap('QUIT'){EM.stop;puts "Stop monit #{@m3u8}."}
                Signal.trap('INT'){EM.stop;puts "Stop monit #{@m3u8}."}
                
                EventMachine.watch_file(@m3u8, Handler, opts)
            end
        end
    end
end