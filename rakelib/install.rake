# Tasks for installing Rubinius. There are two guidelines here:
#
#  1. Only use sudo if necessary
#  2. Build all Ruby files using the bootstrap Ruby implementation
#     and install the files with the 'install' command
#

desc "Install Rubinius"
task :install => %w[build:build install:files install:done]

# Determine if all the targets for the install directories are writable
# decomposing each candidate directory from the right side and checking if
# that path is writable. If not, we require explicit permission.
def need_permission?
  FileList["#{BUILD_CONFIG[:builddir]}/*"].each do |name|
    destdir = ENV['DESTDIR'] || ''
    dir = File.expand_path(File.join(destdir, BUILD_CONFIG[:prefixdir], name))

    until dir == "/"
      if File.directory? dir
        return true unless File.writable? dir
        break
      end

      dir = File.dirname dir
    end
  end

  return false
end


def install_file(source, prefix, dest, name=nil, options={})
  return if File.directory? source

  options, name = name, nil if name.kind_of? Hash
  name = source[prefix.size..-1] unless name

  dest_name = File.join(dest, name)
  dir = File.dirname dest_name
  mkdir_p dir, :verbose => $verbose unless File.directory? dir

  options[:mode] ||= 0644
  options[:verbose] ||= $verbose

  install source, dest_name, **options
end

def install_bin(source, target)
  bin = "#{target}#{BUILD_CONFIG[:bindir]}/#{BUILD_CONFIG[:program_name]}"
  dir = File.dirname bin
  mkdir_p dir, :verbose => $verbose unless File.directory? dir

  install source, bin, :mode => 0755, :verbose => $verbose

  # Create symlinks for common commands
  if BUILD_CONFIG[:use_bin_links]
    begin
      BUILD_CONFIG[:bin_links].each do |name|
        link = "#{target}/#{BUILD_CONFIG[:bindir]}/#{name}"
        File.delete link if File.exist? link
        File.symlink BUILD_CONFIG[:program_name], link
      end
    rescue NotImplementedError
      # ignore
    end
  end
end

def install_extra_bins(prefix, target)
  install_file "#{prefix}/testrb", prefix, "#{target}#{BUILD_CONFIG[:bindir]}", :mode => 0755
end

def install_codedb(prefix, target)
  FileList[
    "#{prefix}/*",
    "#{prefix}/*.*",
    "#{prefix}/**/*",
    "#{prefix}/**/*.*",
  ].each do |name|
    install_file name, prefix, "#{target}#{BUILD_CONFIG[:codedbdir]}"
  end
end

def install_site(prefix, target)
  FileList[
    "#{prefix}/*",
    "#{prefix}/*.*",
    "#{prefix}/**/*",
    "#{prefix}/**/*.*",
  ].each do |name|
    install_file name, prefix, "#{target}#{BUILD_CONFIG[:sitedir]}"
  end
end

def install_capi_include(prefix, destination)
  FileList["#{prefix}/**/*.h", "#{prefix}/**/*.hpp"].each do |name|
    install_file name, prefix, destination
  end
end

def install_build_lib(prefix, target)
  list = FileList["#{prefix}/**/*.*", "#{prefix}/**/*"]

  list.each do |name|
    install_file name, prefix, "#{target}#{BUILD_CONFIG[:libdir]}"
  end
end

def install_lib(prefix, target)
  list = FileList["#{prefix}/**/*.rb", "#{prefix}/**/rubygems/**/*"]

  list.each do |source|
    install_file source, prefix, "#{target}#{BUILD_CONFIG[:libdir]}"
  end
end

def install_transcoders(prefix, target)
  FileList["#{prefix}/*#{$dlext}"].each do |source|
    install_file source, prefix, "#{target}#{BUILD_CONFIG[:encdir]}", :mode => 0755
  end
end

def install_tooling(prefix, target)
  FileList["#{prefix}/tooling/**/*.#{$dlext}"].each do |name|
    install_file name, prefix, "#{target}#{BUILD_CONFIG[:libdir]}"
  end
end

def install_documentation(prefix, target)
  FileList["#{prefix}/rubinius/documentation/**/*"].each do |name|
    install_file name, prefix, "#{target}#{BUILD_CONFIG[:libdir]}"
  end
end

def install_manpages(prefix, target)
  FileList["#{prefix}/**/*"].each do |name|
    install_file name, prefix, "#{target}#{BUILD_CONFIG[:mandir]}"
  end
end

def install_gems(prefix, target)
  list = FileList["#{prefix}/**/*.*", "#{prefix}/**/*"]
  list.exclude("#{prefix}/bin/*")

  list.each do |name|
    install_file name, prefix, "#{target}#{BUILD_CONFIG[:gemsdir]}"
  end
end

def install_gems_bins(prefix, target)
  FileList["#{prefix}/*"].each do |name|
    install_file name, prefix, "#{target}#{BUILD_CONFIG[:gemsdir]}/bin", :mode => 0755
  end
end

namespace :stage do
  task :bin do
    install_bin "#{BUILD_CONFIG[:sourcedir]}/machine/vm", BUILD_CONFIG[:sourcedir]

    if BUILD_CONFIG[:builddir]
      install_bin "#{BUILD_CONFIG[:sourcedir]}/machine/vm", BUILD_CONFIG[:builddir]

      name = BUILD_CONFIG[:program_name]
      mode = File::CREAT | File::TRUNC | File::WRONLY
      File.open("#{BUILD_CONFIG[:sourcedir]}/bin/#{name}", mode, 0755) do |f|
        f.puts <<-EOS
