require 'spec_helper'

module Fedex
  describe Shipment do
    context "missing required parameters" do
      it "should raise Rate exception" do
        lambda{ Shipment.new}.should raise_error(RateError)
      end
    end

    context "required parameters present" do
      subject { Shipment.new(fedex_credentials) }
      it "should create a valid instance" do
        subject.should be_an_instance_of(Shipment)
      end
    end

    describe "rate service" do
      let(:fedex) { Shipment.new(fedex_credentials) }
      let(:shipper) do
        { :name => "Sender", :company => "Company", :phone_number => "555-555-5555", :address => "Main Street", :city => "Harrison", :state => "AR", :postal_code => "72601", :country_code => "US" }
      end
      let(:recipient) do
        { :name => "Recipient", :company => "Company", :phone_number => "555-555-5555", :address => "Main Street", :city => "Frankin Park", :state => "IL", :postal_code => "60131", :country_code => "US", :residential => true }
      end
      let(:packages) do
        [
          {
            :weight => { :units => "LB", :value => 2 },
            :dimensions => { :length => 10, :width => 5, :height => 4, :units => "IN" }
          },
          {
            :weight => { :units => "LB", :value => 6 },
            :dimensions => { :length => 5, :width => 5, :height => 4, :units => "IN" }
          }
        ]
      end
      let(:shipping_options) do
        { :packaging_type => "YOUR_PACKAGING", :drop_off_type => "REGULAR_PICKUP" }
      end

      context "domestic shipment", :vcr do
        it "should return a rate" do
          rates = fedex.rate({ :shipper => shipper, :recipient => recipient, :packages => packages, :service_type => "FEDEX_GROUND"})
          rates.first.should be_an_instance_of(Rate)
        end
        it "should return a transit time" do
          rates = fedex.rate({ :shipper => shipper, :recipient => recipient, :packages => packages, :service_type => "FEDEX_GROUND"})
          rates.first.transit_time.should_not be_nil
        end
      end

      context "canadian shipment", :vcr do
        it "should return a rate" do
          canadian_recipient = { :name => "Recipient", :company => "Company", :phone_number => "555-555-5555", :address=>"Address Line 1", :city => "Richmond", :state => "BC", :postal_code => "V7C4V4", :country_code => "CA", :residential => "true" }
          rates = fedex.rate({ :shipper => shipper, :recipient => canadian_recipient, :packages => packages, :service_type => "FEDEX_GROUND" })
          rates.first.should be_an_instance_of(Rate)
        end
      end

      context "canadian shipment including customs", :vcr do
        it "should return a rate including international fees" do
          canadian_recipient = { :name => "Recipient", :company => "Company", :phone_number => "555-555-5555", :address=>"Address Line 1", :city => "Richmond", :state => "BC", :postal_code => "V7C4V4", :country_code => "CA", :residential => "true" }
          broker = {
            :account_number => "510087143",
            :tins => { :tin_type => "BUSINESS_NATIONAL",
                       :number  => "431870271",
                       :usage => "Usage" },
            :contact => { :contact_id => "1",
                          :person_name => "Broker Name",
                          :title => "Broker",
                          :company_name => "Broker One",
                          :phone_number => "555-555-5555",
                          :phone_extension => "555-555-5555",
                          :pager_number => "555",
                          :fax_number=> "555-555-5555",
                          :e_mail_address => "contact@me.com" },
            :address => { :street_lines => "Main Street",
                          :city => "Franklin Park",
                          :state_or_province_code => 'IL',
                          :postal_code => '60131',
                          :urbanization_code => '123',
                          :country_code => 'US',
                          :residential => 'false' }
          }

          clearance_brokerage = "BROKER_INCLUSIVE"

          importer_of_record= {
            :account_number => "22222",
            :tins => { :tin_type => "BUSINESS_NATIONAL",
                       :number  => "22222",
                       :usage => "Usage" },
            :contact => { :contact_id => "1",
                          :person_name => "Importer Name",
                          :title => "Importer",
                          :company_name => "Importer One",
                          :phone_number => "555-555-5555",
                          :phone_extension => "555-555-5555",
                          :pager_number => "555",
                          :fax_number=> "555-555-5555",
                          :e_mail_address => "contact@me.com" },
            :address => { :street_lines => "Main Street",
                          :city => "Chicago",
                          :state_or_province_code => 'IL',
                          :postal_code => '60611',
                          :urbanization_code => '2308',
                          :country_code => 'US',
                          :residential => 'false' }
          }

          recipient_customs_id = { :type => 'COMPANY',
                                   :value => '1254587' }


          duties_payment = { :payment_type => "SENDER",
                             :payor => { :account_number => "510087143",
                                         :country_code => "US" } }

          customs_value = { :currency => "USD",
                            :amount => "200" }
          commodities = [{
              :name => "Cotton Coat",
              :number_of_pieces => "2",
              :description => "Cotton Coat",
              :country_of_manufacture => "US",
              :harmonized_code => "6103320000",
              :weight => { :units => "LB", :value => "2" },
              :quantity => "3",
              :unit_price => { :currency => "USD", :amount => "50" },
              :customs_value => { :currency => "USD", :amount => "150" }
            },
            {
              :name => "Poster",
              :number_of_pieces => "1",
              :description => "Paper Poster",
              :country_of_manufacture => "US",
              :harmonized_code => "4817100000",
              :weight => { :units => "LB", :value => "0.2" },
              :quantity => "3",
              :unit_price => { :currency => "USD", :amount => "50" },
              :customs_value => { :currency => "USD", :amount => "150" }
            }
          ]

          customs_clearance = { :broker => broker, :clearance_brokerage => clearance_brokerage, :importer_of_record => importer_of_record, :recipient_customs_id => recipient_customs_id, :duties_payment => duties_payment, :commodities => commodities }
          rates = fedex.rate({ :shipper => shipper, :recipient => canadian_recipient, :packages => packages, :service_type => "FEDEX_GROUND", :customs_clearance => customs_clearance })
          rates.first.should be_an_instance_of(Rate)
        end
      end

      context "with service type specified", :vcr do

        let(:rates) {
          fedex.rate({
            :shipper => shipper,
            :recipient => recipient,
            :packages => packages,
            :service_type => "FEDEX_GROUND"
          })
        }

        it "returns a single rate" do
          rates.count.should eq 1
        end

        it "has service_type attribute" do
          rates.first.service_type == 'FEDEX_GROUND'
        end

      end

      context "with no service type specified", :vcr do

        let(:rates) {
          fedex.rate({
            :shipper => shipper,
            :recipient => recipient,
            :packages => packages
          })
        }

        it "returns multiple rates" do
          rates.count.should >= 1
        end

        context "each rate" do

          it 'has service type attribute' do
            rates.first.should respond_to(:service_type)
          end

        end

      end

      context "when there are no valid services available", :vcr do

        let(:bad_shipper) { shipper.merge(state: 'Anywhere') }
        let(:rates) {
          fedex.rate({
            :shipper => bad_shipper,
            :recipient => recipient,
            :packages => packages
          })
        }

        it 'returns empty array' do
          rates.should eq []
        end

      end

    end
  end
end