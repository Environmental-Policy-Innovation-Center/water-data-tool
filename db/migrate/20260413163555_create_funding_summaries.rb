class CreateFundingSummaries < ActiveRecord::Migration[8.1]
  def change
    create_table :funding_summaries do |t|
      t.string :pwsid, null: false
      t.integer :times_funded
      t.decimal :total_srf_assistance
      t.decimal :median_srf_assistance
      t.decimal :total_principal_forgiveness

      t.timestamps
    end

    add_index :funding_summaries, :pwsid, unique: true
  end
end
