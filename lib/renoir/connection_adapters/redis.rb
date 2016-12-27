require "redis"
require "renoir/connection_adapters/base"

module Renoir
  module ConnectionAdapters
    class Redis < Base
      class << self
        def get_keys_from_command(command)
          case command[0].to_s.downcase.to_sym
          when :append, :bitcount, :bitfield, :bitpos, :decr, :decrby, :dump,
              :expire, :expireat, :geoadd, :geodist, :geohash, :geopos, :get,
              :getbit, :getrange, :getset, :hdel, :hexists, :hget, :hgetall,
              :hincrby, :hincrbyfloat, :hkeys, :hlen, :hmget, :hmset, :hscan,
              :hset, :hsetnx, :hstrlen, :hvals, :incr, :incrby, :incrbyfloat,
              :lindex, :linsert, :llen, :lpop, :lpush, :lpushx, :lrange, :lrem,
              :lset, :ltrim, :move, :persist, :pexpire, :pexpireat, :pfadd,
              :psetex, :pttl, :restore, :rpop, :rpush, :rpushx, :sadd, :scard,
              :set, :setbit, :setex, :setnx, :setrange, :sismember, :smembers,
              :spop, :srandmember, :srem, :sscan, :strlen, :ttl, :type, :zadd,
              :zcard, :zcount, :zincrby, :zlexcount, :zrange, :zrangebylex,
              :zrangebyscore, :zrank, :zrem, :zremrangebylex, :zremrangebyrank,
              :zremrangebyscore, :zrevrange, :zrevrangebylex,
              :zrevrangebyscore, :zrevrank, :zscan, :zscore
            [command[1]]
          when :del, :exists, :mget, :pfcount, :pfmerge, :sdiff, :sdiffstore,
              :sinter, :sinterstore, :sunion, :sunionstore, :touch, :unlink,
              :watch, :rename, :renamenx, :rpoplpush
            command[1..-1]
          when :smove
            command[1..-2]
          when :blpop, :brpop, :brpoplpush
            command[-1].is_a?(Hash) ? command[1..-2] : command[1..-1]
          when :bitop
            command[2..-1]
          when :eval, :evalsha
            (command[2].is_a?(Hash) ? command[2][:keys] : command[2]) || []
          when :georadius, :georadiusbymember
            store_index = command.index { |arg| [:store, :storedist].include?(arg.to_s.downcase.to_sym) }
            [command[1]] + (store_index ? command[store_index+1] : [])
          when :migrate
            if command[1].empty?
              # TODO: support multiple keys when the redis-rb gem supports that
            else
              [command[1]]
            end
          when :mset, :msetnx
            ((command.size - 1) / 2).times.map { |count| command[1 + count*2] }
          when :sort
            [command[1]] + (command[2].is_a?(Hash) ? command[2][:store] : [])
          when :zinterstore, :zunionstore
            [command[1]] + command[2]
          else
            [command[1]]
          end
        end
      end

      def initialize(host, port, options={})
        @conn = ::Redis.new(options.merge(host: host, port: port))
      end

      def call(command, asking=false, &block)
        command, *args = command
        if asking
          @conn.multi do |tx|
            tx.asking
            tx.send(command, *args, &block)
          end
        else
          @conn.send(command, *args, &block)
        end
      rescue ::Redis::CommandError => e
        errv = e.to_s.split
        type = errv[0].downcase.to_sym
        raise unless [:moved, :ask].include?(type)

        ip, port = errv[2].split(":")
        Reply::RedirectionError.new(e, type == :ask, ip, port)
      rescue ::Redis::TimeoutError, ::Redis::CannotConnectError => e
        Reply::ConnectionError.new(e)
      end

      def with_raw_connection
        yield @conn
      end
    end
  end
end
