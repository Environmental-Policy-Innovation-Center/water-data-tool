require "rails_helper"

RSpec.describe Etl::FileImporter do
  # Concrete subclass for testing the base behaviour
  let(:importer_class) do
    Class.new(described_class) do
      def parse(content)
        [{pwsid: "VT0000001", created_at: Time.current, updated_at: Time.current}]
      end

      def import!(rows)
        imported_result
      end
    end
  end

  let(:file_url) { "https://s3.example.com/data.csv" }
  let(:last_updated) { 1.day.ago }
  let(:importer) { importer_class.new(file_url: file_url, last_updated: last_updated) }

  before do
    allow($stdout).to receive(:puts)
    allow($stdout).to receive(:flush)
  end

  describe "#call" do
    context "when no prior import exists for this file_url" do
      it "downloads and imports the file, returning an ImportResult" do
        allow(importer).to receive(:download).and_return("csv content")
        expect(importer).to receive(:import!).once.and_call_original
        expect(importer.call).to have_attributes(status: :imported, file_key: "data")
      end

      it "raises when import! returns an arbitrary imported?-responding object" do
        raw_result = Class.new do
          def imported? = true
        end.new

        allow(importer).to receive(:download).and_return("csv content")
        allow(importer).to receive(:import!).and_return(raw_result)

        expect { importer.call }.to raise_error(Etl::FileImporter::InvalidImportResultError)
      end

      it "records a DataImport entry" do
        allow(importer).to receive(:download).and_return("csv content")
        allow(importer).to receive(:import!).and_call_original
        expect { importer.call }.to change(DataImport, :count).by(1)
      end

      it "stores the correct file_url on the DataImport record" do
        allow(importer).to receive(:download).and_return("csv content")
        allow(importer).to receive(:import!).and_call_original
        importer.call
        expect(DataImport.last.file_url).to eq(file_url)
      end
    end

    context "when a prior import exists and file has not changed" do
      before do
        create(:data_import, file_url: file_url, imported_at: 1.hour.ago)
      end

      let(:last_updated) { 2.hours.ago }

      it "skips the import, returning a skipped ImportResult" do
        expect(importer).not_to receive(:download)
        expect(importer.call).to have_attributes(status: :skipped, file_key: "data")
      end

      it "does not create a new DataImport record" do
        expect { importer.call }.not_to change(DataImport, :count)
      end
    end

    context "when a prior import exists but the file has been updated since" do
      before do
        create(:data_import, file_url: file_url, imported_at: 2.hours.ago)
      end

      let(:last_updated) { 1.hour.ago }

      it "downloads and imports the file" do
        allow(importer).to receive(:download).and_return("csv content")
        expect(importer).to receive(:import!).once.and_call_original
        importer.call
      end
    end

    context "with force: true" do
      let(:importer) { importer_class.new(file_url: file_url, last_updated: last_updated, force: true) }

      before do
        create(:data_import, file_url: file_url, imported_at: 1.hour.ago)
      end

      let(:last_updated) { 2.hours.ago }

      it "imports even when file has not changed" do
        allow(importer).to receive(:download).and_return("csv content")
        expect(importer).to receive(:import!).once.and_call_original
        importer.call
      end
    end

    context "when parse returns an empty result" do
      let(:empty_importer_class) do
        Class.new(described_class) do
          def parse(content) = []
          def import!(rows) = nil
        end
      end

      it "raises an error and does not record a DataImport" do
        importer = empty_importer_class.new(file_url: file_url, last_updated: last_updated)
        allow(importer).to receive(:download).and_return("csv content")
        expect { importer.call }.to raise_error(Etl::FileImporter::EmptyImportError)
        expect(DataImport.count).to eq(0)
      end
    end
  end

  describe "result helpers" do
    it "lets subclasses return imported results with metadata" do
      result = importer.send(
        :imported_result,
        changed_pwsids: ["VT0000001", "VT0000001"],
        changed_layers: ["pws"]
      )

      expect(result).to have_attributes(
        file_key: "data",
        status: :imported,
        changed_pwsids: ["VT0000001"],
        changed_layers: ["pws"]
      )
    end

    it "lets subclasses return skipped results" do
      expect(importer.send(:skipped_result)).to have_attributes(
        file_key: "data",
        status: :skipped
      )
    end
  end

  describe "#fetch_url (SSRF guard)" do
    it "raises InsecureUrlError for http:// URLs" do
      importer = importer_class.new(file_url: "http://s3.example.com/f.csv", last_updated: last_updated)
      expect { importer.send(:fetch_url, "http://s3.example.com/f.csv") }
        .to raise_error(Etl::FileImporter::InsecureUrlError, /https/i)
    end

    it "raises InsecureUrlError for file:// URLs" do
      expect { importer.send(:fetch_url, "file:///etc/passwd") }
        .to raise_error(Etl::FileImporter::InsecureUrlError)
    end

    it "raises InsecureUrlError for ftp:// URLs" do
      expect { importer.send(:fetch_url, "ftp://s3.example.com/f.csv") }
        .to raise_error(Etl::FileImporter::InsecureUrlError)
    end
  end
end
