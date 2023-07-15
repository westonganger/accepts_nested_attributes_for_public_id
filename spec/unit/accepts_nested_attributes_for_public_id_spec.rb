require "spec_helper"

RSpec.describe "AcceptsNestedAttributesForPublicId", type: :model do
  include ActionView::Helpers::FormHelper
  attr_accessor :output_buffer ### required for rendering form helpers

  let(:post) { Post.create!(title: "foobar") }

  let(:content_column_value) { "some-content" }

  it "retains methods public/private status" do
    ### Private
    ActionView::Helpers::FormBuilder.private_instance_methods.include?(:fields_for_with_nested_model)
    ActionView::Helpers::FormBuilder.private_instance_methods.include?(:fields_for_with_nested_attributes)
    ActiveRecord::NestedAttributes.private_instance_methods.include?(:assign_nested_attributes_for_one_to_one_association)
    ActiveRecord::NestedAttributes.private_instance_methods.include?(:assign_nested_attributes_for_collection_association)
    ActiveRecord::NestedAttributes.private_instance_methods.include?(:raise_nested_attributes_record_not_found!)

    ### Public
    ActiveRecord::NestedAttributes::ClassMethods.public_instance_methods.include?(:accepts_nested_attributes_for)
  end

  shared_examples "common_tests" do
    let!(:comment) do
      attrs = {content: content_column_value}
      if post.send(association_name).respond_to?(:to_ary)
        post.send(association_name).create!(attrs)
      else
        post.send("create_#{association_name}!", attrs)
      end
    end

    context "actionview" do
      it "fields_for renders existing records correctly" do
        html = form_for(post, url: "/foo") do |f|
          concat f.fields_for(association_name, comment) { |cf|
            concat cf.text_field(:content)
          }
        end

        expected_content_input = %Q(
          <input type=\"text\" value=\"#{content_column_value}\" name=\"post[#{association_name}_attributes][0][content]\" id=\"post_#{association_name}_attributes_0_content\" />
        ).strip

        expected_id_input = %Q(
          <input value=\"#{expected_public_id_value}\" autocomplete=\"off\" type=\"hidden\" name=\"post[#{association_name}_attributes][0][id]\" id=\"post_#{association_name}_attributes_0_id\" />
        ).strip

        if !post.send(association_name).respond_to?(:to_ary)
          expected_content_input.sub!("_0", "").sub!("[0]", "")
          expected_id_input.sub!("_0", "").sub!("[0]", "")
        end

        expect(html).to include(expected_content_input)
        expect(html).to include(expected_id_input)
      end
    end

    context "activerecord" do
      it "updates existing records" do
        attrs = {id: expected_public_id_value, content: "Updated"}

        if post.send(association_name).respond_to?(:to_ary)
          attrs = [attrs]
        end

        post.send("#{association_name}_attributes=", attrs)
        post.save!

        if post.send(association_name).respond_to?(:to_ary)
          expect(post.send(association_name).count).to eq(1)
        else
          expect(post.send(association_name).present?).to eq(true)
        end
        expect(comment.reload.content).to eq("Updated")
      end

      it "creates records" do
        if !post.send(association_name).respond_to?(:to_ary)
          comment.destroy!
          comment = nil
        end

        attrs = {id: "", content: "new record"}

        if post.send(association_name).respond_to?(:to_ary)
          attrs = [attrs]
        end

        post.send("#{association_name}_attributes=", attrs)
        post.save!

        if post.send(association_name).respond_to?(:to_ary)
          expect(post.send(association_name).reload.count).to eq(2)
        else
          expect(post.send(association_name).present?).to eq(true)
        end

        if comment
          expect(comment.reload.content).to eq(content_column_value)
        end

        expect(Comment.last.content).to eq("new record")
      end
    end
  end

  context "accepts_nested_attributes_for_public_id_column" do
    let(:expected_public_id_value) { content_column_value }

    context "has_many" do
      let(:association_name) { :comments_with_accepts_nested_attributes_for_public_id_column }
      it_behaves_like "common_tests"
    end

    context "has_one" do
      let(:association_name) { :has_one_comment_with_accepts_nested_attributes_for_public_id_column }
      it_behaves_like "common_tests"
    end
  end

  context "public_id_column" do
    let(:expected_public_id_value) { content_column_value }

    context "has_many" do
      let(:association_name) { :comments_with_public_id_column }
      it_behaves_like "common_tests"
    end

    context "has_one" do
      let(:association_name) { :has_one_comment_with_public_id_column }
      it_behaves_like "common_tests"
    end
  end

  context "regular id" do
    let(:expected_public_id_value) { comment.id }

    context "has_many" do
      let(:association_name) { :comments_with_regular_id }
      it_behaves_like "common_tests"
    end

    context "has_one" do
      let(:association_name) { :has_one_comment_with_regular_id }
      it_behaves_like "common_tests"
    end
  end
end
