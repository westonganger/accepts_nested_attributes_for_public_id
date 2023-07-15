class CommentWithToParamColumn < Comment

  def self.accepts_nested_attributes_for_public_id_column
    :content
  end

  # def to_param
  #   send(self.class.accepts_nested_attributes_for_public_id_column)
  # end

end
