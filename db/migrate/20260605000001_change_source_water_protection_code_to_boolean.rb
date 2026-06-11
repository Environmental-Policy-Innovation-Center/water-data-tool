class ChangeSourceWaterProtectionCodeToBoolean < ActiveRecord::Migration[8.1]
  def up
    # Raw SQL required: ActiveRecord's change_column cannot emit a USING clause.
    # "No Information" (15,171 rows) collapses to NULL — it is a publisher-stated
    # unknown on a binary yes/no question, semantically identical to nil.
    # 'Yes' -> True
    # 'No' -> False
    # 'No Information' -> nil
    execute <<~SQL
      ALTER TABLE public_water_systems
        ALTER COLUMN source_water_protection_code TYPE boolean
        USING CASE
          WHEN source_water_protection_code = 'Yes' THEN true
          WHEN source_water_protection_code = 'No'  THEN false
          ELSE NULL
        END
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
