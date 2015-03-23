#!/usr/bin/env ruby
require File.join(File.dirname(__FILE__), '..', 'lib', 'eyes.rb')
require 'erb'

fnreg = /(\d+)\.ts$/

$DEBUG = true

# for efficient file watching, use kqueue on Mac OS X
EventMachine.kqueue = true if EventMachine.kqueue?

@monit = Eyes::WatchDog::Monitor.new

m3u8_tmpl=<<-DOC
#EXTM3U
#EXT-X-VERSION:3
#EXT-X-ALLOW-CACHE:YES
#EXT-X-MEDIA-SEQUENCE:<%= $seq%>
#EXT-X-TARGETDURATION:<%= duration %>
#EXTINF:<%= duration %>,
<%= uri %>
DOC

$seq = 0
callback = proc{|path, oss_path, segment_item|
    $seq += 1
    uri = oss_path
    duration = segment_item.duration
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
            :callback => callback
        )
        @eye.monit
#    }
}
