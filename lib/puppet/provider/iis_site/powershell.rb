require 'puppet/provider/iispowershell'
require 'json'

Puppet::Type.type(:iis_site).provide(:powershell, :parent => Puppet::Provider::Iispowershell) do

  def self.iisnames
    {
      :name        => 'name',
      :path        => 'physicalPath',
      :app_pool    => 'applicationPool',
    }
  end

  def self.instances
    inst_cmd = 'Import-Module WebAdministration; Get-Website | Select Name, PhysicalPath, ApplicationPool, HostHeader, State, Bindings | ConvertTo-JSON'
    site_json = JSON.parse(run(inst_cmd))
    # The command returns a Hash if there is 1 site
    if site_json.is_a?(Hash)
      [site_json].collect do |site|
        site_hash               = {}
        site_hash[:name]        = site['name']
        site_hash[:path]        = site['physicalPath']
        site_hash[:app_pool]    = site['applicationPool']
        site_hash[:state]       = site['state']
        bindings                = site['bindings']['Collection'].first['bindingInformation']
        site_hash[:protocol]    = site['bindings']['Collection'].first['protocol']
        site_hash[:ip]          = bindings.split(':')[0]
        site_hash[:port]        = bindings.split(':')[1]
        site_hash[:host_header] = bindings.split(':')[2]
        if site['bindings']['Collection'].first['sslFlags'] == 0
          site_hash[:ssl]       = :true
        else
          site_hash[:ssl]       = :false
        end
        site_hash[:ensure]      = :present
        new(site_hash)
      end
    # The command returns an Array if there is >1 site. WHY IS THIS DIFFERENT WINDOWS?
    elsif site_json.is_a?(Array)
      site_json.each.collect do |site|
        site_hash               = {}
        site_hash[:name]        = site['name']
        site_hash[:path]        = site['physicalPath']
        site_hash[:app_pool]    = site['applicationPool']
        site_hash[:state]       = site['state']
        # Also the format of the bindings is different here. WHY WINDOWS?
        bindings                = site['bindings']['Collection'].split(':')
        site_hash[:protocol]    = bindings[0].split[0]
        site_hash[:ip]          = bindings[0].split[1]
        site_hash[:port]        = bindings[1]
        site_hash[:host_header] = bindings[2].gsub(/\s?sslFlags=\d+/, '') if bindings[2]
        if bindings.last.split('=')[1] == '0'
          site_hash[:ssl]       = :true
        else
          site_hash[:ssl]       = :false
        end
        site_hash[:ensure]      = :present
        new(site_hash)
      end
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

  def create
    createSwitches = [
      "-Name \"#{@resource[:name]}\"",
      "-Port #{@resource[:port]} -IP #{@resource[:ip]}",
      "-HostHeader \"#{@resource[:host_header]}\"",
      "-PhysicalPath \"#{@resource[:path]}\"",
      "-ApplicationPool \"#{@resource[:app_pool]}\"",
      "-Ssl:$#{@resource[:ssl]}",
      '-Force'
    ] 
    inst_cmd = "Import-Module WebAdministration; New-Website #{createSwitches.join(' ')}"
    resp = Puppet::Type::Iis_site::ProviderPowershell.run(inst_cmd)
    fail(resp) if resp.length > 0

    @resource.original_parameters.each_key do |k|
      @property_hash[k] = @resource[k]
    end

    exists? ? (return true) : (return false)
  end

  def destroy
    inst_cmd = "Import-Module WebAdministration; Remove-Website -Name \"#{@property_hash[:name]}\"" 
    resp = Puppet::Type::Iis_site::ProviderPowershell.run(inst_cmd)
    fail(resp) if resp.length > 0
    @property_hash.clear
    exists? ? (return false) : (return true)
  end

  iisnames.each do |property,iisname|
    next if property == :ensure
    define_method "#{property.to_s}=" do |value|
      inst_cmd = "Import-Module WebAdministration; Set-ItemProperty -Path \"IIS:\\\\Sites\\#{@property_hash[:name]}\" -Name \"#{iisname}\" -Value \"#{value}\""
      resp = Puppet::Type::Iis_site::ProviderPowershell.run(inst_cmd)
      fail(resp) if resp.length > 0
    end
  end

  # These three properties have to be submitted together
  binders = [
    'protocol',
    'ip',
    'port',
    'host_header',
    'ssl'
  ]

  binders.each do |property|
    define_method "#{property}=" do |value|
      bhash = {}
      binders.each do |b|
        if b == property
          bhash[b] = value unless value == 'false'
        else
          bhash[b] = @property_hash[b.to_sym]
        end
      end
      inst_cmd = "Import-Module WebAdministration; Set-ItemProperty -Path \"IIS:\\\\Sites\\#{@property_hash[:name]}\" -Name Bindings -Value @{protocol=\"#{bhash['protocol']}\";bindingInformation=\"#{bhash['ip']}:#{bhash['port']}:#{bhash['host_header']}"
      inst_cmd += '"'
      # Append sslFlags to args is enabled
      inst_cmd += '; sslFlags=0' if bhash['ssl'] and bhash['ssl'] != :false
      inst_cmd += '}'
      resp = Puppet::Type::Iis_site::ProviderPowershell.run(inst_cmd)
      fail(resp) if resp.length > 0
      @property_hash[property.to_sym] = value
    end
  end

  def state=(value)
    if value == "Started"
      inst_cmd = 'Start-Website'
    else
      inst_cmd = 'Stop-Website'
    end
    inst_cmd += " -Name \"#{@property_hash[:name]}\""
    resp = Puppet::Type::Iis_site::ProviderPowershell.run(inst_cmd)
    fail(resp) if resp.length > 0
    @property_hash[:state] = value
  end

end
