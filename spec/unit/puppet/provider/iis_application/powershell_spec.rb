require 'spec_helper'

provider_class = Puppet::Type.type(:iis_application).provider(:powershell)

describe provider_class do

  let(:resource) {
    Puppet::Type.type(:iis_application).new(
      :name          => 'test_application',
      :ensure        => 'started',
      :path          => 'C:/Temp',
      :site          => 'Default Web Site',
      :app_pool      => 'DefaultAppPool',
      )
  }

  let(:provider) { resource.provider }

  let(:instance) { provider.class.instances.first }

  it 'should be an instance of ProviderPowershell' do
    expect(provider).to be_an_instance_of Puppet::Type::Iis_application::ProviderPowershell
  end

end
