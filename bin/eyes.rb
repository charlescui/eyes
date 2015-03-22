#!/usr/bin/env ruby
require File.join(File.dirname(__FILE__), '..', 'lib', 'eyes.rb')
require 'erb'

fnreg = /(\d+)\.ts$/
last_ts = Dir[File.join(File.dirname(ARGV[0]), '*.ts')].map{|x|
            name = File.basename(x)
            if(fnreg =~ name)
                $1.to_i
            else
                nil
            end
        }.compact.max

$DEBUG = true

# for efficient file watching, use kqueue on Mac OS X
EventMachine.kqueue = true if EventMachine.kqueue?

@monit = Eyes::WatchDog::Monitor.new

m3u8_tmpl=<<-DOC
#EXTM3U
#EXT-X-VERSION:3
#EXT-X-ALLOW-CACHE:YES
#EXT-X-TARGETDURATION:10
#EXTINF:10,
<%= uri %>
DOC

callback = proc{|path|
    uri = path
    m3u8 = ERB.new(m3u8_tmpl)
    File.open("living.m3u8", 'w+'){|f|
        f << m3u8.result(binding)
    }
}

EventMachine.run {
#    @monit.monit{
        @eye = Eyes::SegmentDog::Monitor.new(
            :m3u8 => ARGV[0],
            :fnreg => fnreg,
            :last_ts => last_ts,
            :callback => callback
        )
        @eye.monit
#    }
}
