#!/usr/bin/env ruby
require "fileutils"
require "eventmachine"
require File.join(File.dirname(__FILE__), 'lib', 'eyes.rb')

$fnreg = /(\d+)\.ts$/
$m3u8 = ARGV[0]
$last_ts = Dir[File.join(File.dirname($m3u8), '*.ts')].map{|x|
            name = File.basename(x)
            if($fnreg =~ name)
                $1.to_i
            else
                nil
            end
        }.compact.max

module Handler
    def file_modified
        puts "#{path} modified"
        clean
    end

    def file_moved
        puts "#{path} moved"
    end

    def file_deleted
        puts "#{path} deleted"
    end

    def unbind
        puts "#{path} monitoring ceased"
    end

    def clean
        # seq = `cat #{path} |grep "#EXT-X-MEDIA-SEQUENCE:"|grep -v grep|cut -f2 -d\:`.chomp.to_i
        Dir[File.join(File.dirname($m3u8), '*.ts')].each{|x|
            # 如果比$last_ts大，则上传
            # 如果比$last_ts小，则删除
            name = File.basename(x)
            if($fnreg =~ name)
                ts = $1.to_i
                if (ts < $last_ts)
                    puts "Delete expired file #{x}, and seq #{$1}"
                    FileUtils.rm_f(x)
                else
                    upload(ts)
                    $last_ts = ts
                end
            end
        }
    end

    def upload(ts)
        File.open(file_path(ts), 'r'){|f|
            path = oss_path(ts)
            oss.put path, f
            puts "put file to oss : #{path}"
        }
    end

    def file_path(ts)
        File.join(File.dirname($m3u8), "#{ts}.ts")
    end

    def oss_path(ts)
        now = Time.now
        "/#{now.year}/#{now.mon}/#{now.day}/#{now.hour}/#{ts}.ts"
    end

    def oss
        @oss ||= ::Aliyun::Connection.new(config)
    end

    def config
        @config ||= {
            :aliyun_access_id => ENV["aliyun_access_id"],
            :aliyun_access_key => ENV["aliyun_access_key"],
            :aliyun_bucket => ENV["aliyun_bucket"],
            :aliyun_area => ENV["aliyun_area"]
        }
    end
end

Signal.trap('QUIT'){EM.stop;puts "Stop monit #{$m3u8}."}
Signal.trap('INT'){EM.stop;puts "Stop monit #{$m3u8}."}

# for efficient file watching, use kqueue on Mac OS X
EventMachine.kqueue = true if EventMachine.kqueue?

EventMachine.run {
    EventMachine.watch_file($m3u8, Handler)
}
