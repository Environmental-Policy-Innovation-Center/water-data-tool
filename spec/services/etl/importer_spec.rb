require "rails_helper"

RSpec.describe Etl::Importer do
  let(:manifest_url) { "https://s3.example.com/data.json" }
  let(:manifest) do
    [
      {
        "file_description" => "EPA SABs csv",
        "s3_path" => "s3://tech-team-data/epa_sabs.csv",
        "http_path" => "https://s3.example.com/epa_sabs.csv",
        "last_updated" => "2026-01-15 10:00:00"
      },
      {
        "file_description" => "EPA SABs geojson",
        "s3_path" => "s3://tech-team-data/epa_sabs_geoms.geojson",
        "http_path" => "https://s3.example.com/epa_sabs_geoms.geojson",
        "last_updated" => "2026-01-15 10:00:00"
      },
      {
        "file_description" => "SDWIS violations",
        "s3_path" => "s3://tech-team-data/sdwis_viols.csv",
        "http_path" => "https://s3.example.com/sdwis_viols.csv",
        "last_updated" => "2026-01-15 10:00:00"
      }
    ]
  end
  let(:manifest_json) { JSON.generate(manifest) }

  subject(:importer) { described_class.new(manifest_url: manifest_url) }

  describe "#call" do
    before do
      allow(importer).to receive(:fetch_manifest).and_return(manifest)
    end

    it "dispatches each recognised file to the correct file importer" do
      epa_sabs_importer = instance_double(Etl::Importers::EpaSabs, call: :skipped)
      geoms_importer = instance_double(Etl::Importers::EpaSabsGeoms, call: :skipped)
      sdwis_importer = instance_double(Etl::Importers::SdwisViols, call: :skipped)

      allow(Etl::Importers::EpaSabs).to receive(:new).and_return(epa_sabs_importer)
      allow(Etl::Importers::EpaSabsGeoms).to receive(:new).and_return(geoms_importer)
      allow(Etl::Importers::SdwisViols).to receive(:new).and_return(sdwis_importer)

      importer.call

      expect(epa_sabs_importer).to have_received(:call).once
      expect(geoms_importer).to have_received(:call).once
      expect(sdwis_importer).to have_received(:call).once
    end

    it "returns an empty errors array when all files succeed" do
      allow_all_importers_to_skip
      expect(importer.call).to eq([])
    end

    it "runs PostImportSteps when the geometry file is imported" do
      geoms_importer = instance_double(Etl::Importers::EpaSabsGeoms, call: :imported)
      allow(Etl::Importers::EpaSabsGeoms).to receive(:new).and_return(geoms_importer)
      allow_all_importers_to_skip(except: Etl::Importers::EpaSabsGeoms)

      expect(Etl::PostImportSteps).to receive(:call)
      importer.call
    end

    it "skips PostImportSteps when the geometry file is skipped" do
      allow_all_importers_to_skip

      expect(Etl::PostImportSteps).not_to receive(:call)
      importer.call
    end

    it "passes force: true to each importer when called with force: true" do
      force_importer = described_class.new(manifest_url: manifest_url, force: true)
      allow(force_importer).to receive(:fetch_manifest).and_return(manifest)

      epa_sabs_importer = instance_double(Etl::Importers::EpaSabs, call: :imported)
      allow(Etl::Importers::EpaSabs).to receive(:new)
        .with(hash_including(force: true))
        .and_return(epa_sabs_importer)
      allow_all_importers_to_skip(except: Etl::Importers::EpaSabs)

      force_importer.call

      expect(Etl::Importers::EpaSabs).to have_received(:new).with(hash_including(force: true))
    end

    context "when a table filter is specified" do
      it "only dispatches to the matching importer" do
        filtered_importer = described_class.new(manifest_url: manifest_url, only: "epa_sabs")
        allow(filtered_importer).to receive(:fetch_manifest).and_return(manifest)

        epa_sabs_importer = instance_double(Etl::Importers::EpaSabs, call: :imported)
        allow(Etl::Importers::EpaSabs).to receive(:new).and_return(epa_sabs_importer)

        filtered_importer.call

        expect(epa_sabs_importer).to have_received(:call).once
        expect(Etl::Importers::EpaSabsGeoms).not_to receive(:new)
        expect(Etl::Importers::SdwisViols).not_to receive(:new)
      end
    end

    context "when one file importer raises" do
      it "continues processing remaining files rather than aborting" do
        failing_importer = instance_double(Etl::Importers::EpaSabs)
        allow(failing_importer).to receive(:call).and_raise(StandardError, "network timeout")
        allow(Etl::Importers::EpaSabs).to receive(:new).and_return(failing_importer)

        sdwis_importer = instance_double(Etl::Importers::SdwisViols, call: :imported)
        allow(Etl::Importers::SdwisViols).to receive(:new).and_return(sdwis_importer)
        allow_all_importers_to_skip(except: [Etl::Importers::EpaSabs, Etl::Importers::SdwisViols])

        errors = importer.call

        expect(sdwis_importer).to have_received(:call)
        expect(errors.length).to eq(1)
        expect(errors.first[:file_key]).to eq("epa_sabs")
      end

      it "records the error details in the returned errors array" do
        failing_importer = instance_double(Etl::Importers::EpaSabs)
        allow(failing_importer).to receive(:call).and_raise(RuntimeError, "boom")
        allow(Etl::Importers::EpaSabs).to receive(:new).and_return(failing_importer)
        allow_all_importers_to_skip(except: Etl::Importers::EpaSabs)

        errors = importer.call

        expect(errors.first[:error]).to be_a(RuntimeError)
        expect(errors.first[:error].message).to eq("boom")
      end

      it "still runs PostImportSteps if geometry was imported before the failure" do
        geoms_importer = instance_double(Etl::Importers::EpaSabsGeoms, call: :imported)
        allow(Etl::Importers::EpaSabsGeoms).to receive(:new).and_return(geoms_importer)

        failing_sabs = instance_double(Etl::Importers::EpaSabs)
        allow(failing_sabs).to receive(:call).and_raise(StandardError, "fail")
        allow(Etl::Importers::EpaSabs).to receive(:new).and_return(failing_sabs)

        allow_all_importers_to_skip(except: [Etl::Importers::EpaSabsGeoms, Etl::Importers::EpaSabs])

        expect(Etl::PostImportSteps).to receive(:call)
        importer.call
      end
    end
  end

  describe "tile cache invalidation" do
    before do
      allow(importer).to receive(:fetch_manifest).and_return(manifest)
    end

    it "busts the tile cache when any file is imported" do
      epa_sabs_importer = instance_double(Etl::Importers::EpaSabs, call: :imported)
      allow(Etl::Importers::EpaSabs).to receive(:new).and_return(epa_sabs_importer)
      allow_all_importers_to_skip(except: Etl::Importers::EpaSabs)

      expect(Etl::PostImportSteps).to receive(:bust_tile_cache)
      importer.call
    end

    it "enqueues TileCacheWarmJob after busting the cache" do
      epa_sabs_importer = instance_double(Etl::Importers::EpaSabs, call: :imported)
      allow(Etl::Importers::EpaSabs).to receive(:new).and_return(epa_sabs_importer)
      allow_all_importers_to_skip(except: Etl::Importers::EpaSabs)

      allow(Etl::PostImportSteps).to receive(:bust_tile_cache)
      expect(TileCacheWarmJob).to receive(:perform_later)
      importer.call
    end

    it "does not bust the cache when all files are skipped" do
      allow_all_importers_to_skip

      expect(Etl::PostImportSteps).not_to receive(:bust_tile_cache)
      expect(TileCacheWarmJob).not_to receive(:perform_later)
      importer.call
    end

    it "busts the cache even when only non-geometry files are imported" do
      sdwis_importer = instance_double(Etl::Importers::SdwisViols, call: :imported)
      allow(Etl::Importers::SdwisViols).to receive(:new).and_return(sdwis_importer)
      allow_all_importers_to_skip(except: Etl::Importers::SdwisViols)

      expect(Etl::PostImportSteps).to receive(:bust_tile_cache)
      expect(TileCacheWarmJob).to receive(:perform_later)
      importer.call
    end
  end

  describe "#fetch_manifest (SSRF guard)" do
    it "raises InsecureUrlError for a non-HTTPS manifest URL" do
      bad_importer = described_class.new(manifest_url: "http://evil.example.com/data.json")
      expect { bad_importer.send(:fetch_manifest) }
        .to raise_error(Etl::Importer::InsecureUrlError, /https/i)
    end
  end

  private

  def allow_all_importers_to_skip(except: nil)
    except_set = Array(except).to_set
    Etl::Importer::FILE_IMPORTERS.each_value do |klass|
      next if except_set.include?(klass)
      dbl = instance_double(klass, call: :skipped)
      allow(klass).to receive(:new).and_return(dbl)
    end
  end
end
