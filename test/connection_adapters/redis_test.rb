require 'test_helper'

class RenoirConnectionAdaptersRedisTest < Minitest::Test
  def setup
    node = CONFIG['cluster_nodes'].sample
    host, port = case node
                 when Array
                   node
                 when String
                   node.split(':')
                 when Hash
                   [node['host'], node['port']]
                 else
                   fail 'invalid cluster_nodes config format'
                 end
    @klass = Renoir::ConnectionAdapters::Redis
    @adapter = @klass.new(host, port)
  end

  def test_get_keys_from_command
    map = {
      [:get, 'key1'] => ['key1'],
      [:del, 'key1', 'key2'] => ['key1', 'key2'],
      [:smove, 'source', 'dest', 123] => ['source', 'dest'],
      [:blpop, 'key1', 'key2', 'key3', timeout: 50] => ['key1', 'key2', 'key3'],
      [:bitop, :and, 'key1', 'key2', 'key3'] => ['key1', 'key2', 'key3'],
      [:eval, 'SCRIPT', ['key1', 'key2'], []] => ['key1', 'key2'],
      [:eval, 'SCRIPT', keys: ['key1', 'key2']] => ['key1', 'key2'],
      [:georadius, 'key1', 0, 90, 1, :km, :store, 'key2'] => ['key1', 'key2'],
      [:migrate, 'key', db: 1] => ['key'],
      [:mset, 'key1', 123, 'key2', 456, 'key3', 789] => ['key1', 'key2', 'key3'],
      [:sort, 'key1', store: 'key2'] => ['key1', 'key2'],
      [:zinterstore, 'key1', ['key2', 'key3']] => ['key1', 'key2', 'key3']
    }

    map.each do |command, keys|
      assert @klass.get_keys_from_command(command) == keys
    end
  end

  def test_call_without_asking
    conn_mock = Minitest::Mock.new
    conn_mock.expect(:info, true)
    @adapter.instance_variable_set(:@conn, conn_mock)

    @adapter.call([:info], false)

    conn_mock.verify
  end

  def test_call_with_asking
    tx_mock = Minitest::Mock.new
    tx_mock.expect(:asking, true)
    tx_mock.expect(:info, true)
    conn_mock = Struct.new(:tx_mock) do
      def multi
        yield tx_mock
      end
    end.new(tx_mock)
    @adapter.instance_variable_set(:@conn, conn_mock)

    @adapter.call([:info], true)

    tx_mock.verify
  end
end
