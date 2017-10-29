require 'csv';

class CsvTransformService
  attr_accessor :file_path, :data_rows, :filtered_rows, :results

  def initialize(file_path, date)
    @file_path = file_path
    @date = date
  end

  def result
    # read data rows
    @data_rows = []
    CSV.foreach(file_path, headers: origin_csv_headers, encoding: 'ISO-8859-1').with_index do |data_row, index|
      next if index == 0
      @data_rows << data_row
    end

    # filter by date
    @filtered_rows = @data_rows.select { |data_row| Date.parse(data_row[:delivery_date]) == Date.parse(@date) rescue false }

    # export csv
    CSV.generate(headers: true, encoding: 'ISO-8859-1') do |csv|
      csv << exported_csv_headers

      @filtered_rows.each_with_index do |row, index|
        base_address = "#{row[:shipping_address_1]}, #{row[:shipping_city]}, #{row[:shipping_state]} #{row[:shipping_postcode]}"
        csv << [
          "#{index + 1}_#{row[:billing_first_name]}_#{row[:billing_last_name]}",
          nil,
          nil,
          formatted_address(base_address),
          convert_12_to_24_hr(row[:delivery_time].split('-').first.delete(' ')),
          convert_12_to_24_hr(row[:delivery_time].split('-').last.delete(' ')),
          10,
          row[:line_items].split('|')[1..-1].join("\n"),
          nil,
          1,
          nil,
          row[:billing_phone]
        ]
      end
    end
  end


  private

  def origin_csv_headers
    [
      :billing_first_name,
      :billing_last_name,
      :billing_email,
      :billing_phone,
      :shipping_address_1,
      :shipping_address_2,
      :shipping_postcode,
      :shipping_city,
      :shipping_state,
      :customer_note,
      :line_items,
      :shipping_items,
      :order_notes,
      :download_permissions_granted,
      :billing_country,
      :billing_company,
      :billing_address_1,
      :billing_address_2,
      :billing_city,
      :billing_state,
      :billing_postcode,
      :delivery_date,
      :delivery_time,
      :shipping_first_name,
      :shipping_last_name,
      :shipping_company,
      :shipping_country,
      :order_comments
    ]
  end

  def exported_csv_headers
    [
      'ID',
      'Latitude',
      'Longitude',
      'Address',
      'From',
      'To',
      'Duration',
      'Notes',
      'Notes 2',
      'Load',
      'Types',
      'Phone'
    ]
  end

  def convert_12_to_24_hr(string_time)
    Time.strptime(string_time, "%I%P").strftime("%H:%M")
  end

  def formatted_address(base_address)
    geo_result = Geocoder.search(base_address).first

    return unless geo_result
    geo_result.formatted_address
  end
end
