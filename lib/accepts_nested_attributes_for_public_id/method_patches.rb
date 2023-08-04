ActiveSupport.on_load(:action_view) do
  module ActionView
    module Helpers
      class FormBuilder
        private

        def fields_for_with_nested_attributes(association_name, association, options, block)
          name = "#{object_name}[#{association_name}_attributes]"
          association = convert_to_model(association)

          if association.respond_to?(:persisted?)
            association = [association] if @object.public_send(association_name).respond_to?(:to_ary)
          elsif !association.respond_to?(:to_ary)
            association = @object.public_send(association_name)
          end

          ### NEW
          if @object.respond_to?(:nested_attributes_options)
            options[:public_id_column] = @object.nested_attributes_options.dig(association_name.to_sym, :public_id_column)
          end
          ### END NEW

          if association.respond_to?(:to_ary)
            explicit_child_index = options[:child_index]
            output = ActiveSupport::SafeBuffer.new
            association.each do |child|
              if explicit_child_index
                options[:child_index] = explicit_child_index.call if explicit_child_index.respond_to?(:call)
              else
                options[:child_index] = nested_child_index(name)
              end
              if content = fields_for_nested_model("#{name}[#{options[:child_index]}]", child, options, block)
                output << content
              end
            end
            output
          elsif association
            fields_for_nested_model(name, association, options, block)
          end
        end

        def fields_for_nested_model(name, object, fields_options, block)
          object = convert_to_model(object)
          emit_hidden_id = object.persisted? && fields_options.fetch(:include_id) {
            options.fetch(:include_id, true)
          }

          @template.fields_for(name, object, fields_options) do |f|
            output = @template.capture(f, &block)

            ### ORIGINAL
            # output.concat f.hidden_field(:id) if output && emit_hidden_id && !f.emitted_hidden_id?
            ### NEW
            if f.object.class.respond_to?(:accepts_nested_attributes_for_public_id_column)
              public_id_column = f.object.class.accepts_nested_attributes_for_public_id_column
              public_id_value = f.object.send(public_id_column)
            elsif fields_options[:public_id_column]
              public_id_value = f.object.send(fields_options[:public_id_column])
              fields_options.delete(:public_id_column)
            else
              public_id_value = f.object.id
            end
            output.concat f.hidden_field(:id, value: public_id_value) if output && emit_hidden_id && !f.emitted_hidden_id?
            ### END NEW

            output
          end
        end
      end
    end
  end
end

