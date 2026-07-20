class TrimBoilWaterSummaryPwsid < ActiveRecord::Migration[8.1]
  def up
    BoilWaterSummary.where("pwsid != TRIM(pwsid)").update_all("pwsid = TRIM(pwsid)")
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end

# ---------------------------------------------------------------------------
# Louisiana's source file pads pwsid to a fixed 12 characters (e.g.
# "LA1001001   "), unlike every other state's 9-character pwsid. Because
# public_water_systems.pwsid is never padded, the join between the two
# tables returned zero rows for LA. Etl::Importers::Generic#parse now
# strips pwsid on import (see generic.rb), so this migration is a one-time
# backfill for rows already in the DB before that fix shipped.
#
# See docs/open_items/LA_BOIL_WATER_PWSID_BACKFILL.md for the full writeup.
# ---------------------------------------------------------------------------
