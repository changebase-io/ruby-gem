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

    # TODO: just use event!
    def event_for(type, id, new_options=nil)
      type = type.base_class.model_name.name if !type.is_a?(String)
      event = nil#@events.find { |a| a.subject_type.to_s == type.to_s && a.subject_id.to_s == id.to_s }

      if new_options
        if event
          raise "diff -> columns plz"
          event.diff.merge!(new_options[:diff]) if new_options.has_key?(:diff)
          event
        else
          event!(new_options)
        end
      else
        event
      end
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

    module ActiveRecord
      extend ActiveSupport::Concern

      class_methods do
        def self.extended(other)
          other.after_create      { changebase_track(:insert) }
          other.after_update      { changebase_track(:update) }
          other.before_destroy    { changebase_track(:delete) }
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

        def has_and_belongs_to_many(name, scope = nil, **options, &extension)
          super
          name = name.to_s
          habtm_model = self.const_get("HABTM_#{name.to_s.camelize}")

          foreign_key = options[:foreign_key] || "#{base_class.name.underscore}_id"
          association_foreign_key = options[:association_foreign_key]
          association_foreign_key ||= "#{options[:class_name].underscore}_id" if options[:class_name]
          association_foreign_key ||= "#{name.singularize.underscore}_id"
          inverse_of = (options[:inverse_of] || self.name.underscore.pluralize).to_s

          callback = ->(method, owner, record) {
            
            columns = habtm_model.columns.each_with_index.reduce([]) do |acc, (column, index)|
              byebug
              
              attr_type = self.type_for_attribute(column.name)
              value = self.attributes[column.name]
              previous_value = self.previous_changes[column.name].try(:[], 0)
              previous_value ||= value if identity
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
            
            habtm_model.changebase_track(:delete)
          }
          self.send("after_remove_for_#{name}=", Array(self.send("after_remove_for_#{name}")).compact + [callback])
        end

        # TODO: Shouldn't this just update the join table and not the fake column `#{relation_name}_ids`?
        def changebase_association_changed(id, reflection_or_relation_name, added: [], removed: [], timestamp: nil, type: :update, propagate: true)
          return if removed.empty? && added.empty?
          reflection = if reflection_or_relation_name.is_a?(String) || reflection_or_relation_name.is_a?(Symbol)
            reflect_on_association(reflection_or_relation_name)
          else
            reflection_or_relation_name
          end

          event = Changebase::Inline.current_transaction.event_for(self, id, { type: type, timestamp: timestamp })

          if reflection
            if reflection.collection?
              column_name = "#{reflection.name.to_s.singularize}_ids"

              event.columns[column_name] ||= [[], []]
              event.columns[column_name][0] |= removed
              event.columns[column_name][1] |= added

              in_common = (event.columns[column_name][0] & event.columns[column_name][1])
              if !in_common.empty?
                event.columns[column_name][0] = event.columns[column_name][0] - in_common
                event.columns[column_name][1] = event.columns[column_name][1] - in_common
              end
            else
              column_name = "#{reflection.name.to_s.singularize}_id"
              if event.columns.has_key?(column_name) && event.columns[column_name][0] == added.first
                event.columns.delete(column_name)
              else
                event.columns[column_name] ||= [removed.first, added.first]
              end
            end

            if propagate && inverse_reflection = reflection.inverse_of
              inverse_klass = inverse_reflection.active_record

              added.each do |added_id|
                inverse_klass.changebase_association_changed(added_id, inverse_reflection,
                  added: [id],
                  timestamp: timestamp,
                  type: type,
                  propagate: false
                )
              end

              removed.each do |removed_id|
                inverse_klass.changebase_association_changed(removed_id, inverse_reflection,
                  removed: [id],
                  timestamp: timestamp,
                  type: type,
                  propagate: false
                )
              end
            end
          end
        end

      end

      def changebase_timestamp
        @changebase_timestamp ||= Time.current
      end

      def with_transaction_returning_status
        @changebase_timestamp = Time.current

        if !Thread.current[:changebase_save_lock]
          run_save = true
          Thread.current[:changebase_save_lock] = true
          if !Thread.current[:changebase_transaction]
            destroy_current_transaction = true
            # TODO: Move the metadata from the connection to a thread variable
            metadata = self.class.connection.instance_variable_get(:@changebase_metadata)
            Thread.current[:changebase_transaction] =
              Changebase::Transaction.new(
                timestamp: @changebase_timestamp,
                metadata: metadata)
          end
        end

        status = nil
        self.class.transaction do
          unless has_transactional_callbacks?
            sync_with_transaction_state if @transaction_state&.finalized?
            @transaction_state = self.class.connection.current_transaction.state
          end
          remember_transaction_record_state

          status = yield
          if status
            if run_save && Changebase.configured? && !changebase_transaction.events.empty?
              changebase_transaction&.save!
            end
          else
            raise ::ActiveRecord::Rollback
          end
          status
        ensure
          @changebase_timestamp = nil
          if run_save
            Thread.current[:changebase_save_lock] = false
          end
          if destroy_current_transaction
            Thread.current[:changebase_transaction] = nil
          end

          if has_transactional_callbacks? &&
              (@_new_record_before_last_commit && !new_record? || _trigger_update_callback || _trigger_destroy_callback)
            add_to_transaction
          end
        end
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
          next if !identity && !self.previous_changes.has_key?(column.name)
          
          attr_type = self.type_for_attribute(column.name)
          value = self.attributes[column.name]
          previous_value = self.previous_changes[column.name].try(:[], 0)
          previous_value ||= value if identity
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
        

        # columns.sort_by! { |c| c[:index] }
        # if type == :create || type == :update
        #   columns = self.saved_changes.select { |k,v| !changebase_tracking[:exclude].include?(k.to_sym) }

        #   if type == :create
        #     self.class.columns.each_with_index do |column, i|
        #       if !columns[column.name] && !changebase_tracking[:exclude].include?(column.name.to_sym) && column.default != self.attributes[column.name]
        #         [nil, self.attributes[column.name]]
        #       end
        #     end
        #   end
        # elsif type == :delete
        #   relations_ids = self.class.reflect_on_all_associations.map { |r| "#{r.name.to_s.singularize}_ids" }

        #   diff = self.attributes.select do |k|
        #     !changebase_tracking[:exclude].include?(k.to_sym)
        #   end.map do |k, i|
        #     if relations_ids.include?(k)
        #       [ k, [ i, [] ] ]
        #     else
        #       [ k, [ i, nil ] ]
        #     end
        #   end.to_h
        # end

        # if type == :update
        #   diff_without_timestamps = if self.class.record_timestamps
        #     diff.keys - (self.class.send(:timestamp_attributes_for_update_in_model) + self.class.send(:timestamp_attributes_for_create_in_model))
        #   else
        #     diff.keys
        #   end

        #   return if diff_without_timestamps.empty?
        # end

        # TODO: If this is a HABTM create events for the join table
        if changebase_tracking[:habtm_model]
        #   if type == :create
        #     left_side = self.class.reflect_on_association(:left_side)
        #     left_side_id_name = changebase_tracking[:habtm_model][:left_side][:foreign_key]
        #     left_side_id = self.send(left_side_id_name)
        #     right_side_name = changebase_tracking[:habtm_model].keys.find { |x| x != :left_side }
        #     right_side = self.class.reflect_on_association(right_side_name)
        #     right_side_id_name = changebase_tracking[:habtm_model][right_side_name][:foreign_key]
        #     right_side_id = self.send(right_side_id_name)

        #     left_side.klass.changebase_association_changed(
        #       left_side_id,
        #       changebase_tracking[:habtm_model][:left_side][:inverse_of],
        #       added: [right_side_id],
        #       timestamp: changebase_timestamp,
        #       propagate: false
        #     )

        #     right_side.klass.changebase_association_changed(
        #       right_side_id,
        #       changebase_tracking[:habtm_model][right_side_name][:inverse_of],
        #       added: [left_side_id],
        #       timestamp: changebase_timestamp,
        #       propagate: false
        #     )
        #   end
        else
          # Emit the event
          changebase_transaction.event_for(self.class.table_name, id, {
            schema: columns[0].try(:[], :schema) || self.class.connection.current_schema,
            table: self.class.table_name,
            type: type,
            columns: columns,
            timestamp: changebase_timestamp
          })

          # self.class.reflect_on_all_associations.each do |reflection|
          #   next if changebase_tracking[:habtm_model]

          #   if reflection.macro == :has_and_belongs_to_many && type == :delete
          #     changebase_association_changed(reflection, removed: self.send("#{reflection.name.to_s.singularize}_ids"))
          #   elsif reflection.macro == :belongs_to && diff.has_key?(reflection.foreign_key)
          #     case type
          #     when :create
          #       old_id = nil
          #       new_id = diff[reflection.foreign_key][1]
          #     when :delete
          #       old_id = diff[reflection.foreign_key][0]
          #       new_id = nil
          #     else
          #       old_id = diff[reflection.foreign_key][0]
          #       new_id = diff[reflection.foreign_key][1]
          #     end

          #     relation_id = self.id || diff.find { |k, v| k != foreign_key }[1][1]

          #     if reflection.polymorphic?
          #     else
          #       changebase_association_changed(reflection, removed: [old_id]) if old_id
          #       changebase_association_changed(reflection, added:   [new_id]) if new_id
          #     end

          #   end
          # end
        end
      end

      def changebase_association_changed(relation_name, added: [], removed: [], timestamp: nil, type: :update)
        # changebase_transaction.event_for(self.class.table_name, id, {
        #   schema: columns[0].try(:[], :schema) || self.class.connection.current_schema,
        #   table: self.class.table_name,
        #   type: type,
        #   columns: {},
        #   timestamp: timestamp || changebase_timestamp
        # })
        

        self.class.changebase_association_changed(id, relation_name,
          added: added,
          removed: removed,
          timestamp: timestamp,
          type: type
        )
      end

      def changebase_association_udpated(reflection, id, added: [], removed: [], timestamp: nil, type: :update)
        return if !changebase_tracking || (removed.empty? && added.empty?)
        klass = reflection.active_record
        inverse_klass = reflection.klass

        inverse_association = if changebase_tracking.has_key?(:habtm_model)
          inverse_klass.reflect_on_association(changebase_tracking.dig(:habtm_model, reflection.name.to_s.singularize.to_sym, :inverse_of))
        else
          reflection.inverse_of
        end

        if inverse_association.nil?
          puts "NO INVERSE for #{self.class}.#{reflection.name}!!!"
          return
        end

        event = changebase_transaction.event_for(klass, id, {
          type: type,
          timestamp: timestamp
        })

        event.diff ||= {}
        if (reflection.collection? || changebase_tracking[:habtm_model])
          diff_key = "#{reflection.name.to_s.singularize}_ids"
          event.diff[diff_key] ||= [[], []]
          event.diff[diff_key][0] |= removed
          event.diff[diff_key][1] |= added
        else
          diff_key = "#{reflection.name.to_s.singularize}_id"
          event.diff[diff_key] ||= [removed.first, added.first]
        end

        removed.each do |removed_id|
          event = changebase_transaction.event_for(inverse_klass, removed_id, {
            type: type,
            timestamp: timestamp
          })

          event.diff ||= {}

          if inverse_association.collection? || changebase_tracking[:habtm_model]
            diff_key = "#{inverse_association.name.to_s.singularize}_ids"
            event.diff[diff_key] ||= [[], []]
            event.diff[diff_key][0] |= [id]
          else
            diff_key = "#{inverse_association.name.to_s.singularize}_id"
            event.diff[diff_key] ||= [id, nil]
          end
        end

        added.each do |added_id|
          event = changebase_transaction.event_for(inverse_klass, added_id, {
            type: type,
            timestamp: timestamp
          })

          event.diff ||= {}
          if inverse_association.collection? || changebase_tracking[:habtm_model]
            diff_key = "#{inverse_association.name.to_s.singularize}_ids"
            event.diff[diff_key] ||= [[], []]
            event.diff[diff_key][1] |= [id]
          else
            diff_key = "#{inverse_association.name.to_s.singularize}_id"
            event.diff[diff_key] ||= [nil, id]
          end
        end
      end

      module Associations
        class CollectionAssociation
          def delete_all(dependent = nil)
            changebase_encapsulate do
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
                  timestamp: owner.changebase_timestamp
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
                      timestamp: owner.changebase_timestamp
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
              end

              delete_or_nullify_all_records(dependent).tap do
                reset
                loaded!
              end
            end
          end

          private

          def replace_records(new_target, original_target)
            changebase_encapsulate do
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
            end

            target
          end

          def delete_or_destroy(records, method)
            changebase_encapsulate do
              records = find(records) if records.any? { |record| record.kind_of?(Integer) || record.kind_of?(String) }
              records = records.flatten
              records.each { |record| raise_on_type_mismatch!(record) }
              existing_records = records.reject(&:new_record?)

              if existing_records.empty?
                remove_records(existing_records, records, method)
              else
                transaction { remove_records(existing_records, records, method) }
              end
            end
          end

          def changebase_encapsulate
            @changebase_timestamp = Time.current

            if !Thread.current[:changebase_save_lock]
              run_save = true
              Thread.current[:changebase_save_lock] = true
              if Thread.current[:changebase_transaction].nil?
                destroy_current_transaction = true
                # TODO: Move the metadata from the connection to a thread variable
                metadata = self.class.connection.instance_variable_get(:@changebase_metadata)
                Thread.current[:changebase_transaction] =
                  Changebase::Transaction.new(
                    timestamp: @changebase_timestamp,
                    metadata: metadata)
              end
            end

            result = yield

            if run_save && Changebase.configured?  && !owner.changebase_transaction.events.empty?
              owner.changebase_transaction&.save!
            end

            result
          ensure
            @changebase_timestamp = nil
            if run_save
              Thread.current[:changebase_save_lock] = false
            end
            if destroy_current_transaction
              Thread.current[:changebase_transaction] = nil
            end
          end
        end
      end
    end
  end
end
