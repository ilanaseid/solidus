require 'spec_helper'

describe Spree::BaseHelper, type: :helper do
  include Spree::BaseHelper

  let(:current_store){ create :store }

  context "available_countries" do
    let(:country) { create(:country) }

    before do
      3.times { create(:country) }
    end

    context "with no checkout zone defined" do
      before do
        Spree::Config[:checkout_zone] = nil
      end

      it "return complete list of countries" do
        expect(available_countries.count).to eq(Spree::Country.count)
      end
    end

    context "with a checkout zone defined" do
      context "checkout zone is of type country" do
        before do
          @country_zone = create(:zone, name: "CountryZone")
          @country_zone.members.create(zoneable: country)
          Spree::Config[:checkout_zone] = @country_zone.name
        end

        it "return only the countries defined by the checkout zone" do
          expect(available_countries).to eq([country])
        end
      end

      context "checkout zone is of type state" do
        before do
          state_zone = create(:zone, name: "StateZone")
          state = create(:state, country: country)
          state_zone.members.create(zoneable: state)
          Spree::Config[:checkout_zone] = state_zone.name
        end

        it "return complete list of countries" do
          expect(available_countries.count).to eq(Spree::Country.count)
        end
      end
    end
  end

  # Regression test for https://github.com/spree/spree/issues/1436
  context "defining custom image helpers" do
    let(:product) { mock_model(Spree::Product, images: [], variant_images: []) }
    before do
      Spree::Image.class_eval do
        attachment_definitions[:attachment][:styles][:very_strange] = '1x1'
      end
    end

    it "should not raise errors when style exists" do
      ActiveSupport::Deprecation.silence do
        very_strange_image(product)
      end
    end

    it "should raise NoMethodError when style is not exists" do
      expect { another_strange_image(product) }.to raise_error(NoMethodError)
    end
  end

  # Regression test for https://github.com/spree/spree/issues/2034
  context "flash_message" do
    let(:flash) { { "notice" => "ok", "foo" => "foo", "bar" => "bar" } }

    it "should output all flash content" do
      flash_messages
      html = Nokogiri::HTML(helper.output_buffer)
      expect(html.css(".notice").text).to eq("ok")
      expect(html.css(".foo").text).to eq("foo")
      expect(html.css(".bar").text).to eq("bar")
    end

    it "should output flash content except one key" do
      flash_messages(ignore_types: :bar)
      html = Nokogiri::HTML(helper.output_buffer)
      expect(html.css(".notice").text).to eq("ok")
      expect(html.css(".foo").text).to eq("foo")
      expect(html.css(".bar").text).to be_empty
    end

    it "should output flash content except some keys" do
      flash_messages(ignore_types: [:foo, :bar])
      html = Nokogiri::HTML(helper.output_buffer)
      expect(html.css(".notice").text).to eq("ok")
      expect(html.css(".foo").text).to be_empty
      expect(html.css(".bar").text).to be_empty
      expect(helper.output_buffer).to eq("<div class=\"flash notice\">ok</div>")
    end
  end

  context "link_to_tracking" do
    it "returns tracking link if available" do
      a = link_to_tracking_html(shipping_method: true, tracking: '123', tracking_url: 'http://g.c/?t=123').css('a')

      expect(a.text).to eq '123'
      expect(a.attr('href').value).to eq 'http://g.c/?t=123'
    end

    it "returns tracking without link if link unavailable" do
      html = link_to_tracking_html(shipping_method: true, tracking: '123', tracking_url: nil)
      expect(html.css('span').text).to eq '123'
    end

    it "returns nothing when no shipping method" do
      html = link_to_tracking_html(shipping_method: nil, tracking: '123')
      expect(html.css('span').text).to eq ''
    end

    it "returns nothing when no tracking" do
      html = link_to_tracking_html(tracking: nil)
      expect(html.css('span').text).to eq ''
    end

    def link_to_tracking_html(options = {})
      node = link_to_tracking(double(:shipment, options))
      Nokogiri::HTML(node.to_s)
    end
  end

  # Regression test for https://github.com/spree/spree/issues/2396
  context "meta_data_tags" do
    it "truncates a product description to 160 characters" do
      # Because the controller_name method returns "test"
      # controller_name is used by this method to infer what it is supposed
      # to be generating meta_data_tags for
      @test = Spree::Product.new(description: "a" * 200)
      tags = Nokogiri::HTML.parse(meta_data_tags)
      content = tags.css("meta[name=description]").first["content"]
      expect(content.length).to be <= 160
    end
  end

  # Regression test for https://github.com/spree/spree/issues/5384
  context "custom image helpers conflict with inproper statements" do
    let(:product) { mock_model(Spree::Product, images: [], variant_images: []) }
    before do
      Spree::Image.class_eval do
        attachment_definitions[:attachment][:styles][:foobar] = '1x1'
      end
    end

    it "should not raise errors when helper method called" do
      ActiveSupport::Deprecation.silence do
        foobar_image(product)
      end
    end

    it "should raise NoMethodError when statement with name equal to style name called" do
      expect { foobar(product) }.to raise_error(NoMethodError)
    end
  end

  context "pretty_time" do
    it "prints in a format" do
      expect(pretty_time(DateTime.new(2012, 5, 6, 13, 33))).to eq "May 06, 2012  1:33 PM"
    end
  end
end
