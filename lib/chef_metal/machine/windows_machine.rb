require 'chef_metal/machine/basic_machine'

module ChefMetal
  class Machine
    class WindowsMachine < BasicMachine
      def initialize(node, transport, convergence_strategy)
        super
      end

      # Options include:
      #
      # command_prefix - prefix to put in front of any command, e.g. sudo
      attr_reader :options

      # Delete file
      def delete_file(provider, path)
        if file_exists?(path)
          provider.converge_by "delete file #{escape(path)} on #{node['name']}" do
            transport.execute("Remove-Item #{escape(path)}").error!
          end
        end
      end

      # Return true or false depending on whether file exists
      def file_exists?(path)
        parse_boolean(transport.execute("Test-Path #{escape(path)}").stdout)
      end

      def files_different?(path, local_path, content=nil)
        # Get remote checksum of file (from http://stackoverflow.com/a/13926809)
        result = transport.execute <<-EOM
$md5 = [System.Security.Cryptography.MD5]::Create("MD5")
$fd = [System.IO.File]::OpenRead(#{path.inspect})
$buf = new-object byte[] (1024*1024*8) # 8mb buffer
while (($read_len = $fd.Read($buf,0,$buf.length)) -eq $buf.length){
    $total += $buf.length
    $md5.TransformBlock($buf,$offset,$buf.length,$buf,$offset)
}
# finalize the last read
$md5.TransformFinalBlock($buf,0,$read_len)
$hash = $md5.Hash
# convert hash bytes to hex formatted string
$hash | foreach { $hash_txt += $_.ToString("x2") }
$hash_txt
EOM
        result.error!
        remote_sum = result.stdout.split(' ')[0]
        digest = Digest::SHA256.new
        if content
          digest.update(content)
        else
          File.open(local_path, 'rb') do |io|
            while (buf = io.read(4096)) && buf.length > 0
              digest.update(buf)
            end
          end
        end
        remote_sum != digest.hexdigest
      end

      def create_dir(provider, path)
        if !file_exists?(path)
          provider.converge_by "create directory #{path} on #{node['name']}" do
            transport.execute("New-Item #{escape(path)} -Type directory")
          end
        end
      end

      # Set file attributes { :owner, :group, :rights }
#      def set_attributes(provider, path, attributes)
#      end

      # Get file attributes { :owner, :group, :rights }
#      def get_attributes(path)
#      end

      def dirname_on_machine(path)
        path.split(/[\\\/]/)[0..-2].join('\\')
      end

      def escape(string)
        transport.escape(string)
      end

      def parse_boolean(string)
        if string =~ /^\s*true\s*$/mi
          true
        else
          false
        end
      end
    end
  end
end