class CreateCertificationSummaries < ActiveRecord::Migration[8.1]
  def change
    create_table :certification_summaries do |t|
      t.string :pwsid, null: false
      t.string :rra_certification

      t.timestamps
    end
    add_index :certification_summaries, :pwsid, unique: true
  end
end
