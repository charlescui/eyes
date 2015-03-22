module Eyes
    module SegmentDog
        class Handler < EventMachine::ProcessWatch
            def initialize(opts={})
                @m3u8 = opts[:m3u8]
                @fnreg = opts[:fnreg]
                @last_ts = opts[:last_ts]
                super
            end

            def file_modified
                Eyes::Utils.log "#{path} modified"
                Dir[File.join(File.dirname(@m3u8), '*.ts')].each{|x|
                    # 如果比@last_ts大，则上传
                    # 如果比@last_ts小，则删除
                    name = File.basename(x)
                    if(@fnreg =~ name)
                        ts = $1.to_i
                        if (ts < @last_ts)
                            clean(x)
                        else
                            upload(x)
                            @last_ts = ts
                        end
                    end
                }
            end

            def file_moved
                Eyes::Utils.log "#{path} moved"
            end

            def file_deleted
                Eyes::Utils.log "#{path} deleted"
            end

            def unbind
                Eyes::Utils.log "#{path} monitoring ceased"
            end

            def clean(path)
                Eyes::Utils.log "Delete expired file #{path}, and seq #{$1}"
                FileUtils.rm_f(path)
            end

            def upload(path)
                File.open(path, 'r'){|f|
                    opath = oss_path(path)
                    oss.put opath, f
                    Eyes::Utils.log "put file to oss : #{opath}"
                }
            end

            def file_path(ts)
                File.join(File.dirname(@m3u8), "#{ts}.ts")
            end

            def oss_path(path)
                now = Time.now
                name = File.basename(path)
                "/#{now.year}/#{now.mon}/#{now.day}/#{now.hour}/#{name}"
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
    end
end