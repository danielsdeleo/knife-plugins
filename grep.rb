require 'chef/knife'

module Kallistec
  class Grep < Chef::Knife

    deps do
      require 'chef/search/query'
      require 'chef/knife/search'
    end

    banner "knife grep QUERY"

    def run
      unless @query = name_args.first
        ui.error "You need to specify a query term"
        exit 1
      end


      fuzzy_query = "tags:*#{@query}* OR roles:*#{@query}* OR fqdn:*#{@query}* OR addresses:*#{@query}*"
      knife_search = Chef::Knife::Search.new
      knife_search.name_args = ['node', fuzzy_query]
      knife_search.run

    end
  end
end
