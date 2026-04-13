class CreateDataImports < ActiveRecord::Migration[8.1]
  def change
    create_table :data_imports do |t|
      t.string :file_url, null: false
      t.datetime :imported_at, null: false

      t.timestamps
    end

    add_index :data_imports, :file_url
  end
end
