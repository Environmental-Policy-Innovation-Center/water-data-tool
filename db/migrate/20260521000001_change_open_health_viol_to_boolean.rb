class ChangeOpenHealthViolToBoolean < ActiveRecord::Migration[8.1]
  def up
    # Raw SQL required: ActiveRecord's change_column cannot emit a USING clause.
    # Without it, a separate full-table UPDATE pass would be needed before the ALTER.
    execute <<~SQL
      ALTER TABLE public_water_systems
        ALTER COLUMN open_health_viol TYPE boolean
        USING open_health_viol::boolean
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
