class SetUpTestTables < ActiveRecord::Migration::Current

  def change
    create_table :posts do |t|
      t.string :title
      t.timestamps
    end

    create_table :comments do |t|
      t.string :content
      t.references :post
      t.timestamps
    end
  end

end
