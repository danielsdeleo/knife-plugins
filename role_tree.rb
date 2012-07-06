require 'chef/knife'

module Kallistec
  class RoleTree < Chef::Knife

    deps do
      require 'chef/node'
      require 'chef/run_list'
      require 'chef/run_list/run_list_expansion'
    end

    banner "knife role tree NODE"

    attr_reader :node_name
    attr_reader :node

    def run
      unless Chef::RunList::RunListExpansion.instance_methods.map(&:to_s).include?("run_list_trace")
        ui.error "knife role tree requires Chef 10.14.0 beta or newer"
        exit 1
      end
      unless @node_name = name_args.first
        ui.error "You must specify a the name of the node you want to print the run list tree for"
        exit 1
      end

      @node = Chef::Node.load(node_name)

      tree_print("top level", expansion.run_list_trace)

    end

    def run_list
      @node.run_list
    end

    def expansion
      @expansion ||= run_list.expand("server")
    end

    def puts_indented(item, indentation)
      prefix = ""
      unless indentation == 0
        prefix = "| " * (indentation - 1)
        prefix << "|-"
      end
      puts "#{prefix}#{item}"
    end

    def tree_print(item, trace, depth=0)
      puts_indented(item, depth)
      trace[item.to_s].each { |sub_item| tree_print(sub_item, trace, depth + 1)}
    end

  end
end





