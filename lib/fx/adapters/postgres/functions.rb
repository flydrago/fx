require "fx/function"

module Fx
  module Adapters
    class Postgres
      # Fetches defined functions from the postgres connection.
      # @api private
      class Functions
        # The SQL query used by F(x) to retrieve the functions considered
        # dumpable into `db/schema.rb`.
        FUNCTIONS_WITH_DEFINITIONS_QUERY = <<-EOS.freeze
          SELECT
              pp.proname AS name,
              pg_get_function_identity_arguments(pp.oid) AS arguments,
              pg_get_functiondef(pp.oid) AS definition
          FROM pg_proc pp
          JOIN pg_namespace pn
              ON pn.oid = pp.pronamespace
          LEFT JOIN pg_depend pd
              ON pd.objid = pp.oid AND pd.deptype = 'e'
          LEFT JOIN pg_aggregate pa
              ON pa.aggfnoid = pp.oid
          WHERE pn.nspname = 'public'
            AND pa.aggfnoid IS NULL
            AND pp.prokind = 'f'
            AND pd.objid IS NULL
          ORDER BY pp.oid;
        EOS

        FUNCTIONS_WITH_DEFINITIONS_QUERY_PG10 = <<-EOS.freeze
          SELECT
              pp.proname AS name,
              pg_get_function_identity_arguments(pp.oid) AS arguments,
              pg_get_functiondef(pp.oid) AS definition
          FROM pg_proc pp
          JOIN pg_namespace pn
              ON pn.oid = pp.pronamespace
          LEFT JOIN pg_depend pd
              ON pd.objid = pp.oid AND pd.deptype = 'e'
          WHERE pn.nspname = 'public'
            AND NOT pp.proisagg
            AND pd.objid IS NULL
          ORDER BY pp.oid;
        EOS

        # Wraps #all as a static facade.
        #
        # @return [Array<Fx::Function>]
        def self.all(*args)
          new(*args).all
        end

        def initialize(connection)
          @connection = connection
        end

        # All of the functions that this connection has defined. Functions with
        # multiple definitions are grouped into a single object.
        #
        # @return [Array<Fx::Function>]
        def all
          functions_from_postgres.map { |function| to_fx_function(function) }
        end

        private

        attr_reader :connection

        def functions_from_postgres
          if postgresql_10?
            connection.execute(FUNCTIONS_WITH_DEFINITIONS_QUERY_PG10)
          else
            connection.execute(FUNCTIONS_WITH_DEFINITIONS_QUERY)
          end
        end

        def postgresql_10?
          connection.execute('SELECT version()').first['version'] =~ /PostgreSQL 10.*/
        end

        def to_fx_function(result)
          Fx::Function.new(result)
        end
      end
    end
  end
end
