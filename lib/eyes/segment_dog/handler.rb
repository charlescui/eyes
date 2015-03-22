module Eyes
    module SegmentDog
        class Handler < EventMachine::FileWatch
            def initialize(opts={})
                @m3u8 = opts[:m3u8]
                @fnreg = opts[:fnreg]
                @last_ts = opts[:last_ts]
                @callback = opts[:callback]
                super
            end

            def file_modified
                Eyes::Utils.log "#{path} modified"
                ts_array = Dir[File.join(File.dirname(@m3u8), '*.ts')].map{|x|
                    name = File.basename(x)
                    if(@fnreg =~ name)
                        $1.to_i
                    else
                        nil
                    end
                }.compact.sort

                # 时间戳最大的那个文件还在被FFMPEG写入中
                # 不能上传该文件，留作下一次上传
                dirty = ts_array.pop
                Eyes::Utils.log "#{file_path dirty} is modifing!"

                ts_array.each { |ts|  
                    path = file_path(ts)
                    # 如果比@last_ts大，则上传
                    # 如果比@last_ts小，则删除
                    if (ts < @last_ts)
                        clean(path)
                    else
                        upload(path)
                        @last_ts = ts
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
                f = File.open(path, 'r')
                opath = oss_path(path)
                Eyes::Utils.log "put file to oss : #{opath}"
                begin
                    oss.put opath, f
                    # 回调事件
                    # 用于外界对上传文件完成后的处理
                    @callback and @callback.call(oss_full_path(opath))
                rescue RestClient::RequestTimeou => e
                    Eyes::Utils.log "upload file timeout : #{path}"
                rescue => e
                    Eyes::Utils.log "upload file failed : #{path}"
                    raise e
                end
            end

            def file_path(ts)
                File.join(File.dirname(@m3u8), "#{ts}.ts")
            end

            def oss_path(path)
                now = Time.now
                name = File.basename(path)
                "/#{now.year}/#{now.mon}/#{now.day}/#{now.hour}/#{name}"
            end

            def oss_full_path(path)
                oss.path_to_url(path)
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