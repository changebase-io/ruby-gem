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
          sql = ::ActiveRecord::Base.send(:replace_named_bind_variables, <<~SQL, {version: 1, metadata: ActiveSupport::JSON.encode(@changebase_metadata)})
            INSERT INTO #{quote_table_name(Changebase.metadata_table)} ( version, data )
            VALUES ( :version, :metadata )
            ON CONFLICT ( version )
            DO UPDATE SET version = :version, data = :metadata;
          SQL
  
          log(sql, "CHANGEBASE") do
            ActiveSupport::Dependencies.interlock.permit_concurrent_loads do
              @connection.async_exec(sql)
            end
          end
        end
        super
      end
    end
    
  end
end