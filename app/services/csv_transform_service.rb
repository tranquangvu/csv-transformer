require 'csv';

class CsvTransformService
  attr_accessor :file_path, :imported_rows, :exported_rows, :results

  def initialize(file_path, date)
    @file_path = file_path
    @date = date
  end

  def result
    # read data rows
    @imported_rows = []
    CSV.foreach(file_path, headers: origin_csv_headers, encoding: 'ISO-8859-1').with_index do |data_row, index|
      next if index == 0
      @imported_rows << data_row
    end

    # filter data by date
    @exported_rows = @imported_rows.select do |data_row|
      Date.parse(data_row[:delivery_date]) == Date.parse(@date) rescue false
    end

    # export csv
    CSV.generate(headers: true, encoding: 'ISO-8859-1') do |csv|
      csv << exported_csv_headers

      @exported_rows.each_with_index do |row, index|
        csv << [build_exported_csv_id(row, index), nil, nil,
          build_exported_csv_address(row), build_exported_csv_from(row), build_exported_csv_to(row),
            10, build_exported_csv_notes(row), nil, 1, nil, row[:billing_phone]]
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

  def build_exported_csv_id(row, index)
    "#{index + 1}_#{row[:billing_first_name]}_#{row[:billing_last_name]}"
  end

  def build_exported_csv_address(row)
    "#{row[:shipping_address_1]}, #{row[:shipping_city]}, #{row[:shipping_state]} #{row[:shipping_postcode]}, USA" # country is fixed to USA
  end

  def build_exported_csv_from(row)
    convert_12_to_24_hr(row[:delivery_time].split('-').first.delete(' '))
  end

  def build_exported_csv_to(row)
    convert_12_to_24_hr(row[:delivery_time].split('-').last.delete(' '))
  end

  def build_exported_csv_notes(row)
    row[:line_items].split('|')[1..-1].join("\n")
  end

  # helper methods
  def convert_12_to_24_hr(string_time)
    Time.strptime(string_time, "%I%P").strftime("%H:%M")
  end
end
