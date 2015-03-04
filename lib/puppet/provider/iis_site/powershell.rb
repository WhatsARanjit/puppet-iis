require 'puppet/provider/exec/powershell'
require 'json'
require 'pry'

Puppet::Type.type(:iis_site).provide(:powershell) do

  commands :powershell =>
    if File.exists?("#{ENV['SYSTEMROOT']}\\sysnative\\WindowsPowershell\\v1.0\\powershell.exe")
      "#{ENV['SYSTEMROOT']}\\sysnative\\WindowsPowershell\\v1.0\\powershell.exe"
    elsif File.exists?("#{ENV['SYSTEMROOT']}\\system32\\WindowsPowershell\\v1.0\\powershell.exe")
      "#{ENV['SYSTEMROOT']}\\system32\\WindowsPowershell\\v1.0\\powershell.exe"
    else
      'powershell.exe'
    end

  def self.run(command, check = false)
    write_script(command) do |native_path|
      psh = "cmd.exe /c \"\"#{native_path(command(:powershell))}\" #{args} -Command - < \"#{native_path}\"\""
      return %x(#{psh})
    end
  end

  def self.instances
    inst_cmd = 'Import-Module WebAdministration; Get-Website | Select Name, PhysicalPath, Bindings | ConvertTo-JSON'
    site_json = JSON.parse(run(inst_cmd))
    site_json.collect do |site|
      site_hash          = {}
      site_hash[:name]   = site_json['name']
      site_hash[:path]   = site_json['physicalPath']
      bindings           = site_json['bindings']['Collection'].first['bindingInformation']
      site_hash[:ip]     = bindings.split(':')[0]
      site_hash[:port]   = bindings.split(':')[1]
      site_hash[:ssl]    = site_json['bindings']['Collection'].first['sslFlags']
      site_hash[:ensure] = :present
      new(site_hash)
    end
  end

  def self.prefetch(resources)
    sites = instances
    resources.keys.each do |site|
      if provider = sites.find{ |s| s.name == site }
        resources[site].provider = provider
      end
    end
  end

  def exists?
    @property_hash[:ensure] == :present
  end

  mk_resource_methods

  private
  def self.write_script(content, &block)
    Tempfile.open(['puppet-powershell', '.ps1']) do |file|
      file.write(content)
      file.flush
      yield native_path(file.path)
    end
  end

  def self.native_path(path)
    path.gsub(File::SEPARATOR, File::ALT_SEPARATOR)
  end

  def self.args
    '-NoProfile -NonInteractive -NoLogo -ExecutionPolicy Bypass'
  end

end
