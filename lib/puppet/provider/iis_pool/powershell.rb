require 'puppet/provider/iispowershell'
require 'json'
require 'pry'

Puppet::Type.type(:iis_pool).provide(:powershell, :parent => Puppet::Provider::Iispowershell) do

  def self.poolattrs
    {
      :enable_32_bit => 'enable32BitAppOnWin64',
      :runtime       => 'managedRuntimeVersion',
      :pipeline      => 'managedPipelineMode'
    }
  end

  def self.pipelines
    {
      0 => 'Integrated',
      1 => 'Classic'
    }
  end

  def self.instances
    inst_cmd ='Import-Module WebAdministration; ls IIS:\\AppPools | Select Name | ConvertTo-JSON'
    pool_names = JSON.parse(run(inst_cmd))
    pool_names.collect do |pool|
      pool_cmd                  = "Import-Module WebAdministration; Get-ItemProperty \"IIS:\\\\AppPools\\#{pool['name']}\""
      pool_hash                 = {}
      pool_hash[:name]          = pool['name']
      pool_hash[:enable_32_bit] = run("#{pool_cmd} enable32BitAppOnWin64.value").rstrip.downcase.to_sym
      pool_hash[:runtime]       = run("#{pool_cmd} managedRuntimeVersion.value").rstrip.gsub(/^v/, '')
      pool_hash[:pipeline]      = pipelines[run("#{pool_cmd} managedPipelineMode.value").rstrip.to_i]
      pool_hash[:ensure]        = :present
      new(pool_hash)
    end
  end

  def self.prefetch(resources)
    pools = instances
    resources.keys.each do |pool|
      if provider = pools.find{ |p| p.name == pool }
        resources[pool].provider = provider
      end
    end
  end

  def exists?
    @property_hash[:ensure] == :present
  end

  mk_resource_methods

  def create
    inst_cmd = "Import-Module WebAdministration; New-WebAppPool -Name \"#{@resource[:name]}\""
    Puppet::Type::Iis_pool::ProviderPowershell.poolattrs.each do |property,value|
      inst_cmd += "; Set-ItemProperty \"IIS:\\\\AppPools\\#{@resource[:name]}\" #{value} #{@resource[property]}" if @resource[property]
    end
    resp = Puppet::Type::Iis_pool::ProviderPowershell.run(inst_cmd)

    @resource.original_parameters.each_key do |k|
      @property_hash[k] = @resource[k]
    end

    exists? ? (return true) : (return false)
  end

  def destroy
    inst_cmd = "Import-Module WebAdministration; Remove-WebAppPool -Name \"#{@resource[:name]}\""
    resp = Puppet::Type::Iis_pool::ProviderPowershell.run(inst_cmd)
    fail(resp) if resp.length > 0

    @property_hash.clear
    exists? ? (return false) : (return true)
  end

end
