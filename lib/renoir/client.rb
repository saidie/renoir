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
    end

    def call(*command, &block)
      keys = @adapter_class.get_keys_from_command(command)
      slots = keys.map { |key| key_slot(key) }.uniq
      fail "No way to dispatch this command to Redis Cluster." if slots.size != 1
      slot = slots.first

      refresh_slots if @refresh_slots

      call_with_redirection(slot, command, &block)
    end

    def each_node
      return enum_for(:each_node) unless block_given?

      @cluster_info.node_names.each do |name|
        fetch_connection(name).with_raw_connection do |conn|
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

    def call_with_redirection(slot, command, &block)
      names = @cluster_info.node_names.dup
      name = @cluster_info.slot_node(slot) || names.sample

      redirect_count = 0
      connect_error_count = 0
      connect_retry_count = 0
      asking = false
      loop do
        names.delete(name)

        conn = fetch_connection(name)
        reply = conn.call(command, asking, &block)
        case reply
        when ConnectionAdapters::Reply::RedirectionError
          asking = reply.ask
          name = @cluster_info.add_node(reply.ip, reply.port)
          @refresh_slots ||= !asking

          redirect_count += 1
          raise RedirectionError, "Too many redirections" if @options[:max_redirection] < redirect_count
        when ConnectionAdapters::Reply::ConnectionError
          connect_error_count += 1
          raise reply.cause if @options[:max_connection_error] < connect_error_count
          if names.empty?
            connect_retry_count += 1
            sleep(sleep_interval(connect_retry_count))
          else
            asking = false
            name = names.sample
          end
        else
          return reply
        end
      end
    end

    def refresh_slots
      slots = nil
      @cluster_info.node_names.each do |name|
        conn = fetch_connection(name)
        reply = conn.call(["cluster", "slots"])
        case reply
        when ConnectionAdapters::Reply::RedirectionError
          fail "never reach here"
        when ConnectionAdapters::Reply::ConnectionError
          if @logger
            @logger.warn("CLUSTER SLOTS command failed: node_name=#{name}, message=#{reply.cause}")
          end
        else
          slots = reply
          break
        end
      end
      return unless slots

      @refresh_slots = false
      @cluster_info = ClusterInfo.new.tap do |cluster_info|
        cluster_info.load_slots(slots)
      end

      (@connections.keys - @cluster_info.node_names).each do |key|
        @connections.delete(key)
      end
    end

    def fetch_connection(name)
      @connections[name] ||=
        begin
          node = @cluster_info.node_info(name)
          @adapter_class.new(node[:host], node[:port], @options)
        end
    end

    def sleep_interval(retry_count)
      factor = 1 + 2 * (rand - 0.5) * @options[:connect_retry_random_factor]
      factor * @options[:connect_retry_interval] * 2**(retry_count - 1)
    end
  end
end