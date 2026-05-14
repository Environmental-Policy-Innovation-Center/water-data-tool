require "rails_helper"

RSpec.describe Etl::Importer do
  let(:last_updated) { Time.zone.parse("2026-01-15 10:00:00") }
  let(:file_entries) do
    [
      {"file_key" => "epa_sabs", "http_path" => "https://s3.example.com/epa_sabs.csv", "last_updated" => last_updated},
      {"file_key" => "epa_sabs_geoms", "http_path" => "https://s3.example.com/epa_sabs_geoms.geojson", "last_updated" => last_updated},
      {"file_key" => "sdwis_viols", "http_path" => "https://s3.example.com/sdwis_viols.csv", "last_updated" => last_updated}
    ]
  end

  subject(:importer) { described_class.new }

  describe "#call" do
    before do
      allow(importer).to receive(:build_file_entries).and_return(file_entries)
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

    it "runs PostImportSteps with the geometry file key when geometry is imported" do
      geoms_importer = instance_double(Etl::Importers::EpaSabsGeoms, call: :imported)
      allow(Etl::Importers::EpaSabsGeoms).to receive(:new).and_return(geoms_importer)
      allow_all_importers_to_skip(except: Etl::Importers::EpaSabsGeoms)

      expect(Etl::PostImportSteps).to receive(:call).with(imported_files: ["epa_sabs_geoms"])
      importer.call
    end

    it "calls PostImportSteps with an empty list when no files are imported" do
      allow_all_importers_to_skip

      expect(Etl::PostImportSteps).to receive(:call).with(imported_files: [])
      importer.call
    end

    it "passes force: true to each importer when called with force: true" do
      force_importer = described_class.new(force: true)
      allow(force_importer).to receive(:build_file_entries).and_return(file_entries)

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
        filtered_importer = described_class.new(only: "epa_sabs")
        allow(filtered_importer).to receive(:build_file_entries).and_return(file_entries)

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

      it "still runs PostImportSteps with geometry key if geometry was imported before the failure" do
        geoms_importer = instance_double(Etl::Importers::EpaSabsGeoms, call: :imported)
        allow(Etl::Importers::EpaSabsGeoms).to receive(:new).and_return(geoms_importer)

        failing_sabs = instance_double(Etl::Importers::EpaSabs)
        allow(failing_sabs).to receive(:call).and_raise(StandardError, "fail")
        allow(Etl::Importers::EpaSabs).to receive(:new).and_return(failing_sabs)

        allow_all_importers_to_skip(except: [Etl::Importers::EpaSabsGeoms, Etl::Importers::EpaSabs])

        expect(Etl::PostImportSteps).to receive(:call).with(imported_files: ["epa_sabs_geoms"])
        importer.call
      end
    end
  end

  describe "imported_files tracking" do
    before do
      allow(importer).to receive(:build_file_entries).and_return(file_entries)
      allow(Etl::PostImportSteps).to receive(:call)
    end

    it "passes the imported file key to PostImportSteps when a file is imported" do
      epa_sabs_importer = instance_double(Etl::Importers::EpaSabs, call: :imported)
      allow(Etl::Importers::EpaSabs).to receive(:new).and_return(epa_sabs_importer)
      allow_all_importers_to_skip(except: Etl::Importers::EpaSabs)

      expect(Etl::PostImportSteps).to receive(:call).with(imported_files: ["epa_sabs"])
      importer.call
    end

    it "passes an empty imported_files when all files are skipped" do
      allow_all_importers_to_skip

      expect(Etl::PostImportSteps).to receive(:call).with(imported_files: [])
      importer.call
    end

    it "passes only the imported file key when a non-geometry file is imported" do
      sdwis_importer = instance_double(Etl::Importers::SdwisViols, call: :imported)
      allow(Etl::Importers::SdwisViols).to receive(:new).and_return(sdwis_importer)
      allow_all_importers_to_skip(except: Etl::Importers::SdwisViols)

      expect(Etl::PostImportSteps).to receive(:call).with(imported_files: ["sdwis_viols"])
      importer.call
    end
  end

  describe "#build_file_entries (private)" do
    let(:mock_response) do
      instance_double(Net::HTTPOK).tap do |r|
        allow(r).to receive(:[]).with("last-modified").and_return("Wed, 15 Jan 2026 10:00:00 GMT")
      end
    end

    before do
      ENV["ETL_SOURCE_URL"] = "https://s3.example.com/data"
      allow(importer).to receive(:head_url).and_return(mock_response)
    end

    after { ENV.delete("ETL_SOURCE_URL") }

    it "returns one entry per key in FILE_IMPORTERS" do
      entries = importer.send(:build_file_entries)
      expect(entries.length).to eq(Etl::Importer::FILE_IMPORTERS.length)
    end

    it "constructs the correct file URL for each key" do
      entries = importer.send(:build_file_entries)
      epa_sabs = entries.find { |e| e["file_key"] == "epa_sabs" }
      expect(epa_sabs["http_path"]).to eq("https://s3.example.com/data/epa_sabs.csv")
    end

    it "uses .geojson extension for the geometry file" do
      entries = importer.send(:build_file_entries)
      geoms = entries.find { |e| e["file_key"] == "epa_sabs_geoms" }
      expect(geoms["http_path"]).to end_with(".geojson")
    end

    it "parses Last-Modified into a Time object" do
      entry = importer.send(:build_file_entries).first
      expect(entry["last_updated"]).to be_a(Time)
    end

    it "tolerates a trailing slash on ETL_SOURCE_URL" do
      ENV["ETL_SOURCE_URL"] = "https://s3.example.com/data/"
      entries = importer.send(:build_file_entries)
      expect(entries.first["http_path"]).not_to include("//epa_sabs")
    end

    context "when ETL_SOURCE_URL is not set" do
      before { @saved = ENV.delete("ETL_SOURCE_URL") }
      after { ENV["ETL_SOURCE_URL"] = @saved if @saved }

      it "raises a descriptive error" do
        expect { importer.send(:build_file_entries) }
          .to raise_error(RuntimeError, /ETL_SOURCE_URL is not set/)
      end
    end

    context "when the Last-Modified header is absent" do
      before do
        missing = instance_double(Net::HTTPOK)
        allow(missing).to receive(:[]).with("last-modified").and_return(nil)
        allow(importer).to receive(:head_url).and_return(missing)
      end

      it "raises a descriptive error" do
        expect { importer.send(:build_file_entries) }
          .to raise_error(RuntimeError, /Missing Last-Modified header/)
      end
    end
  end

  describe "#head_url (SSRF guard)" do
    it "raises InsecureUrlError for a non-HTTPS URL" do
      expect { importer.send(:head_url, "http://evil.example.com/data.csv") }
        .to raise_error(Etl::Importer::InsecureUrlError, /https/i)
    end
  end

  private

  def allow_all_importers_to_skip(except: nil)
    except_set = Array(except).to_set
    # Only stub importers present in file_entries to avoid unexpected interactions.
    file_entries.each do |entry|
      klass = Etl::Importer::FILE_IMPORTERS[entry["file_key"]]
      next if except_set.include?(klass)
      dbl = instance_double(klass, call: :skipped)
      allow(klass).to receive(:new).and_return(dbl)
    end
  end
end
