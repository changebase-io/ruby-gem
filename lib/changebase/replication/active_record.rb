module Changebase::Replication
  module ActiveRecord
    module PostgreSQLAdapter

      def initialize(*args, **margs)
        @without_changebase = false
        @changebase_metadata = nil
        super
      end

      def without_changebase
        @without_changebase = true
        yield
      ensure
        @without_changebase = false
      end

      def drop_database(name) # :nodoc:
        without_changebase { super }
      end

      def drop_table(table_name, **options) # :nodoc:
        without_changebase { super }
      end

      def create_database(name, options = {})
        without_changebase { super }
      end

      def recreate_database(name, options = {}) # :nodoc:
        without_changebase { super }
      end

      def execute(sql, name = nil)
        if !@without_changebase && !current_transaction.open? && write_query?(sql)
          transaction { super }
        else
          super
        end
      end

      def exec_query(sql, name = "SQL", binds = [], prepare: false)
        if !@without_changebase && !current_transaction.open? && write_query?(sql)
          transaction { super }
        else
          super
        end
      end

      def exec_delete(sql, name = nil, binds = []) # :nodoc:
        if !@without_changebase && !current_transaction.open? && write_query?(sql)
          transaction { super }
        else
          super
        end
      end

      def commit_db_transaction
        if !@without_changebase && @changebase_metadata && !@changebase_metadata.empty?
          sql = case Changebase.metadata_mode
          when 'message'
            ::ActiveRecord::Base.send(:replace_named_bind_variables, <<~SQL, {prefix: Changebase.metadata_message_prefix, metadata: ActiveSupport::JSON.encode(@changebase_metadata)})
              SELECT pg_logical_emit_message(true, :prefix, :metadata);
            SQL
          when 'table'
            ::ActiveRecord::Base.send(:replace_named_bind_variables, <<~SQL, {version: 1, metadata: ActiveSupport::JSON.encode(@changebase_metadata)})
              INSERT INTO #{quote_table_name(Changebase.metadata_table)} ( version, data )
              VALUES ( :version, :metadata )
              ON CONFLICT ( version )
              DO UPDATE SET version = :version, data = :metadata;
            SQL
          end

          log(sql, "CHANGEBASE") do
            ActiveSupport::Dependencies.interlock.permit_concurrent_loads do
              if defined?(@connection) # <= Rails 7.0
                @connection.async_exec(sql)
              else # >= Rails 7.1
                with_raw_connection { |conn| conn.async_exec(sql) }
              end              
            end
          end
        end
        
        super
      end

      if ::ActiveRecord.gem_version < ::Gem::Version.new("6.0.0")
        CHANGEBASE_COMMENT_REGEX = %r{(?:--.*\n)|/\*(?:[^*]|\*[^/])*\*/}m
        def self.changebase_build_read_query_regexp(*parts) # :nodoc:
          parts += [:begin, :commit, :explain, :release, :rollback, :savepoint, :select, :with]
          parts = parts.map { |part| /#{part}/i }
          /\A(?:[(\s]|#{CHANGEBASE_COMMENT_REGEX})*#{Regexp.union(*parts)}/
        end
              
        CHANGEBASE_READ_QUERY = changebase_build_read_query_regexp(
          :close, :declare, :fetch, :move, :set, :show
        )
        def write_query?(sql)
          !CHANGEBASE_READ_QUERY.match?(sql)
        rescue ArgumentError # Invalid encoding
          !CHANGEBASE_READ_QUERY.match?(sql.b)
        end
      end

    end
  end
end