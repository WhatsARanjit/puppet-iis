require 'puppet/provider/iispowershell'
require 'json'
require 'pry'

Puppet::Type.type(:iis_pool).provide(:powershell, :parent => Puppet::Provider::Iispowershell) do

  def initialize(value={})
    super(value)
    @property_flush = {
      'poolattrs' => {},
    }
  end

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
    inst_cmd = [
      'Import-Module WebAdministration;',
      '$pools=(ls "IIS:\\AppPools");',
      '@(ForEach ($pool in $pools)',
      '{ $p=($pool.name);',
      'Get-ItemProperty "IIS:\\AppPools\$p" |',
      'Select Name,State,enable32BitAppOnWin64,managedRuntimeVersion,managedPipelineMode }) |',
      'ConvertTo-JSON'
    ]
    pool_names = JSON.parse(run(inst_cmd.join))
    pool_names.collect do |pool|
      pool_hash                 = {}
      pool_hash[:name]          = pool['name']
      pool_hash[:state]         = pool['state']
      pool_hash[:enable_32_bit] = "#{pool['enable32BitAppOnWin64']}".to_sym || :false
      pool_hash[:runtime]       = pool['managedRuntimeVersion']
      pool_hash[:pipeline]      = pool['managedPipelineMode']
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

  Puppet::Type::Iis_pool::ProviderPowershell.poolattrs.each do |property,poolattr|
    define_method "#{property}=" do |value|
      @property_flush['poolattrs'][poolattr] = value
      @property_hash[property] = value
    end
  end

  def restart
    inst_cmd = "Import-Module WebAdministration; Restart-WebAppPool -Name \"#{@resource[:name]}\""
    resp = Puppet::Type::Iis_pool::ProviderPowershell.run(inst_cmd)
    fail(resp) if resp.length > 0
  end
  
  def enabled?
    inst_cmd = "Import-Module WebAdministration; (Get-WebAppPoolState -Name \"#{@resource[:name]}\").value"
    resp = Puppet::Type::Iis_pool::ProviderPowershell.run(inst_cmd).rstrip
    if resp == 'Started'
      return true
    else
      return false
    end
  end

  def state=(value)
    @property_flush['state'] = value
    @property_hash[:state] = value
  end

  def flush
    command_array = []
    command_array << "Import-Module WebAdministration; "
    @property_flush['poolattrs'].each do |poolattr,value|
      command_array << "Set-ItemProperty \"IIS:\\\\AppPools\\#{@property_hash[:name]}\" #{poolattr} #{value}"
    end
    if @property_flush['state']
      if @property_flush['state'] == :Started
        state_cmd = 'Start-WebAppPool'
      else
        state_cmd = 'Stop-WebAppPool'
      end
      state_cmd += " -Name \"#{@property_hash[:name]}\""
      command_array << state_cmd
    end
    resp = Puppet::Type::Iis_pool::ProviderPowershell.run(command_array.join('; '))
    fail(resp) if resp.length > 0
  end

end
