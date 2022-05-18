require 'securerandom'

module Changebase
  module Inline

    module Through
      extend ActiveSupport::Concern

      def delete_records(records, method)
        x = super

        if method != :destroy
          records.each do |record|
            through_model = source_reflection.active_record

            columns = through_model.columns.each_with_index.reduce([]) do |acc, (column, index)|
              attr_type = through_model.type_for_attribute(column.name)
              previous_value = attr_type.serialize(column.name == source_reflection.foreign_key ? record.id : owner.id)
              acc << {
                index: index,
                identity: true,
                name: column.name,
                type: column.sql_type,
                value: nil,
                previous_value: previous_value
              }
              acc
            end

            transaction = through_model.connection.changebase_transaction || Changebase::Inline::Transaction.new(
              timestamp: Time.current,
              metadata: through_model.connection.instance_variable_get(:@changebase_metadata)
            )

            transaction.event!({
              schema: columns[0].try(:[], :schema) || through_model.connection.current_schema,
              table: through_model.table_name,
              type: :delete,
              columns: columns,
              timestamp: Time.current
            })

            # Save the Changebase::Transaction if we are not in a transaction.
            transaction.save! if !through_model.connection.changebase_transaction
          end
        end

        x
      end
    end

    module HasMany
      
      def delete_or_nullify_all_records(method)
        x = super
        if method == :delete_all
          target.each { |record| record.changebase_track(:delete) }
        end
        x
      end
      
    end

    module ActiveRecord

      module PostgreSQLAdapter
        
        attr_reader :changebase_transaction
        
        # Begins a transaction.
        def begin_db_transaction
          super
          @changebase_transaction = Changebase::Inline::Transaction.new(
            timestamp: Time.current,
            metadata: @changebase_metadata
          )
        end

        # Aborts a transaction.
        def exec_rollback_db_transaction
          super
        ensure
          @changebase_transaction = nil
        end

        # Commits a transaction.
        def commit_db_transaction
          @changebase_transaction&.save!
          @changebase_transaction = nil
          super
        end
      end

      extend ActiveSupport::Concern

      class_methods do
        def self.extended(other)
          other.after_create      { changebase_track(:insert) }
          other.after_update      { changebase_track(:update) }
          other.after_destroy     { changebase_track(:delete) }
        end

      end

      def changebase_tracking
        if Changebase.configured?# && self.class.instance_variable_defined?(:@changebase)
          # self.class.instance_variable_get(:@changebase)
          {exclude: []}
        end
      end

      def changebase_transaction
        self.class.connection.changebase_transaction
      end

      def changebase_track(type)
        return if !changebase_tracking
        return if type == :update && self.previous_changes.empty?

        # Go through each of the Model#attributes and grab the type from the
        # Model#type_for_attribute(attr) to do the serialization, grab the
        # column definition using Model#column_for_attribute(attr) to write the
        # type, and use Model.columns.index(col) to grab the index of the column
        # in the database.
        columns = self.class.columns.each_with_index.reduce([]) do |acc, (column, index)|
          identity = self.class.primary_key ? self.class.primary_key == column.name : true

          attr_type = self.type_for_attribute(column.name)
          value = self.attributes[column.name]
          previous_value = self.previous_changes[column.name].try(:[], 0)

          case type
          when :update
            previous_value ||= value
          when :delete
            previous_value ||= value
            value = nil
          end

          acc << {
            index: index,
            identity: identity,
            name: column.name,
            type: column.sql_type,
            value: attr_type.serialize(value),
            previous_value: attr_type.serialize(previous_value)
          }
          acc
        end

        # Emit the event
        changebase_transaction.event!({
          schema: columns[0].try(:[], :schema) || self.class.connection.current_schema,
          table: self.class.table_name,
          type: type,
          columns: columns,
          timestamp: Time.current
        })
      end

    end
  end
end
