require 'test_helper'

class HostObserverTest < ActiveSupport::TestCase
  test "should save" do
    host = Host::Base.new
    host.name = "foo"
    assert host.save
  end
end
