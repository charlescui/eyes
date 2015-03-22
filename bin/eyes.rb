#!/usr/bin/env ruby
require File.join(File.dirname(__FILE__), '..', 'lib', 'eyes.rb')

last_ts = Dir[File.join(File.dirname($m3u8), '*.ts')].map{|x|
            name = File.basename(x)
            if($fnreg =~ name)
                $1.to_i
            else
                nil
            end
        }.compact.max

$DEBUG = true

# for efficient file watching, use kqueue on Mac OS X
EventMachine.kqueue = true if EventMachine.kqueue?

@monit = Eyes::WatchDog::Monitor.new

EventMachine.run {
    @monit.monit{
        @eye = Eyes::SegmentDog::Monitor.new(
            :m3u8 => ARGV[0],
            :fnreg => /(\d+)\.ts$/,
            :last_ts => last_ts
        )
        @eye.monit
    }
}