#!/bin/sh
#
# Rubinius has been configured to be installed. This convenience
# wrapper enables running Rubinius from the staging directories.

export RBX_PREFIX_PATH=#{BUILD_CONFIG[:builddir]}
EXE=$(basename $0)

exec #{BUILD_CONFIG[:builddir]}#{BUILD_CONFIG[:bindir]}/$EXE "$@"
        EOS
      end
    end
  end

  task :extra_bins do
    if BUILD_CONFIG[:builddir]
      install_extra_bins "#{BUILD_CONFIG[:sourcedir]}/bin", BUILD_CONFIG[:builddir]
    end
  end

  task :capi_include do
    if BUILD_CONFIG[:builddir]
      install_capi_include "#{BUILD_CONFIG[:capi_includedir]}",
                           "#{BUILD_CONFIG[:builddir]}#{BUILD_CONFIG[:"includedir"]}"
    end
  end

  task :lib do
    if BUILD_CONFIG[:builddir]
      install_build_lib "#{BUILD_CONFIG[:sourcedir]}/library", BUILD_CONFIG[:builddir]
    end
  end

  task :site do
    if BUILD_CONFIG[:builddir]
      install_site "#{BUILD_CONFIG[:sourcedir]}/site", BUILD_CONFIG[:builddir]
    end
  end

  task :documentation do
    if BUILD_CONFIG[:builddir]
      install_documentation "#{BUILD_CONFIG[:sourcedir]}/library", BUILD_CONFIG[:builddir]
    end
  end

  task :manpages do
    if BUILD_CONFIG[:builddir]
      install_manpages "#{BUILD_CONFIG[:sourcedir]}/doc/generated/machine/man", BUILD_CONFIG[:builddir]
    end
  end
end

namespace :install do
  desc "Install all the Rubinius files. Use DESTDIR environment variable " \
       "to specify custom installation location."
  task :files do
    if BUILD_CONFIG[:builddir]
      if need_permission?
        prefix = BUILD_CONFIG[:prefixdir]
        STDERR.puts <<-EOM
Rubinius has been configured for the following paths:

bin:     #{prefix}#{BUILD_CONFIG[:bindir]}
lib:     #{prefix}#{BUILD_CONFIG[:libdir]}
core:    #{prefix}#{BUILD_CONFIG[:coredir]}
site:    #{prefix}#{BUILD_CONFIG[:sitedir]}
vendor:  #{prefix}#{BUILD_CONFIG[:vendordir]}
man:     #{prefix}#{BUILD_CONFIG[:mandir]}
gems:    #{prefix}#{BUILD_CONFIG[:gemsdir]}
include: #{prefix}#{BUILD_CONFIG[:includedir]}

Please ensure that the paths to these directories are writable
by the current user. Otherwise, run 'rake install' with the
appropriate command to elevate permissions (eg su, sudo).
        EOM

        exit(1)
      else
        builddir = BUILD_CONFIG[:builddir]
        destdir = ENV['DESTDIR'] || ''
        prefixdir = File.join(destdir, BUILD_CONFIG[:prefixdir])

        install_capi_include "#{builddir}#{BUILD_CONFIG[:includedir]}",
                             "#{prefixdir}#{BUILD_CONFIG[:includedir]}"

        install_codedb "#{builddir}#{BUILD_CONFIG[:codedbdir]}", prefixdir

        install_site "#{builddir}#{BUILD_CONFIG[:sitedir]}", prefixdir

        install_lib "#{builddir}#{BUILD_CONFIG[:libdir]}", prefixdir

        install_transcoders "#{builddir}#{BUILD_CONFIG[:encdir]}", prefixdir

        install_tooling "#{builddir}#{BUILD_CONFIG[:libdir]}", prefixdir

        install_documentation "#{builddir}#{BUILD_CONFIG[:libdir]}", prefixdir

        install_manpages "#{builddir}#{BUILD_CONFIG[:mandir]}", prefixdir

        bin = "#{BUILD_CONFIG[:bindir]}/#{BUILD_CONFIG[:program_name]}"
        install_bin "#{builddir}#{bin}", prefixdir

        install_extra_bins "#{builddir}/#{BUILD_CONFIG[:bindir]}", prefixdir

        install_gems "#{builddir}#{BUILD_CONFIG[:gemsdir]}", prefixdir
        install_gems_bins "#{builddir}#{BUILD_CONFIG[:gemsdir]}/bin", prefixdir

        # Install the testrb command
        unless BUILD_CONFIG[:sourcedir] == BUILD_CONFIG[:prefixdir]
          testrb = "#{prefixdir}#{BUILD_CONFIG[:bindir]}/testrb"
          install "bin/testrb", testrb, :mode => 0755, :verbose => $verbose
        end
      end
    end
  end

  task :done do
    STDOUT.puts <<-EOM
--------

Successfully installed Rubinius #{release_revision.first}

Add '#{BUILD_CONFIG[:prefixdir]}#{BUILD_CONFIG[:bindir]}' to your PATH. Available commands are:

  #{BUILD_CONFIG[:program_name]}, ruby, rake, gem, irb, rdoc, ri

  1. Run Ruby files with '#{BUILD_CONFIG[:program_name]} path/to/file.rb'
  2. Start IRB by running '#{BUILD_CONFIG[:program_name]}' with no arguments

    EOM
  end
end

