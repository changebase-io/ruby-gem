require 'test_helper'

class ActionControllerTest < ActionDispatch::IntegrationTest

  get "/block" => "block#world"
  class BlockController < ActionController::Base
    changebase :request_id do
      request.uuid
    end
    
    def world
      render plain: "Hello world!"
    end
  end

  test "changebase key with a block" do
    uuid = SecureRandom.uuid
    ActionDispatch::Request.any_instance.stubs(:uuid).returns(uuid)
    ActiveRecord::Base.expects(:with_metadata).once.with({request_id: uuid})

    get "/block"
    assert_response :success
  end

  get "/proc" => "block#world"
  class ProcController < ActionController::Base
    changebase :request_id, -> () { request.uuid }
  
    def world
      render plain: "Hello world!"
    end
  end

  test "changebase key with a proc" do
    uuid = SecureRandom.uuid
    ActionDispatch::Request.any_instance.stubs(:uuid).returns(uuid)
    ActiveRecord::Base.expects(:with_metadata).once.with({request_id: uuid})

    get "/proc"
    assert_response :success
  end

  get "/symbol" => "symbol#world"
  class SymbolController < ActionController::Base
    changebase :request_id, :request_id
  
    def request_id
      request.uuid
    end
    
    def world
      render plain: "Hello world!"
    end
  end

  test "changebase key with a symbol" do
    uuid = SecureRandom.uuid
    ActionDispatch::Request.any_instance.stubs(:uuid).returns(uuid)
    ActiveRecord::Base.expects(:with_metadata).once.with({request_id: uuid})

    get "/symbol"
    assert_response :success
  end

  get "/string" => "string#world"
  class StringController < ActionController::Base
    changebase :version, 'v1.0.rc2'
    
    def world
      render plain: "Hello world!"
    end
  end

  test "changebase key with a string" do
    ActiveRecord::Base.expects(:with_metadata).once.with({version: 'v1.0.rc2'})

    get "/string"
    assert_response :success
  end
  
  get "/nested" => "nested#world"
  class NestedController < ActionController::Base
    changebase :build, :version, 'v1.0.rc2'
    
    def world
      render plain: "Hello world!"
    end
  end

  test 'nested keys' do
    ActiveRecord::Base.expects(:with_metadata).once.with({build: {version: 'v1.0.rc2'}})

    get "/nested"
    assert_response :success
  end
  
  get "/multiple" => "multiple#world"
  class MultipleController < ActionController::Base
    changebase :request_id, -> () { request.uuid }
    changebase :build, :version, 'v1.0.rc2'
    changebase :build, :id, 'ID'
    
    def world
      render plain: "Hello world!"
    end
  end

  test 'multiple keys' do
    uuid = SecureRandom.uuid
    ActionDispatch::Request.any_instance.stubs(:uuid).returns(uuid)
    ActiveRecord::Base.expects(:with_metadata).once.with({
      request_id: uuid,
      build: {id: 'ID', version: 'v1.0.rc2'}
    })

    get "/multiple"
    assert_response :success
  end
  
  get "/inherited" => "inherited#world"
  class InheritedController < MultipleController
    changebase :request_id, -> () { 'NEWID' }
    changebase :build, :version, 'NEWVERSION'
    
    def world
      render plain: "Hello world!"
    end
  end

  test 'inherited' do
    ActiveRecord::Base.expects(:with_metadata).once.with({
      request_id: 'NEWID',
      build: {id: 'ID', version: 'NEWVERSION'}
    })

    get "/inherited"
    assert_response :success
  end

end