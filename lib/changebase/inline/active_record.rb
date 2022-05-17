require 'securerandom'

module Changebase

  class Transaction

    attr_accessor :id, :metadata, :timestamp, :events

    def initialize(attrs={})
      attrs.each { |k,v| self.send("#{k}=", v) }

      if id
        @persisted = true
      else
        @persisted = false
        @id ||= SecureRandom.uuid
      end

      @events ||= []
      @timestamp ||= Time.now
      @metadata ||= {}
    end

    def persisted?
      @persisted
    end

    def event!(event)
      event = Changebase::Event.new(event)
      @events << event
      event
    end

    def self.create!(attrs={})
      transaction = self.new(attrs)
      transaction.save!
      transaction
    end

    def save!
      persisted? ? _update : _create
    end

    def _update
      return if events.empty?
      events.delete_if { |a| a.diff.empty? }
      payload = JSON.generate({events: events.as_json.map{ |json| json[:transaction_id] = id; json }})
      Changebase.logger.debug("[Changebase] POST /events WITH #{payload}")
      Changebase.connection.post('/events', payload)
      @events = []
    end

    def _create
      events.delete_if { |a| a.columns.empty? }
      payload = JSON.generate({transaction: self.as_json})
      Changebase.logger.debug("[Changebase] POST /transactions WITH #{payload}")
      Changebase.connection.post('/transactions', payload)
      @events = []
      @persisted = true
    end

    def as_json
      result = {
        id:                   id,
        lsn:                  timestamp.utc.iso8601(3),
        timestamp:            timestamp.utc.iso8601(3),
        events:               events.as_json
      }
      result[:metadata] = metadata.as_json if !metadata.empty?
      result
    end

  end

  class Event

    attr_accessor :id, :database_id, :transaction_id, :type, :schema,
      :table, :timestamp, :created_at, :columns

    def initialize(attrs)
      attrs.each do |k,v|
        self.send("#{k}=", v)
      end
      self.columns ||= {}
    end

    def as_json
      {
        id: id,
        transaction_id:     transaction_id,
        lsn:                timestamp.utc.iso8601(3),
        type: type,
        schema: schema,
        table: table,
        timestamp:    timestamp.utc.iso8601(3),
        columns:         columns.as_json,
      }.select { |k, v| !v.nil? }
    end

  end

  module Inline

    def self.current_transaction
      Thread.current[:changebase_transaction]
    end

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

            owner.changebase_transaction.event!({
              schema: columns[0].try(:[], :schema) || through_model.connection.current_schema,
              table: through_model.table_name,
              type: :delete,
              columns: columns,
              timestamp: Time.current
            })
          end
        end

        x
      end
    end

    module HasMany
      def delete_or_nullify_all_records(method)
        super
        if method == :delete_all
          target.each do |record|
            record.changebase_track(:delete)
          end
        end

      end
    end

    module ActiveRecord

      module PostgreSQLAdapter
        # Begins a transaction.
        def begin_db_transaction
          super
          Thread.current[:changebase_transaction] = Changebase::Transaction.new(
              timestamp: Time.current,
              metadata: @changebase_metadata
          )
        end

        # Aborts a transaction.
        def exec_rollback_db_transaction
          super
        ensure
          Thread.current[:changebase_transaction] = nil
        end

        # Commits a transaction.
        def commit_db_transaction
          Thread.current[:changebase_transaction]&.save!
          super
        end

        def changebase_transaction
          Thread.current[:changebase_transaction]
        end
      end

      extend ActiveSupport::Concern

      class_methods do
        def self.extended(other)
          other.after_create      { changebase_track(:insert) }
          other.after_update      { changebase_track(:update) }
          other.after_destroy    { changebase_track(:delete) }
        end

        # def inherited(subclass)
        #   super
        #   subclass.instance_variable_set('@changebase', @changebase.clone) if defined?(@changebase)
        # end
        #
        # def track(track_model = true, exclude: [], habtm_model: nil)
        #   if track_model == false
        #     @changebase = nil
        #   else
        #     options = { exclude: Array(exclude) }
        #     options[:habtm_model] = habtm_model if habtm_model
        #     @changebase = options
        #   end
        # end
      end

      def changebase_tracking
        if Changebase.configured?# && self.class.instance_variable_defined?(:@changebase)
          # self.class.instance_variable_get(:@changebase)
          {exclude: []}
        end
      end

      def changebase_transaction
        Changebase::Inline.current_transaction
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

      module Associations
        class CollectionAssociation
          def delete_all(dependent = nil)
            # changebase_encapsulate do
              if dependent && ![:nullify, :delete_all].include?(dependent)
                raise ArgumentError, "Valid values are :nullify or :delete_all"
              end

              dependent = if dependent
                            dependent
                          elsif options[:dependent] == :delete
                            :delete_all
                          else
                            options[:dependent]
                          end

              if dependent == :delete_all

              elsif !owner.id.nil?
                removed_ids = self.scope.pluck(:id)

                event = owner.changebase_transaction.event_for(self.reflection.active_record, owner.id, {
                  type: :update,
                  timestamp: Time.current
                })

                diff_key = "#{self.reflection.name.to_s.singularize}_ids"
                event.diff ||= {}
                event.diff[diff_key] ||= [[], []]
                event.diff[diff_key][0] |= removed_ids

                ainverse_of = self.klass.reflect_on_association(self.options[:inverse_of])
                if ainverse_of
                  removed_ids.each do |removed_id|
                    event = owner.changebase_transaction.event_for(ainverse_of.active_record, removed_id, {
                      type: :update,
                      timestamp: Time.current
                    })
                    event.diff ||= {}
                    if ainverse_of.collection?
                      diff_key = "#{ainverse_of.name.to_s.singularize}_ids"
                      event.diff[diff_key] ||= [[], []]
                      event.diff[diff_key][0] |= [owner.id]
                    else
                      diff_key = "#{ainverse_of.name}_id"
                      event.diff[diff_key] ||= [owner.id, nil]
                    end
                  end
                end
              # end

              delete_or_nullify_all_records(dependent).tap do
                reset
                loaded!
              end
            end
          end

          private

          def replace_records(new_target, original_target)
            # changebase_encapsulate do
              removed_records = target - new_target
              added_records = new_target - target

              delete(difference(target, new_target))

              unless concat(difference(new_target, target))
                @target = original_target
                raise RecordNotSaved, "Failed to replace #{reflection.name} because one or more of the " \
                                      "new records could not be saved."
              end

              if !owner.new_record?
                owner.changebase_association_changed(self.reflection, added: added_records.map(&:id), removed: removed_records.map(&:id))
              end
            # end

            target
          end

          def delete_or_destroy(records, method)
            # changebase_encapsulate do
              records = find(records) if records.any? { |record| record.kind_of?(Integer) || record.kind_of?(String) }
              records = records.flatten
              records.each { |record| raise_on_type_mismatch!(record) }
              existing_records = records.reject(&:new_record?)

              if existing_records.empty?
                remove_records(existing_records, records, method)
              else
                transaction { remove_records(existing_records, records, method) }
              end
            # end
          end

        end
      end
    end
  end
end
