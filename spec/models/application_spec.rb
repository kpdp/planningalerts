require 'spec_helper'

describe Application do
  before :each do
    Authority.delete_all
    @auth = create(:authority, full_name: "Fiddlesticks", state: "NSW", short_name: "Fiddle")
    # Stub out the geocoder to return some arbitrary coordinates so that the tests can run quickly
    allow(Location).to receive(:geocode).and_return(double(lat: 1.0, lng: 2.0, suburb: "Glenbrook", state: "NSW",
      postcode: "2773", success: true))
  end

  describe "validation" do
    describe "date_scraped" do
      it { expect(build(:application, date_scraped: nil)).not_to be_valid }
    end

    describe "council_reference" do
      let (:auth1) { create(:authority) }

      it { expect(build(:application, council_reference: "")).not_to be_valid }

      context "one application already exists" do
        before :each do
          create(:application, council_reference: "A01", authority: auth1)
        end
        let(:auth2) { create(:authority, full_name: "A second authority") }

        it { expect(build(:application, council_reference: "A01", authority: auth1)).not_to be_valid }
        it { expect(build(:application, council_reference: "A02", authority: auth1)).to be_valid }
        it { expect(build(:application, council_reference: "A01", authority: auth2)).to be_valid }
      end
    end

    describe "address" do
      it { expect(build(:application, address: "")).not_to be_valid }
    end

    describe "description" do
      it { expect(build(:application, description: "")).not_to be_valid }
    end

    describe "info_url" do
      it { expect(build(:application, info_url: "")).not_to be_valid }
      it { expect(build(:application, info_url: "http://blah.com?p=1")).to be_valid }
      it { expect(build(:application, info_url: "foo")).not_to be_valid }
    end

    describe "comment_url" do
      it { expect(build(:application, comment_url: nil)).to be_valid }
      it { expect(build(:application, comment_url: "http://blah.com?p=1")).to be_valid }
      it { expect(build(:application, comment_url: "mailto:m@foo.com?subject=hello+sir")).to be_valid }
      it { expect(build(:application, comment_url: "foo")).not_to be_valid }
      it { expect(build(:application, comment_url: "mailto:council@lakemac.nsw.gov.au?Subject=Redhead%20Beach%20&%20Surf%20Life%20Saving%20Club,%202A%20Beach%20Road,%20REDHEAD%20%20NSW%20%202290%20DA-1699/2014")).to be_valid }
    end

    describe "date_received" do
      it { expect(build(:application, date_received: nil)).to be_valid }

      context "the date today is 1 january 2001" do
        before :each do
          allow(Date).to receive(:today).and_return(Date.new(2001,1,1))
        end
        it { expect(build(:application, date_received: Date.new(2002,1,1))).not_to be_valid }
        it { expect(build(:application, date_received: Date.new(2000,1,1))).to be_valid }
      end
    end

    describe "on_notice" do
      it { expect(build(:application, on_notice_from: nil, on_notice_to: nil)).to be_valid }
      it { expect(build(:application, on_notice_from: Date.new(2001,1,1), on_notice_to: Date.new(2001,2,1))).to be_valid }
      it { expect(build(:application, on_notice_from: nil, on_notice_to: Date.new(2001,2,1))).to be_valid }
      it { expect(build(:application, on_notice_from: Date.new(2001,1,1), on_notice_to: nil)).to be_valid }
      it { expect(build(:application, on_notice_from: Date.new(2001,2,1), on_notice_to: Date.new(2001,1,1))).not_to be_valid }
    end
  end

  describe "getting DA descriptions" do
    it "should allow applications to be blank" do
      expect(build(:application, description: "").description).to eq("")
    end

    it "should allow the application description to be nil" do
      expect(build(:application, description: nil).description).to be_nil
    end

    it "should start descriptions with a capital letter" do
      expect(build(:application, description: "a description").description).to eq("A description")
    end

    it "should fix capitilisation of descriptions all in caps" do
      expect(build(:application, description: "DWELLING").description).to eq("Dwelling")
    end

    it "should not capitalise descriptions that are partially in lowercase" do
      expect(build(:application, description: "To merge Owners Corporation").description).to eq("To merge Owners Corporation")
    end

    it "should capitalise the first word of each sentence" do
      expect(build(:application, description: "A SENTENCE. ANOTHER SENTENCE").description).to eq("A sentence. Another sentence")
    end

    it "should only capitalise the word if it's all lower case" do
      expect(build(:application, description: 'ab sentence. AB SENTENCE. aB sentence. Ab sentence').description).to eq('Ab sentence. AB SENTENCE. aB sentence. Ab sentence')
    end

    it "should allow blank sentences" do
      expect(build(:application, description: "A poorly.    . formed sentence . \n").description).to eq("A poorly. . Formed sentence. ")
    end
  end

  describe "getting addresses" do
    it "should convert words to first letter capitalised form" do
      expect(build(:application, address: "1 KINGSTON AVENUE, PAKENHAM").address).to eq("1 Kingston Avenue, Pakenham")
    end

    it "should not convert words that are not already all in upper case" do
      expect(build(:application, address: "In the paddock next to the radio telescope").address).to eq("In the paddock next to the radio telescope")
    end

    it "should handle a mixed bag of lower and upper case" do
      expect(build(:application, address: "63 Kimberley drive, SHAILER PARK").address).to eq("63 Kimberley drive, Shailer Park")
    end

    it "should not affect dashes in the address" do
      expect(build(:application, address: "63-81").address).to eq("63-81")
    end

    it "should not affect abbreviations like the state names" do
      expect(build(:application, address: "1 KINGSTON AVENUE, PAKENHAM VIC 3810").address).to eq("1 Kingston Avenue, Pakenham VIC 3810")
    end

    it "should not affect the state names" do
      expect(build(:application, address: "QLD VIC NSW SA ACT TAS WA NT").address).to eq("QLD VIC NSW SA ACT TAS WA NT")
    end

    it "should not affect the state names with punctuation" do
      expect(build(:application, address: "QLD. ,VIC ,NSW, !SA /ACT/ TAS: WA, NT;").address).to eq("QLD. ,VIC ,NSW, !SA /ACT/ TAS: WA, NT;")
    end

    it "should not affect codes" do
      expect(build(:application, address: "R79813 24X").address).to eq("R79813 24X")
    end
  end

  describe "on saving" do
    it "should geocode the address" do
      loc = double("Location", lat: -33.772609, lng: 150.624263, suburb: "Glenbrook", state: "NSW",
        postcode: "2773", success: true)
      expect(Location).to receive(:geocode).with("24 Bruce Road, Glenbrook, NSW").and_return(loc)
      a = create(:application, address: "24 Bruce Road, Glenbrook, NSW", council_reference: "r1", date_scraped: Time.now)
      expect(a.lat).to eq(loc.lat)
      expect(a.lng).to eq(loc.lng)
    end

    it "should log an error if the geocoder can't make sense of the address" do
      expect(Location).to receive(:geocode).with("dfjshd").and_return(double("Location", success: false))
      logger = double("Logger")
      expect(logger).to receive(:error).with("Couldn't geocode address: dfjshd")

      a = build(:application, address: "dfjshd", council_reference: "r1", date_scraped: Time.now)
      allow(a).to receive(:logger).and_return(logger)

      a.save!
      expect(a.lat).to be_nil
      expect(a.lng).to be_nil
    end

    it "should set the url for showing the address on a google map" do
      a = build(:application, address: "24 Bruce Road, Glenbrook, NSW", council_reference: "r1", date_scraped: Time.now)
      expect(a.map_url).to eq("http://maps.google.com/maps?q=24+Bruce+Road%2C+Glenbrook%2C+NSW&z=15")
    end
  end

  describe "collecting applications from the scraperwiki web service url" do
    it "should translate the data" do
      feed_data = <<-EOF
        [
          {
            "date_scraped": "2012-08-24",
            "description": "Construction of Dwelling",
            "info_url": "http://www.yarracity.vic.gov.au/Planning-Application-Search/Results.aspx?ApplicationNumber=PL01/0776.01&Suburb=(All)&Street=(All)&Status=(All)&Ward=(All)",
            "on_notice_from": "2012-05-01",
            "on_notice_to": "2012-06-01",
            "date_received": "2012-07-06",
            "council_reference": "PL01/0776.01",
            "address": "56 Murphy St Richmond VIC 3121",
            "comment_url": "http://www.yarracity.vic.gov.au/planning--building/Planning-applications/Objecting-to-a-planning-applicationVCAT/"
          },
          {
            "date_scraped": "2012-08-24",
            "description": "Liquor Licence for Existing Caf\u00e9",
            "info_url": "http://www.yarracity.vic.gov.au/Planning-Application-Search/Results.aspx?ApplicationNumber=PL02/0313.01&Suburb=(All)&Street=(All)&Status=(All)&Ward=(All)",
            "date_received": "2012-07-30",
            "council_reference": "PL02/0313.01",
            "address": "359-361 Napier St Fitzroy VIC 3065",
            "comment_url": "http://www.yarracity.vic.gov.au/planning--building/Planning-applications/Objecting-to-a-planning-applicationVCAT/"
          }
        ]
      EOF
      # Freeze time
      t = Time.now
      allow(Time).to receive(:now).and_return(t)
      expect(Application.translate_morph_feed_data(feed_data)).to eq(
      [
        {
          date_scraped: t,
          description: "Construction of Dwelling",
          info_url: "http://www.yarracity.vic.gov.au/Planning-Application-Search/Results.aspx?ApplicationNumber=PL01/0776.01&Suburb=(All)&Street=(All)&Status=(All)&Ward=(All)",
          on_notice_from: "2012-05-01",
          on_notice_to: "2012-06-01",
          date_received: "2012-07-06",
          council_reference: "PL01/0776.01",
          address: "56 Murphy St Richmond VIC 3121",
          comment_url: "http://www.yarracity.vic.gov.au/planning--building/Planning-applications/Objecting-to-a-planning-applicationVCAT/"
        },
        {
          date_scraped: t,
          description: "Liquor Licence for Existing Caf\u00e9",
          info_url: "http://www.yarracity.vic.gov.au/Planning-Application-Search/Results.aspx?ApplicationNumber=PL02/0313.01&Suburb=(All)&Street=(All)&Status=(All)&Ward=(All)",
          on_notice_from: nil,
          on_notice_to: nil,
          date_received: "2012-07-30",
          council_reference: "PL02/0313.01",
          address: "359-361 Napier St Fitzroy VIC 3065",
          comment_url: "http://www.yarracity.vic.gov.au/planning--building/Planning-applications/Objecting-to-a-planning-applicationVCAT/"
        }
      ]
      )
    end

    it "should handle a malformed response" do
      expect(Application.translate_morph_feed_data('[["An invalid scraperwiki API response"]]')).to eq([])
    end
  end

  describe "collecting applications from the scraper web service urls" do
    before :each do
      @feed_xml = <<-EOF
      [
        {
          "council_reference": "R1",
          "address": "1 Smith Street, Fiddleville",
          "description": "Knocking a house down",
          "info_url": "http://fiddle.gov.au/info/R1",
          "comment_url": "http://fiddle.gov.au/comment/R1",
          "date_received": "2009-01-01",
          "on_notice_from": "2009-01-05",
          "on_notice_to": "2009-01-19"
        },
        {
          "council_reference": "R2",
          "address": "2 Smith Street, Fiddleville",
          "description": "Putting a house up",
          "info_url": "http://fiddle.gov.au/info/R2",
          "comment_url": "http://fiddle.gov.au/comment/R2"
        }
      ]
      EOF
      @date = Date.new(2009, 1, 1)
      @feed_url = "http://example.org?year=#{@date.year}&month=#{@date.month}&day=#{@date.day}"
      Application.delete_all
      allow(@auth).to receive(:open).and_return(double(read: @feed_xml))
    end

    it "should collect the correct applications" do
      logger = double
      allow(@auth).to receive(:logger).and_return(logger)
      expect(logger).to receive(:info).with("2 new applications found for Fiddlesticks, NSW with date from 2009-01-01 to 2009-01-01")

      @auth.collect_applications_date_range(@date, @date)
      expect(Application.count).to eq(2)
      r1 = Application.find_by_council_reference("R1")
      expect(r1.authority).to eq(@auth)
      expect(r1.address).to eq("1 Smith Street, Fiddleville")
      expect(r1.description).to eq("Knocking a house down")
      expect(r1.info_url).to eq("http://fiddle.gov.au/info/R1")
      expect(r1.comment_url).to eq("http://fiddle.gov.au/comment/R1")
      expect(r1.date_received).to eq(@date)
      expect(r1.on_notice_from).to eq(Date.new(2009,1,5))
      expect(r1.on_notice_to).to eq(Date.new(2009,1,19))
    end

    it "should not create new applications when they already exist" do
      logger = double
      allow(@auth).to receive(:logger).and_return(logger)
      expect(logger).to receive(:info).with("2 new applications found for Fiddlesticks, NSW with date from 2009-01-01 to 2009-01-01")
      expect(logger).to receive(:info).with("0 new applications found for Fiddlesticks, NSW with date from 2009-01-01 to 2009-01-01")

      # Getting the feed twice with the same content
      @auth.collect_applications_date_range(@date, @date)
      @auth.collect_applications_date_range(@date, @date)
      expect(Application.count).to eq(2)
    end

    it "should collect all the applications from all the authorities over the last n days" do
      auth2 = create(:authority, full_name: "Wombat City Council", short_name: "Wombat", state: "NSW")
      allow(Date).to receive(:today).and_return(Date.new(2010, 1, 10))
      logger = double
      expect(logger).to receive(:info).with("Scraping 2 authorities")
      #logger.should_receive(:add).with(1, nil, "Took 0 s to collect applications from Fiddlesticks, NSW")
      #logger.should_receive(:add).with(1, nil, "Took 0 s to collect applications from Wombat City Council, NSW")
      expect(@auth).to receive(:collect_applications).with(logger)
      expect(auth2).to receive(:collect_applications).with(logger)

      Application.collect_applications([@auth, auth2], logger)
    end
  end

  describe "#official_submission_period_expired?" do
    before :each do
      @application = create(:application)
    end

    context "when the ‘on notice to’ date is not set" do
      before { @application.update(on_notice_to: nil) }

      it { expect(@application.official_submission_period_expired?).to be_falsey }
    end

    context "when the ‘on notice to’ date has passed", focus: true do
      before { @application.update(on_notice_to: Date.today - 1.day) }

      it { expect(@application.official_submission_period_expired?).to be true }
    end

    context "when the ‘on notice to’ date is in the future" do
      before { @application.update(on_notice_to: Date.today + 1.day) }

      it { expect(@application.official_submission_period_expired?).to be false }
    end
  end

  describe "#current_councillors_for_authority" do
    let(:authority) { create(:authority) }
    let(:application) { create(:application, authority: authority) }

    context "when there are no councillors" do
      it { expect(application.current_councillors_for_authority).to eq nil }
    end

    context "when there are councillors" do
      before do
        @councillor1 = create(:councillor, authority: authority)
        @councillor2 = create(:councillor, authority: authority)
        @councillor3 = create(:councillor, authority: authority)
      end

      it { expect(application.current_councillors_for_authority).to match_array [@councillor1, @councillor2, @councillor3] }
    end

    context "when there are councillors but not for the application’s authority" do
      before do
        @councillor1 = create(:councillor, authority: create(:authority))
      end

      it { expect(application.current_councillors_for_authority).to eq nil }
    end

    context "when there are councillors but not all are current" do
      before do
        @current_councillor = create(:councillor, current: true, authority: authority)
        @former_councillor = create(:councillor, current: false, authority: authority)
      end

      it "only includes the current ones" do
        expect(application.current_councillors_for_authority).to eq [@current_councillor]
      end
    end
  end

  describe "#councillors_available_for_contact" do
    let(:authority) { create(:authority) }
    let(:application) { create(:application, authority: authority) }

    context "when there are no councillors" do
      context "and the feature is disabled for the authority" do
        before do
          allow(authority).to receive(:write_to_councillors_enabled?).and_return false
        end

        it { expect(application.councillors_available_for_contact).to eq nil }
      end

      context "and the feature is enabled for the authority" do
        before do
          allow(authority).to receive(:write_to_councillors_enabled?).and_return true
        end

        it { expect(application.councillors_available_for_contact).to eq nil }
      end
    end

    context "when there are councillors" do
      before do
        @councillor1 = create(:councillor, authority: authority)
        @councillor2 = create(:councillor, authority: authority)
        @councillor3 = create(:councillor, authority: authority)
      end

      context "but the feature is disabled for the authority" do
        before do
          allow(authority).to receive(:write_to_councillors_enabled?).and_return false
        end

        it { expect(application.councillors_available_for_contact).to eq nil }
      end

      context "and the feature is enabled for the authority" do
        before do
          allow(authority).to receive(:write_to_councillors_enabled?).and_return true
        end

        it { expect(application.councillors_available_for_contact).to match_array [@councillor1, @councillor2, @councillor3] }
      end
    end
  end
end
