class AddErpCertificationToCertificationSummaries < ActiveRecord::Migration[8.1]
  def change
    add_column :certification_summaries, :erp_certification, :string
  end
end
