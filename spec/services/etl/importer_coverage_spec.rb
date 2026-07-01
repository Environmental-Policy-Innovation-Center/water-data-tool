require "rails_helper"

# No-silent-gaps backstop for Phase 4 of docs/CONFIG_AUDIT.md.
#
# Every source file the ETL pipeline imports must be accounted for by the manifest in
# exactly one of two ways: generic (its columns live in FieldRegistry.etl_mapping and it
# is ingested by Etl::Importers::Generic), or a declared custom case (FieldRegistry
# .custom_imports, with a reason). A new importer that is neither fails here, so a custom
# path is always a deliberate, visible choice — never silent drift.
RSpec.describe "ETL importer coverage" do
  it "classifies every importer file as exactly one of generic or custom" do
    Etl::Importer::FILE_IMPORTERS.each_key do |file|
      key = file.to_sym
      generic = FieldRegistry.etl_mapping.key?(key)
      custom = FieldRegistry.custom_imports.key?(key)

      expect([generic, custom].count(true)).to eq(1),
        "#{file}: expected exactly one of generic(etl_mapping)=#{generic}, custom_imports=#{custom}"
    end
  end

  it "declares a known destination model for every custom import" do
    FieldRegistry.custom_imports.each do |file, meta|
      expect(FieldRegistry::MODEL_CLASSES).to have_key(meta[:model].to_sym),
        "#{file}: custom_imports model #{meta[:model].inspect} is not a known model"
    end
  end
end
