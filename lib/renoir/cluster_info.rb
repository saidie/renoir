module Renoir
  # Store cluster information.
  class ClusterInfo
    class << self
      def node_name(host, port)
        "#{host}:#{port}"
      end
    end

    def initialize
      @slots = {}
      @nodes = {}
    end

    def load_slots(slots)
      slots.each do |s, e, master, *slaves|
        ip, port, = master
        name = add_node(ip, port)
        (s..e).each do |slot|
          @slots[slot] = name
        end
      end
    end

    def slot_node(slot)
      @nodes[@slots[slot]]
    end

    def node_names
      @nodes.keys
    end

    def nodes
      @nodes.values
    end

    def add_node(host, port)
      name = self.class.node_name(host, port)
      @nodes[name] = {
        host: host,
        port: port,
        name: name,
      }
    end
  end
end
