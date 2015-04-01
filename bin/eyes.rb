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
<% $segments3.each do|item| %>
#EXTINF:<%= item.duration %>,
<%= item.segment %>
<% end %>
DOC

$seq = 0
$segments3 = []
callback = proc{|path, oss_path, segment_item|
    segment_item.segment = oss_path
    begin
        upload_to_cinema(segment_item)
    rescue RestClient::UnprocessableEntity => e
        # 上传失败
        Eyes::Utils.log "UnprocessableEntity #{segment_item} upload failed!"
    rescue RestClient::InternalServerError => e
        # 上传失败
        Eyes::Utils.log "InternalServerError #{segment_item} upload failed!"
    end
    
    while $segments3.size > 2
        $segments3.shift
    end
    $segments3 << segment_item

    $seq += 1
    duration = $segments3.map{|item|item.duration.to_f}.max
    m3u8 = ERB.new(m3u8_tmpl)
    File.open("living.m3u8", 'w+'){|f|
        f << m3u8.result(binding).gsub("\n\n", "\n")
    }
}

$credentials = "UsFzScHX7XTSEhiEi71"

def upload_to_cinema(segment)
    data = {
        duration: segment.duration,
        segment: segment.segment,
        comment: segment.comment,
        byterange_length: segment.byterange_length,
        byterange_start: segment.byterange_start
    }
    RestClient.post "http://ongo360.com:3001/api/v1/segment?eye_credentials=#{$credentials}", data
end

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
