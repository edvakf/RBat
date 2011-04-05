BEGIN {
class RBat
  NEW_RUBY_DIR = "ruby-dist"

  def initialize
    @pwd = Dir.pwd
    @script = $0
    @me = __FILE__
  end

  def make
    Dir.chdir(@pwd)
    collect_loaded_features

    # it's a windows-only script anyway
    require 'Win32API'
    require 'fileutils'
    require 'pathname'
    check_ruby
    clear_ruby_dir
    copy_files
    make_bat
  end

  # gather files that are 'require'd by this ruby process
  # it is important that no files are 'require'd in this script
  # before this method is called
  def collect_loaded_features
    @loaded_features = []
    $LOADED_FEATURES.each {|file|
      $LOAD_PATH.each {|dir|
        file_path = File.join(dir, file)
        if File.identical?(file_path, @me)
          next
        end
        if File.file?(file_path)
          @loaded_features << file_path
          next
        end
      }
    }
  end

  def check_ruby
    # DWORD WINAPI GetModuleFileName( __in_opt HMODULE hModule, __out LPTSTR lpFilename, __in DWORD nSize );
    win32_GetModuleFileName = Win32API.new('kernel32', 'GetModuleFileName', 'LPL', 'L')
    buf = '\0' * 260 # should check MAXPATHLEN?
    len = win32_GetModuleFileName.call(0, buf, buf.length)
    raise "An error occured in GetModuleFileName" if len == 0
    @ruby = buf[0..(len-1)]
    @ruby.gsub!(File::ALT_SEPARATOR, File::SEPARATOR) unless File::ALT_SEPARATOR.nil?
    # if ruby is foo/bin/ruby.exe then prefix is foo
    # otherwise (ruby is foo/ruby.exe), prefix is foo
    @prefix = File.dirname(@ruby)
    if File.basename(@prefix).downcase == "bin"
      @prefix = File.dirname(@prefix)
    end

    # below is more standard way, but it cannot tell apart
    # between ruby.exe and rubyw.exe, and also
    # fails if ruby was run from a non-standard path
    #require 'rbconfig'
    #@prefix = RbConfig::CONFIG['prefix']
    #@ruby = File::join(RbConfig::CONFIG['bindir'],
                       #RbConfig::CONFIG['ruby_install_name']) + 
                       #RbConfig::CONFIG['EXEEXT']
  end

  def clear_ruby_dir
    @new_prefix = File.join(@pwd, NEW_RUBY_DIR)
    if File.exist?(@new_prefix)
      FileUtils.remove_entry(@new_prefix)
    end
    FileUtils.mkdir(@new_prefix)
  end

  def copy_files
    # copy ruby
    FileUtils.cp(@ruby, @new_prefix)
    # copy all .dll in the same directory as ruby
    ruby_dir = File.dirname(@ruby)
    Dir.glob(File.join(ruby_dir, "*.dll")).each{|file|
      FileUtils.cp(file, @new_prefix)
    }
    # copy all libraries under the ruby prefix
    prefix = Pathname.new(@prefix)
    new_prefix = Pathname.new(@new_prefix)
    @loaded_features.each{|file_path|
      file_path = Pathname.new(file_path).expand_path.cleanpath
      if file_path.to_s.index(@prefix) == 0
        new_path = new_prefix.join(file_path.relative_path_from(prefix))
        new_path.dirname.mkpath
        FileUtils.cp(file_path.to_s, new_path.to_s)
      end
    }
  end

  def make_bat
    bat = File.basename(@script, ".rb") + ".bat"
    new_ruby = File.join('.', NEW_RUBY_DIR, File.basename(@ruby))
    new_ruby.gsub!(File::SEPARATOR, File::ALT_SEPARATOR) unless File::ALT_SEPARATOR.nil?

    rel_script = Pathname.new(@script).
      expand_path.relative_path_from(Pathname.new(@pwd)).to_s
    rel_script.gsub!(File::SEPARATOR, File::ALT_SEPARATOR) unless File::ALT_SEPARATOR.nil?
    # should change '/' to '\'?
    open(bat, "w") {|file|
      file.puts "#{new_ruby} #{rel_script}"
    }
  end
end

$rbat_object = RBat.new
}

END {
$rbat_object.make
}