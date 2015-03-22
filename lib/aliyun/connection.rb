# encoding: utf-8

require 'digest/hmac'
require 'digest/md5'
require "rest-client"
require "base64"
require 'uri'

module Aliyun
  class Connection
    def initialize(options = {})
      @aliyun_access_id  = options[:aliyun_access_id]
      @aliyun_access_key = options[:aliyun_access_key]
      @aliyun_bucket     = options[:aliyun_bucket]
      @aliyun_area       = (options[:aliyun_area] and options[:aliyun_area].to_s.downcase) || 'cn-hangzhou'
      @aliyun_upload_host = options[:aliyun_upload_host]

      # Host for upload
      if @aliyun_upload_host.nil?
        if options[:aliyun_internal] == true
          @aliyun_upload_host = "http://#{@aliyun_bucket}.oss-#{@aliyun_area}-internal.aliyuncs.com"
        else
          @aliyun_upload_host = "http://#{@aliyun_bucket}.oss-#{@aliyun_area}.aliyuncs.com"
        end
      end

      # Host for get request
      @aliyun_host = options[:aliyun_host] || "http://#{@aliyun_bucket}.oss-#{@aliyun_area}.aliyuncs.com"

      if not @aliyun_host.include?("http")
        raise "config.aliyun_host requirement include http:// or https://, but you give: #{@aliyun_host}"
      end
    end

    # 上传文件
    # params:
    # - path - remote 存储路径
    # - file - 需要上传文件的 File 对象
    # - options:
    #   - content_type - 上传文件的 MimeType，默认 `image/jpg`
    # returns:
    # 图片的下载地址
    def put(path, file, options={})
      path         = format_path(path)
      bucket_path  = get_bucket_path(path)
      # 阿里云要求先得到文件的16进制MD5
      # 然后再做Base64
      # 不可以使用这种方式直接获取文件MD5： Digest::MD5.file(file)，否则包400错误
      file_md5     = Digest::MD5.digest(IO.read(file.path))
      content_md5  = Base64.encode64(file_md5).chomp
      content_type = options[:content_type] || "image/jpg"
      date         = gmtdate
      url          = path_to_url(path)
      oss_headers  = options[:oss_headers] || {}
      
      host = URI.parse(url).host

      auth_sign    = sign("PUT", bucket_path, content_md5, content_type, oss_headers, date)
      headers      = {
        "Authorization"  => auth_sign,
        "Content-Type"   => content_type,
        "Content-Md5" => content_md5,
        # "Content-Length" => file.size,
        "Date"           => date,
        "Host"           => host
        # "Expect"         => "100-Continue"
      }.merge(oss_headers)

      begin
        RestClient.put(url, file, headers)
      rescue Exception => e
        puts e
        raise e
      end
      return path_to_url(path, :get => true)
    end

    # 读取文件
    # params:
    # - path - remote 存储路径
    # returns:
    # file data
    def get(path)
      path = format_path(path)
      url  = path_to_url(path)
      RestClient.get(URI.encode(url))
    end

=begin rdoc
检查远程服务器是否已存在指定文件
== 参数:
- path - remote 存储路径
== 返回值:
true/false
=end
    def exists?(path)
      path = format_path(path)
      bucket_path = get_bucket_path(path)
      date = gmtdate
      headers = {
        "Host" => URI.parse(@aliyun_upload_host).host,
        "Date" => date,
        "Authorization" => sign("HEAD", bucket_path, "", "", "", date)
      }
      url = path_to_url(path)

      # rest_client will throw exception if requested resource not found
      begin
        response = RestClient.head(URI.encode(url), headers)
      rescue RestClient::ResourceNotFound
        return false
      end

      true
    end

    # 删除 Remote 的文件
    #
    # params:
    # - path - remote 存储路径
    #
    # returns:
    # 图片的下载地址
    def delete(path)
      path        = format_path(path)
      bucket_path = get_bucket_path(path)
      date        = gmtdate
      url         = path_to_url(path)
      host        = URI.parse(url).host
      headers     = {
        "Host"          => host,
        "Date"          => date,
        "Authorization" => sign("DELETE", bucket_path, "", "" , nil, date)
      }
      
      RestClient.delete(url, headers)
      return path_to_url(path, :get => true)
    end

    #
    # 阿里云需要的 GMT 时间格式
    def gmtdate
      Time.now.gmtime.strftime("%a, %d %b %Y %H:%M:%S GMT")
    end

    def format_path(path)
      return "" if !path
      path.gsub!(/^\//,"")

      path
    end

    def get_bucket_path(path)
      [@aliyun_bucket,path].join("/")
    end

    ##
    # 根据配置返回完整的上传文件的访问地址
    def path_to_url(path, opts = {})
      if opts[:get]
        "#{@aliyun_host}/#{path}"
      else
        "#{@aliyun_upload_host}/#{path}"
      end
    end

    def oss_headers_string(oss_headers={})
        if oss_headers.is_a?(Hash)
            keys = oss_headers.keys.sort
            keys.inject(""){|s, k| s<<"#{k}:#{oss_headers[k]}"<<"\n"}.downcase
        else
            nil
        end
    end

    private
    def sign(verb, path, content_md5 = '', content_type = '', oss_headers = nil, date)
      canonicalized_oss_headers = oss_headers_string(oss_headers)
      canonicalized_resource = "/#{path}"
      string_to_sign = "#{verb}\n#{content_md5}\n#{content_type}\n#{date}\n#{canonicalized_oss_headers}#{canonicalized_resource}"
      digest = OpenSSL::Digest.new('sha1')
      h = OpenSSL::HMAC.digest(digest, @aliyun_access_key, string_to_sign)
      h = Base64.encode64(h)
      "OSS #{@aliyun_access_id}:#{h.chomp}"
    end
  end
end
