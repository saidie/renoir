require 'test_helper'

class RenoirClientRedisTest < Minitest::Test
  def setup
    @client = Renoir::Client.new(
      CONFIG.merge(connection_adapter: :redis)
    )
  end

  def test_call_single_key_command
    assert @client.set('hoge', 123) == 'OK'
    assert @client.set('fuga', 'piyo') == 'OK'
    assert @client.set('hogera', 'hogehoge') == 'OK'
    assert @client.get('hoge') == '123'
    assert @client.get('fuga') == 'piyo'
    assert @client.get('hogera') == 'hogehoge'
  end

  def test_call_multi_key_command
    assert_raises RuntimeError do
      @client.mget('hoge', 'fuga', 'hogera')
    end

    assert @client.mget('hoge{1}', 'fuga{1}', 'hogera{1}').size == 3
  end

  def test_call_unsupported_command
    assert_raises RuntimeError do
      @client.info
    end
  end

  def test_close
    # ensure that connection is established
    connections = []
    @client.send(:refresh_slots)
    @client.each_node do |conn|
      conn.ping
      connections << conn
    end

    @client.close

    refute connections.any?(&:connected?)
  end

  def test_each_node
    @client.send(:refresh_slots)
    assert @client.each_node.all? { |conn| conn.is_a?(::Redis) }
  end

  def test_too_many_redirections
    @client.send(:refresh_slots)
    @client.each_node do |conn|
      def conn.set(*args)
        if Thread.current[:error_count] < Thread.current[:limit]
          Thread.current[:error_count] += 1
          raise ::Redis::CommandError, "MOVED 123 #{client.host}:#{client.port}"
        else
          super(*args)
        end
      end
    end

    Thread.current[:error_count] = 0
    Thread.current[:limit] = Renoir::Client::DEFAULT_OPTIONS[:max_redirection] + 1
    assert_raises Renoir::RedirectionError do
      @client.set('hoge', 123)
    end

    Thread.current[:error_count] = 0
    Thread.current[:limit] = Renoir::Client::DEFAULT_OPTIONS[:max_redirection]
    assert @client.set('hoge', 123) == 'OK'
  end

  def test_too_many_connection_errors
    @client.send(:refresh_slots)
    @client.each_node do |conn|
      def conn.set(*args)
        if Thread.current[:error_count] < Thread.current[:limit]
          Thread.current[:error_count] += 1
          raise ::Redis::CannotConnectError
        else
          super(*args)
        end
      end
    end

    Thread.current[:error_count] = 0
    Thread.current[:limit] = Renoir::Client::DEFAULT_OPTIONS[:max_connection_error] + 1
    assert_raises ::Redis::CannotConnectError do
      @client.set('hoge', 123)
    end

    Thread.current[:error_count] = 0
    Thread.current[:limit] = Renoir::Client::DEFAULT_OPTIONS[:max_connection_error]
    assert @client.set('hoge', 123) == 'OK'
  end
end
