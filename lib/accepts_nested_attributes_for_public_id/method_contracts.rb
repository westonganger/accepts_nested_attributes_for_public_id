module AcceptsNestedAttributesForPublicId
  def verify_method_contract!(method, contract)
    if method.source.strip.gsub(/^\s*/, "") != contract.strip.gsub(/^\s*/, "")
      raise RuntimeError.new("Method definition contract violated for '#{self.class.name}##{method.name}', cannot apply patch for accepts_nested_attribute_for_public_id")
    end
  end
  module_function :verify_method_contract!
end

ActiveSupport.on_load(:action_view) do
  AcceptsNestedAttributesForPublicId.verify_method_contract!(
    ActionView::Helpers::FormBuilder.instance_method(:fields_for_with_nested_attributes),
    <<-'CODE'
      def fields_for_with_nested_attributes(association_name, association, options, block)
        name = "#{object_name}[#{association_name}_attributes]"
        association = convert_to_model(association)

        if association.respond_to?(:persisted?)
          association = [association] if @object.public_send(association_name).respond_to?(:to_ary)
        elsif !association.respond_to?(:to_ary)
          association = @object.public_send(association_name)
        end

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
    CODE
  )

  AcceptsNestedAttributesForPublicId.verify_method_contract!(
    ActionView::Helpers::FormBuilder.instance_method(:fields_for_nested_model),
    <<-'CODE'
      def fields_for_nested_model(name, object, fields_options, block)
        object = convert_to_model(object)
        emit_hidden_id = object.persisted? && fields_options.fetch(:include_id) {
          options.fetch(:include_id, true)
        }

        @template.fields_for(name, object, fields_options) do |f|
          output = @template.capture(f, &block)
          output.concat f.hidden_field(:id) if output && emit_hidden_id && !f.emitted_hidden_id?
          output
        end
      end
    CODE
  )
end

ActiveSupport.on_load(:active_record) do
  AcceptsNestedAttributesForPublicId.verify_method_contract!(
    ActiveRecord::NestedAttributes::ClassMethods.instance_method(:accepts_nested_attributes_for),
    <<-'CODE'
      def accepts_nested_attributes_for(*attr_names)
        options = { allow_destroy: false, update_only: false }
        options.update(attr_names.extract_options!)
        options.assert_valid_keys(:allow_destroy, :reject_if, :limit, :update_only)
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
    CODE
  )

  AcceptsNestedAttributesForPublicId.verify_method_contract!(
    ActiveRecord::NestedAttributes.instance_method(:assign_nested_attributes_for_one_to_one_association),
    <<-'CODE'
      def assign_nested_attributes_for_one_to_one_association(association_name, attributes)
        options = nested_attributes_options[association_name]
        if attributes.respond_to?(:permitted?)
          attributes = attributes.to_h
        end
        attributes = attributes.with_indifferent_access
        existing_record = send(association_name)

        if (options[:update_only] || !attributes["id"].blank?) && existing_record &&
          (options[:update_only] || existing_record.id.to_s == attributes["id"].to_s)
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
    CODE
  )

  AcceptsNestedAttributesForPublicId.verify_method_contract!(
    ActiveRecord::NestedAttributes.instance_method(:assign_nested_attributes_for_collection_association),
    <<-'CODE'
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

        existing_records = if association.loaded?
          association.target
        else
          attribute_ids = attributes_collection.filter_map { |a| a["id"] || a[:id] }
          attribute_ids.empty? ? [] : association.scope.where(association.klass.primary_key => attribute_ids)
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
          elsif existing_record = existing_records.detect { |record| record.id.to_s == attributes["id"].to_s }
            unless call_reject_if(association_name, attributes)
              # Make sure we are operating on the actual object which is in the association's
              # proxy_target array (either by finding it, or adding it if not found)
              # Take into account that the proxy_target may have changed due to callbacks
              target_record = association.target.detect { |record| record.id.to_s == attributes["id"].to_s }
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
    CODE
  )

  AcceptsNestedAttributesForPublicId.verify_method_contract!(
    ActiveRecord::NestedAttributes.instance_method(:raise_nested_attributes_record_not_found!),
    <<-'CODE'
      def raise_nested_attributes_record_not_found!(association_name, record_id)
        model = self.class._reflect_on_association(association_name).klass.name
        raise RecordNotFound.new("Couldn't find #{model} with ID=#{record_id} for #{self.class.name} with ID=#{id}",
                                 model, "id", record_id)
      end
    CODE
  )
end
