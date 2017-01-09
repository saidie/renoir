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
    @conn = @adapter.instance_variable_get(:@conn)
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
    def @conn.asking
      call(:asking)
      @asked = true
    end
    assert @adapter.call([[:info]], false).size == 1
    refute @conn.instance_variable_get(:@asked)
  end

  def test_call_with_asking
    def @conn.asking
      call(:asking)
      @asked = true
    end
    assert @adapter.call([[:info]], true).size == 1
    assert @conn.instance_variable_get(:@asked)
  end

  def test_call_with_multi
    assert_raises RuntimeError do
      @adapter.call([[:multi], [:info]], false)
    end

    assert @adapter.call([[:multi], [:info], [:exec]], false).size == 1
  end

  def test_call_with_multiple_commands
    assert @adapter.call([[:info], [:info]], false).size == 2
  end
end
