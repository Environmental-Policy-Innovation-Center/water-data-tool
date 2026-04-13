class CreateDataImports < ActiveRecord::Migration[8.1]
  def change
    create_table :data_imports do |t|
      t.string :file_url, null: false
      t.datetime :imported_at, null: false

      t.timestamps
    end

    # Non-unique: multiple rows per file_url are expected — each import run
    # appends a record so the ETL can diff against the most recent imported_at.
    add_index :data_imports, :file_url
  end
end