ActiveSupport.on_load(:active_record) do
  module ActiveRecord
    module NestedAttributes
      module ClassMethods
        def accepts_nested_attributes_for(*attr_names)
          options = { allow_destroy: false, update_only: false }
          options.update(attr_names.extract_options!)
          ### ORIGINAL
          # options.assert_valid_keys(:allow_destroy, :reject_if, :limit, :update_only)
          ### NEW
          options.assert_valid_keys(:allow_destroy, :reject_if, :limit, :update_only, :public_id_column)
          ### END NEW
          options[:reject_if] = REJECT_ALL_BLANK_PROC if options[:reject_if] == :all_blank

          attr_names.each do |association_name|
            if reflection = _reflect_on_association(association_name)
              reflection.autosave = true
              define_autosave_validation_callbacks(reflection)

              nested_attributes_options = self.nested_attributes_options.dup
              nested_attributes_options[association_name.to_sym] = options
              self.nested_attributes_options = nested_attributes_options

              type = (reflection.collection? ? :collection : :one_to_one)
              generate_association_writer(association_name, type)
            else
              raise ArgumentError, "No association found for name `#{association_name}'. Has it been defined yet?"
            end
          end
        end
      end
    end

    module NestedAttributes
      private

      def assign_nested_attributes_for_one_to_one_association(association_name, attributes)
        options = nested_attributes_options[association_name]
        if attributes.respond_to?(:permitted?)
          attributes = attributes.to_h
        end
        attributes = attributes.with_indifferent_access
        existing_record = send(association_name)

        ### ORIGINAL
        # if (options[:update_only] || !attributes["id"].blank?) && existing_record &&
        #   (options[:update_only] || existing_record.id.to_s == attributes["id"].to_s)
        ### NEW
        if self.class.reflect_on_association(association_name).klass.respond_to?(:accepts_nested_attributes_for_public_id_column)
          public_id_column = self.class.reflect_on_association(association_name).klass.accepts_nested_attributes_for_public_id_column
        elsif options[:public_id_column]
          public_id_column = options[:public_id_column]
        else
          public_id_column = :id
        end

        if (options[:update_only] || !attributes["id"].blank?) && existing_record &&
          (options[:update_only] || existing_record.send(public_id_column).to_s == attributes["id"].to_s)
        ### END NEW
          assign_to_or_mark_for_destruction(existing_record, attributes, options[:allow_destroy]) unless call_reject_if(association_name, attributes)

        elsif attributes["id"].present?
          raise_nested_attributes_record_not_found!(association_name, attributes["id"])

        elsif !reject_new_record?(association_name, attributes)
          assignable_attributes = attributes.except(*UNASSIGNABLE_KEYS)

          if existing_record && existing_record.new_record?
            existing_record.assign_attributes(assignable_attributes)
            association(association_name).initialize_attributes(existing_record)
          else
            method = :"build_#{association_name}"
            if respond_to?(method)
              send(method, assignable_attributes)
            else
              raise ArgumentError, "Cannot build association `#{association_name}'. Are you trying to build a polymorphic one-to-one association?"
            end
          end
        end
      end

      def assign_nested_attributes_for_collection_association(association_name, attributes_collection)
        options = nested_attributes_options[association_name]
        if attributes_collection.respond_to?(:permitted?)
          attributes_collection = attributes_collection.to_h
        end

        unless attributes_collection.is_a?(Hash) || attributes_collection.is_a?(Array)
          raise ArgumentError, "Hash or Array expected for attribute `#{association_name}`, got #{attributes_collection.class.name} (#{attributes_collection.inspect})"
        end

        check_record_limit!(options[:limit], attributes_collection)

        if attributes_collection.is_a? Hash
          keys = attributes_collection.keys
          attributes_collection = if keys.include?("id") || keys.include?(:id)
            [attributes_collection]
          else
            attributes_collection.values
          end
        end

        association = association(association_name)

        ### NEW
        if association.klass.respond_to?(:accepts_nested_attributes_for_public_id_column)
          public_id_column = association.klass.accepts_nested_attributes_for_public_id_column
        elsif nested_attributes_options[association.reflection.name][:public_id_column]
          public_id_column = nested_attributes_options[association.reflection.name][:public_id_column]
        else
          public_id_column = :id
        end
        ### END NEW

        existing_records = if association.loaded?
          association.target
        else
          attribute_ids = attributes_collection.map { |a| a["id"] || a[:id] }.compact
          ### ORIGINAL
          # attribute_ids.empty? ? [] : association.scope.where(association.klass.primary_key => attribute_ids)
          ### NEW
          attribute_ids.empty? ? [] : association.scope.where(public_id_column => attribute_ids)
          ### END NEW
        end

        attributes_collection.each do |attributes|
          if attributes.respond_to?(:permitted?)
            attributes = attributes.to_h
          end
          attributes = attributes.with_indifferent_access

          if attributes["id"].blank?
            unless reject_new_record?(association_name, attributes)
              association.reader.build(attributes.except(*UNASSIGNABLE_KEYS))
            end
          ### ORIGINAL
          # elsif existing_record = existing_records.detect { |record| record.id.to_s == attributes["id"].to_s }
          ### NEW
          elsif existing_record = existing_records.detect { |record| record.send(public_id_column).to_s == attributes["id"].to_s }
          ### END NEW
            unless call_reject_if(association_name, attributes)
              # Make sure we are operating on the actual object which is in the association's
              # proxy_target array (either by finding it, or adding it if not found)
              # Take into account that the proxy_target may have changed due to callbacks
              ### ORIGINAL
              # target_record = association.target.detect { |record| record.id.to_s == attributes["id"].to_s }
              ### NEW
              target_record = association.target.detect { |record| record.send(public_id_column).to_s == attributes["id"].to_s }
              ### END NEW

              if target_record
                existing_record = target_record
              else
                association.add_to_target(existing_record, skip_callbacks: true)
              end

              assign_to_or_mark_for_destruction(existing_record, attributes, options[:allow_destroy])
            end
          else
            raise_nested_attributes_record_not_found!(association_name, attributes["id"])
          end
        end
      end

      def raise_nested_attributes_record_not_found!(association_name, record_id)
        model = self.class._reflect_on_association(association_name).klass.name
        ### ORIGINAL
        # raise RecordNotFound.new("Couldn't find #{model} with ID=#{record_id} for #{self.class.name} with ID=#{id}",
        #                          model, "id", record_id)
        ### NEW
        if self.class._reflect_on_association(association_name).klass.respond_to?(:accepts_nested_attributes_for_public_id_column)
          id_column = self.class._reflect_on_association(association_name).klass.accepts_nested_attributes_for_public_id_column
        elsif nested_attributes_options[association_name][:public_id_column]
          id_column = nested_attributes_options[association_name][:public_id_column].to_s
        else
          id_column = "id"
        end
        raise RecordNotFound.new(
          "Couldn't find #{model} with ID=#{record_id} for #{self.class.name} with ID=#{id}",
          model,
          id_column,
          record_id,
        )
        ### END NEW
      end
    end
  end
end
