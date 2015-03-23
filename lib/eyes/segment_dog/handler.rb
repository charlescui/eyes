module Eyes
    module SegmentDog
        class Handler < EventMachine::FileWatch
            def initialize(opts={})
                @m3u8 = opts[:m3u8]
                @fnreg = opts[:fnreg]
                @callback = opts[:callback]
                super
            end

            # 通过m3u8库解析
            # ffmpeg生成时，只生成一个文件
            # 保证m3u8中只有一个ts记录
            # 让eyes可以获取片段元数据
            def file_modified
                Eyes::Utils.log "#{path} modified"
                segments = []

                meta{|segment_item|
                    name = File.basename(segment_item)
                    if(@fnreg =~ name)
                        ts = $1.to_i
                        segments << ts
                        path = file_path(ts)
                        upload(path, segment_item)
                    else
                        nil
                    end
                }

                # 找到当前m3u8中最小的时间戳
                # 所有小于该时间戳的文件，都可以删除
                latest = segments.min

                Dir[File.join(File.dirname(@m3u8), '*.ts')].map{|x|
                    name = File.basename(x)
                    if(@fnreg =~ name) and ($1.to_i < latest)
                        clean(x)
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

            private

            def meta
                File.open(@m3u8){|file|
                    playlist = M3u8::Playlist.read file
                    playlist.each { |e| yield e}
                }
            end

            def clean(path)
                Eyes::Utils.log "Delete expired file #{path}, and seq #{$1}"
                FileUtils.rm_f(path)
            end

            # 有内容更新的时候，要变更文件内容
            # 为了更方便的与外界第三方程序通信
            # 第三方程序可以使用inotify监听eyes.notify的变化，从而产生回调
            def notify_file(local_path, oss_path)
                File.open('eyes.notify', 'w+'){|f| f << "#{oss_path},#{local_path}" }
            end

            def upload(path, segment_item = nil)
                f = File.open(path, 'r')
                opath = oss_path(path)
                Eyes::Utils.log "put file to oss : #{opath}"
                begin
                    oss.put opath, f
                    # 回调事件
                    # 用于外界对上传文件完成后的处理
                    @callback and @callback.call(path, oss_full_path(opath), segment_item)
                    # 变更文件内容
                    notify_file(path, oss_full_path(opath))
                rescue RestClient::RequestTimeout => e
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