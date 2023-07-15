class Post < ApplicationRecord
  ### accepts_nested_attributes_for_public_id_column
  has_many :comments_with_accepts_nested_attributes_for_public_id_column, class_name: "CommentWithToParamColumn"
  accepts_nested_attributes_for :comments_with_accepts_nested_attributes_for_public_id_column

  has_one :has_one_comment_with_accepts_nested_attributes_for_public_id_column, class_name: "CommentWithToParamColumn"
  accepts_nested_attributes_for :has_one_comment_with_accepts_nested_attributes_for_public_id_column

  ### accepts_nested_attribute_for public_id_column
  has_many :comments_with_public_id_column, class_name: "Comment"
  accepts_nested_attributes_for :comments_with_public_id_column, public_id_column: :content

  has_one :has_one_comment_with_public_id_column, class_name: "Comment"
  accepts_nested_attributes_for :has_one_comment_with_public_id_column, public_id_column: :content

  ### regular ID
  has_many :comments_with_regular_id, class_name: "Comment"
  accepts_nested_attributes_for :comments_with_regular_id

  has_one :has_one_comment_with_regular_id, class_name: "Comment"
  accepts_nested_attributes_for :has_one_comment_with_regular_id
end
