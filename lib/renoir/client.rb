require 'thread'
require "renoir/cluster_info"
require "renoir/connection_adapters"
require "renoir/crc16"

module Renoir
  class Client
    REDIS_CLUSTER_HASH_SLOTS = 16_384

    DEFAULT_OPTIONS = {
      cluster_nodes: [
        ["127.0.0.1", 6379]
      ],
      max_redirection: 10,
      max_connection_error: 5,
      connect_retry_random_factor: 0.1,
      connect_retry_interval: 0.001, # 1 ms
      connection_adapter: :redis,
    }.freeze

    def initialize(options)
      @connections = {}
      @cluster_info = ClusterInfo.new
      @refresh_slots = true

      options = options.map { |k, v| [k.to_sym, v] }.to_h
      @options = DEFAULT_OPTIONS.merge(options)
      @logger = @options[:logger]
      @adapter_class = ConnectionAdapters.const_get(@options[:connection_adapter].to_s.capitalize)

      cluster_nodes = @options.delete(:cluster_nodes)
      fail "the cluster_nodes option must contain at least one node" if cluster_nodes.empty?
      cluster_nodes.each do |node|
        host, port = case node
                     when Array
                       node
                     when Hash
                       [node[:host], node[:port]]
                     when String
                       node.split(":")
                     else
                       fail "invalid entry in cluster_nodes option: #{node}"
                     end
        port ||= 6379
        @cluster_info.add_node(host, port.to_i)
      end

      @connections_mutex = Mutex.new
      @refresh_slots_mutex = Mutex.new
    end

    def eval(*args, &block)
      call(eval, *args, &block)
    end

    def call(*command, &block)
      keys = @adapter_class.get_keys_from_command(command)
      slots = keys.map { |key| key_slot(key) }.uniq
      fail "No way to dispatch this command to Redis Cluster." if slots.size != 1
      slot = slots.first

      refresh = @refresh_slots_mutex.synchronize do
        refresh = @refresh_slots
        @refresh_slots = false
        refresh
      end
      refresh_slots if refresh

      call_with_redirection(slot, [command], &block)[0]
    end

    def close
      while entry = @connections.shift
        entry[1].close
      end
    end

    def each_node
      return enum_for(:each_node) unless block_given?

      @cluster_info.nodes.each do |node|
        fetch_connection(node).with_raw_connection do |conn|
          yield conn
        end
      end
    end

    def method_missing(command, *args, &block)
      call(command, *args, &block)
    end

    private

    def key_slot(key)
      s = key.index("{")
      if s
        e = key.index("}", s + 1)
        if e && e != s + 1
          key = key[s + 1..e - 1]
        end
      end
      CRC16.crc16(key) % REDIS_CLUSTER_HASH_SLOTS
    end

    def call_with_redirection(slot, commands, &block)
      nodes = @cluster_info.nodes.dup
      node = @cluster_info.slot_node(slot) || nodes.sample

      redirect_count = 0
      connect_error_count = 0
      connect_retry_count = 0
      asking = false
      loop do
        nodes.delete(node)

        conn = fetch_connection(node)
        reply = conn.call(commands, asking, &block)
        case reply
        when ConnectionAdapters::Reply::RedirectionError
          asking = reply.ask
          node = @cluster_info.add_node(reply.ip, reply.port)
          @refresh_slots ||= !asking

          redirect_count += 1
          raise RedirectionError, "Too many redirections" if @options[:max_redirection] < redirect_count
        when ConnectionAdapters::Reply::ConnectionError
          connect_error_count += 1
          raise reply.cause if @options[:max_connection_error] < connect_error_count
          if nodes.empty?
            connect_retry_count += 1
            sleep(sleep_interval(connect_retry_count))
          else
            asking = false
            node = nodes.sample
          end
        else
          return reply
        end
      end
    end

    def refresh_slots
      slots = nil
      @cluster_info.nodes.each do |node|
        conn = fetch_connection(node)
        reply = conn.call([["cluster", "slots"]])
        case reply
        when ConnectionAdapters::Reply::RedirectionError
          fail "never reach here"
        when ConnectionAdapters::Reply::ConnectionError
          if @logger
            @logger.warn("CLUSTER SLOTS command failed: node_name=#{node[:name]}, message=#{reply.cause}")
          end
        else
          slots = reply[0]
          break
        end
      end
      return unless slots

      @cluster_info = ClusterInfo.new.tap do |cluster_info|
        cluster_info.load_slots(slots)
      end

      (@connections.keys - @cluster_info.node_names).each do |key|
        conn = @connections.delete(key)
        conn.close if conn
      end
    end

    def fetch_connection(node)
      name = node[:name]
      if conn = @connections[name]
        conn
      else
        @connections_mutex.synchronize do
          @connections[name] ||= @adapter_class.new(node[:host], node[:port], @options)
        end
      end
    end

    def sleep_interval(retry_count)
      factor = 1 + 2 * (rand - 0.5) * @options[:connect_retry_random_factor]
      factor * @options[:connect_retry_interval] * 2**(retry_count - 1)
    end
  end
end
